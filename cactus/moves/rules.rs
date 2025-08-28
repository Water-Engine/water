use crate::core::{
    Color,
    board::Board,
    piece::{PieceKind, PieceType},
};

impl Board {
    pub fn is_move_legal(
        &self,
        from: (usize, usize),
        to: (usize, usize),
        promotion: Option<PieceKind>,
    ) -> bool {
        self.simulate_move_checked(from, to, promotion).is_ok()
    }

    pub fn is_valid_piece_move(
        &self,
        piece: PieceKind,
        from: (usize, usize),
        to: (usize, usize),
    ) -> bool {
        match piece.to_type() {
            PieceType::Pawn => self.validate_pawn_move(piece.color(), from, to),
            PieceType::Knight => self.validate_knight_move(from, to),
            PieceType::Bishop => self.validate_bishop_move(from, to),
            PieceType::Rook => self.validate_rook_move(from, to),
            PieceType::Queen => self.validate_queen_move(from, to),
            PieceType::King => self.validate_king_move(from, to),
        }
    }

    pub fn validate_pawn_move(
        &self,
        color: Color,
        from: (usize, usize),
        to: (usize, usize),
    ) -> bool {
        let (fr, ff) = from;
        let (tr, tf) = to;

        let dir: isize = match color {
            Color::White => -1,
            Color::Black => 1,
        };

        let start_rank = match color {
            Color::White => 6,
            Color::Black => 1,
        };

        let dr = tr as isize - fr as isize;
        let df = tf as isize - ff as isize;

        if df == 0 && dr == dir {
            return self.piece_at(to).is_none();
        }

        if df == 0 && fr == start_rank && dr == 2 * dir {
            let mid = ((fr as isize + dir) as usize, ff);
            return self.piece_at(mid).is_none() && self.piece_at(to).is_none();
        }

        if dr == dir && df.abs() == 1 {
            if let Some(target) = self.piece_at(to) {
                return target.color() != color;
            }

            if let Some(ep) = self.en_passant_target {
                return ep == to;
            }
        }

        false
    }

    pub fn validate_knight_move(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        let (fr, ff) = from;
        let (tr, tf) = to;
        let dr = (fr as isize - tr as isize).abs();
        let df = (ff as isize - tf as isize).abs();
        (dr == 2 && df == 1) || (dr == 1 && df == 2)
    }

    pub fn validate_bishop_move(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        if (from.0 as isize - to.0 as isize).abs() == (from.1 as isize - to.1 as isize).abs() {
            return self.is_path_clear(from, to);
        }
        false
    }

    pub fn validate_rook_move(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        let (fr, ff) = from;
        let (tr, tf) = to;
        if fr == tr || ff == tf {
            return self.is_path_clear(from, to);
        }
        false
    }

    pub fn validate_queen_move(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        self.validate_rook_move(from, to) || self.validate_bishop_move(from, to)
    }

    pub fn validate_king_move(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        let (fr, ff) = from;
        let (tr, tf) = to;
        let dr = (fr as isize - tr as isize).abs();
        let df = (ff as isize - tf as isize).abs();

        // Normal king move
        if dr <= 1 && df <= 1 {
            return true;
        }

        // Castling logic
        let color = self.piece_at(from).unwrap().color();
        let row = match color {
            Color::White => 7,
            Color::Black => 0,
        };

        if fr != row || tr != row || self.is_in_check(color) {
            return false;
        }

        // King-side castling
        if ff == 4 && tf == 6 {
            let can_castle = match color {
                Color::White => {
                    !self.flags.has_white_king_moved && !self.flags.has_white_kingside_rook_moved
                }
                Color::Black => {
                    !self.flags.has_black_king_moved && !self.flags.has_black_kingside_rook_moved
                }
            };
            if !can_castle {
                return false;
            }

            if self.piece_at((row, 5)).is_some() || self.piece_at((row, 6)).is_some() {
                return false;
            }

            let squares = [(row, 4), (row, 5), (row, 6)];
            return !squares.iter().any(|&pos| {
                let mut clone = self.clone();
                clone.set_piece(pos, self.piece_at((row, 4)));
                clone.set_piece((row, 4), None);
                clone.is_in_check(color)
            });
        }

        if ff == 4 && tf == 2 {
            let can_castle = match color {
                Color::White => {
                    !self.flags.has_white_king_moved && !self.flags.has_white_queenside_rook_moved
                }
                Color::Black => {
                    !self.flags.has_black_king_moved && !self.flags.has_black_queenside_rook_moved
                }
            };
            if !can_castle {
                return false;
            }

            if self.piece_at((row, 3)).is_some()
                || self.piece_at((row, 2)).is_some()
                || self.piece_at((row, 1)).is_some()
            {
                return false;
            }

            let squares = [(row, 4), (row, 3), (row, 2)];
            return !squares.iter().any(|&pos| {
                let mut clone = self.clone();
                clone.set_piece(pos, self.piece_at((row, 4)));
                clone.set_piece((row, 4), None);
                clone.is_in_check(color)
            });
        }

        false
    }

    pub fn is_path_clear(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        let (mut r, mut f) = from;
        let (tr, tf) = to;

        let dr = (tr as isize - r as isize).signum();
        let df = (tf as isize - f as isize).signum();

        r = (r as isize + dr) as usize;
        f = (f as isize + df) as usize;

        while (r, f) != to {
            if self.piece_at((r, f)).is_some() {
                return false;
            }
            r = (r as isize + dr) as usize;
            f = (f as isize + df) as usize;
        }

        true
    }

    pub fn is_in_check(&self, color: Color) -> bool {
        let king_pos = match self.find_king(color) {
            Some(pos) => pos,
            None => return false,
        };

        for rank in 0..8 {
            for file in 0..8 {
                if let Some(attacker) = self.piece_at((rank, file)) {
                    if attacker.color() != color {
                        if self.can_attack_square((rank, file), king_pos) {
                            return true;
                        }
                    }
                }
            }
        }

        false
    }

    pub fn can_attack_square(&self, from: (usize, usize), to: (usize, usize)) -> bool {
        if let Some(piece) = self.piece_at(from) {
            self.is_valid_piece_move(piece, from, to)
        } else {
            false
        }
    }

    pub fn find_king(&self, color: Color) -> Option<(usize, usize)> {
        for r in 0..8 {
            for f in 0..8 {
                if let Some(p) = self.piece_at((r, f)) {
                    if p.to_type() == PieceType::King && p.color() == color {
                        return Some((r, f));
                    }
                }
            }
        }
        None
    }

    pub fn any_legal_move(&self, color: Color) -> bool {
        for from_r in 0..8 {
            for from_f in 0..8 {
                let from = (from_r, from_f);
                if let Some(piece) = self.piece_at(from) {
                    if piece.color() != color {
                        continue;
                    }

                    for to_r in 0..8 {
                        for to_f in 0..8 {
                            let to = (to_r, to_f);
                            if from == to {
                                continue;
                            }
                            if Board::is_valid_pos(to) && self.is_move_legal(from, to, None) {
                                return true;
                            }
                        }
                    }
                }
            }
        }
        false
    }
}
