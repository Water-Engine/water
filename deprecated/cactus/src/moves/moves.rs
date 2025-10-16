use crate::core::{
    Color,
    board::Board,
    piece::{PieceKind, PieceType},
};

#[derive(Clone)]
pub struct Move {
    pub from: (usize, usize),
    pub to: (usize, usize),
    pub promotion: Option<PieceType>,
    pub piece: PieceKind,
}

impl Move {
    pub fn to_uci(&self) -> String {
        let (rank1, file1) = self.from;
        let (rank2, file2) = self.to;

        let mut s = format!(
            "{}{}{}{}",
            (b'a' + file1 as u8) as char,
            8 - rank1,
            (b'a' + file2 as u8) as char,
            8 - rank2,
        );

        if let Some(promo) = self.promotion {
            s.push(match promo {
                PieceType::Queen => 'q',
                PieceType::Rook => 'r',
                PieceType::Bishop => 'b',
                PieceType::Knight => 'n',
                _ => unreachable!(),
            });
        }

        s
    }
}

impl Board {
    pub fn update_castling_flags(&mut self, from: (usize, usize), piece: PieceKind) {
        match piece {
            PieceKind::WhiteKing => self.flags.has_white_king_moved = true,
            PieceKind::BlackKing => self.flags.has_black_king_moved = true,
            PieceKind::WhiteRook => match from {
                (7, 0) => self.flags.has_white_queenside_rook_moved = true,
                (7, 7) => self.flags.has_white_kingside_rook_moved = true,
                _ => {}
            },
            PieceKind::BlackRook => match from {
                (0, 0) => self.flags.has_black_queenside_rook_moved = true,
                (0, 7) => self.flags.has_black_kingside_rook_moved = true,
                _ => {}
            },
            _ => {}
        }
    }

    pub fn update_en_passant_target(
        &mut self,
        from: (usize, usize),
        to: (usize, usize),
        piece: PieceKind,
    ) {
        if piece.to_type() == PieceType::Pawn {
            let dir: isize = match piece.color() {
                Color::White => -1,
                Color::Black => 1,
            };
            let from_rank = from.0 as isize;
            let to_rank = to.0 as isize;

            if (to_rank - from_rank) == 2 * dir {
                self.en_passant_target = Some(((from_rank + dir) as usize, from.1));
                return;
            }
        }
        self.en_passant_target = None;
    }

    pub fn handle_en_passant(
        &mut self,
        from: (usize, usize),
        to: (usize, usize),
        piece: PieceKind,
    ) -> Option<PieceKind> {
        if piece.to_type() != PieceType::Pawn {
            return None;
        }

        let dir: isize = match piece.color() {
            Color::White => -1,
            Color::Black => 1,
        };

        let from_rank = from.0 as isize;
        let to_rank = to.0 as isize;
        let from_file = from.1;
        let to_file = to.1;

        if let Some((ep_rank, ep_file)) = self.en_passant_target {
            if (to.0, to.1) == (ep_rank, ep_file)
                && (from_file as isize - to_file as isize).abs() == 1
                && (to_rank - from_rank) == dir
                && self.piece_at(to).is_none()
            {
                let captured_pos = ((to_rank - dir) as usize, to_file);
                let captured = self.piece_at(captured_pos);
                self.set_piece(captured_pos, None);
                return captured;
            }
        }

        None
    }

    pub fn handle_castling(&mut self, from: (usize, usize), to: (usize, usize)) {
        let Some(piece) = self.piece_at(from) else {
            return;
        };
        if piece.to_type() != PieceType::King {
            return;
        }

        match (from, to) {
            ((fr, 4), (tr, 6)) if fr == tr => {
                let rook_from = (fr, 7);
                let rook_to = (fr, 5);
                if let Some(rook) = self.piece_at(rook_from) {
                    self.set_piece(rook_to, Some(rook));
                    self.set_piece(rook_from, None);
                }
            }
            ((fr, 4), (tr, 2)) if fr == tr => {
                let rook_from = (fr, 0);
                let rook_to = (fr, 3);
                if let Some(rook) = self.piece_at(rook_from) {
                    self.set_piece(rook_to, Some(rook));
                    self.set_piece(rook_from, None);
                }
            }
            _ => {}
        }
    }

    pub fn validate_no_self_capture(
        &self,
        to: (usize, usize),
        color: Color,
    ) -> Result<Option<PieceKind>, String> {
        if let Some(target) = self.piece_at(to) {
            if target.color() == color {
                return Err("Cannot capture your own piece".into());
            }
            return Ok(Some(target));
        }
        Ok(None)
    }
}
