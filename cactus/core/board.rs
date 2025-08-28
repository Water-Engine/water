use crate::{
    core::{Color, STARTING_COLOR, piece::*},
    moves::moves::Move,
};

use std::collections::HashMap;

use eframe::egui::{Pos2, Rect};

#[derive(Copy, Clone, Debug)]
pub struct Square {
    pub piece: Option<PieceKind>,
}

#[derive(Clone)]
pub struct Board {
    pub squares: [[Square; 8]; 8],
    pub centers: [[Pos2; 8]; 8],
    pub state: State,
    pub players: Players,
    pub en_passant_target: Option<(usize, usize)>,
    pub flags: Flags,
    pub halfmove_clock: usize,
    pub position_history: HashMap<u64, usize>,
    pub moves: Vec<Move>,
}

#[derive(Copy, Clone, Default)]
pub struct Flags {
    pub has_white_king_moved: bool,
    pub has_white_kingside_rook_moved: bool,
    pub has_white_queenside_rook_moved: bool,
    pub has_black_king_moved: bool,
    pub has_black_kingside_rook_moved: bool,
    pub has_black_queenside_rook_moved: bool,
}

#[derive(Copy, Clone, Debug)]
pub enum State {
    Playing { turn: Color },
    Checkmate { winner: Color },
    Stalemate,
    Draw,
}

impl Default for State {
    fn default() -> Self {
        State::Playing {
            turn: STARTING_COLOR,
        }
    }
}

#[derive(Clone)]
pub struct Player {
    pub captures: Vec<PieceKind>,
    pub score: usize,
}

impl Default for Player {
    fn default() -> Self {
        Self {
            captures: Vec::new(),
            score: 0,
        }
    }
}

impl Player {
    pub fn add_capture(&mut self, piece: PieceKind) {
        self.captures.push(piece);
        self.score += piece.score();
    }
}

#[derive(Clone, Default)]
pub struct Players {
    pub white: Player,
    pub black: Player,
}

impl Default for Board {
    fn default() -> Self {
        use PieceKind::*;

        let empty_square = Square { piece: None };
        let squares = [[empty_square; 8]; 8];
        let centers = [[Pos2::ZERO; 8]; 8];

        let mut board = Board {
            squares,
            centers,
            state: State::default(),
            players: Players::default(),
            en_passant_target: None,
            flags: Flags::default(),
            halfmove_clock: 0,
            position_history: HashMap::new(),
            moves: Vec::new(),
        };

        for i in 0..8 {
            board.squares[1][i].piece = Some(BlackPawn);
            board.squares[6][i].piece = Some(WhitePawn);
        }
        let back_rank = [
            BlackRook,
            BlackKnight,
            BlackBishop,
            BlackQueen,
            BlackKing,
            BlackBishop,
            BlackKnight,
            BlackRook,
        ];
        let front_rank = [
            WhiteRook,
            WhiteKnight,
            WhiteBishop,
            WhiteQueen,
            WhiteKing,
            WhiteBishop,
            WhiteKnight,
            WhiteRook,
        ];

        for i in 0..8 {
            board.squares[0][i].piece = Some(back_rank[i]);
            board.squares[7][i].piece = Some(front_rank[i]);
        }

        board
    }
}

impl Board {
    pub fn is_valid_pos(pos: (usize, usize)) -> bool {
        let (r, f) = pos;
        r < 8 && f < 8
    }

    pub fn piece_at(&self, pos: (usize, usize)) -> Option<PieceKind> {
        if Self::is_valid_pos(pos) {
            let (r, f) = pos;
            self.squares[r][f].piece
        } else {
            None
        }
    }

    pub fn center_at(&self, (rank, file): (usize, usize)) -> Option<Pos2> {
        if Self::is_valid_pos((rank, file)) {
            Some(self.centers[rank][file])
        } else {
            None
        }
    }

    pub fn set_piece(&mut self, pos: (usize, usize), piece: Option<PieceKind>) {
        if Self::is_valid_pos(pos) {
            let (r, f) = pos;
            self.squares[r][f].piece = piece;
        }
    }

    pub fn move_piece(
        &mut self,
        from: (usize, usize),
        to: (usize, usize),
        promotion: Option<PieceKind>,
    ) -> Result<(PieceKind, Option<PieceKind>), String> {
        if !Self::is_valid_pos(from) || !Self::is_valid_pos(to) {
            return Err("Position out of bounds".into());
        }

        let piece = self.piece_at(from).ok_or("No piece at from-position")?;

        if let State::Playing { turn } = self.state {
            if piece.color() != turn {
                return Err("Not your turn".into());
            }
        } else {
            return Err("Game is not in playing state".into());
        }

        self.update_castling_flags(from, piece);

        let mut captured = self.handle_en_passant(from, to, piece);
        self.update_en_passant_target(from, to, piece);

        self.handle_castling(from, to);

        if captured.is_none() {
            captured = self.validate_no_self_capture(to, piece.color())?;
        }

        let promotion_rank = match piece.color() {
            Color::White => 0,
            Color::Black => 7,
        };

        let is_pawn_move = piece.to_type() == PieceType::Pawn;
        let promoted_piece = if is_pawn_move && to.0 == promotion_rank {
            if let Some(prom_piece) = promotion {
                if prom_piece.color() != piece.color() {
                    return Err("Promotion piece must be same color".into());
                }
                if !matches!(
                    prom_piece.to_type(),
                    PieceType::Queen | PieceType::Rook | PieceType::Bishop | PieceType::Knight
                ) {
                    return Err("Invalid promotion piece".into());
                }
                Some(prom_piece)
            } else {
                return Err("Promotion piece required".into());
            }
        } else {
            None
        };

        let current_player_mut = match piece.color() {
            Color::White => &mut self.players.white,
            Color::Black => &mut self.players.black,
        };

        if let Some(captured_piece) = captured {
            current_player_mut.add_capture(captured_piece);
        }

        self.set_piece(to, promoted_piece.or(Some(piece)));
        self.set_piece(from, None);

        let is_capture = captured.is_some();
        if is_pawn_move || is_capture {
            self.halfmove_clock = 0;
        } else {
            self.halfmove_clock += 1;
        }

        let mv = Move {
            from,
            to,
            promotion: promoted_piece.map(|p| p.to_type()),
            piece,
        };
        self.moves.push(mv);

        Ok((promoted_piece.unwrap_or(piece), captured))
    }

    pub fn update_state(&mut self) {
        let current_turn = match self.state {
            State::Playing { turn } => turn,
            _ => return,
        };

        let next_turn = current_turn.opponent();

        let in_check = self.is_in_check(next_turn);
        let has_moves = self.any_legal_move(next_turn);

        let hash = self.compute_position_hash();
        let entry = self.position_history.entry(hash).or_insert(0);
        *entry += 1;
        let num_repeats = *entry;

        self.state = if !has_moves && in_check {
            State::Checkmate {
                winner: current_turn,
            }
        } else if !self.has_sufficient_material() {
            State::Draw
        } else if num_repeats >= 3 || self.halfmove_clock >= 100 {
            State::Draw
        } else if has_moves {
            State::Playing {
                turn: current_turn.opponent(),
            }
        } else {
            State::Stalemate
        };
    }

    pub fn refresh(&self, rect: Rect) -> Self {
        use PieceKind::*;
        let square_size = rect.width() / 8.0;

        let mut centers = [[Pos2::ZERO; 8]; 8];
        for rank in 0..8 {
            for file in 0..8 {
                let x = rect.left() + (file as f32 + 0.5) * square_size;
                let y = rect.top() + (rank as f32 + 0.5) * square_size;
                centers[rank][file] = Pos2::new(x, y);
            }
        }

        let mut board = Board {
            squares: [[Square { piece: None }; 8]; 8],
            centers,
            state: self.state,
            players: self.players.clone(),
            en_passant_target: self.en_passant_target,
            flags: self.flags,
            halfmove_clock: self.halfmove_clock,
            position_history: self.position_history.clone(),
            moves: self.moves.clone(),
        };

        for i in 0..8 {
            board.squares[1][i].piece = Some(BlackPawn);
            board.squares[6][i].piece = Some(WhitePawn);
        }
        let back_rank = [
            BlackRook,
            BlackKnight,
            BlackBishop,
            BlackQueen,
            BlackKing,
            BlackBishop,
            BlackKnight,
            BlackRook,
        ];
        let front_rank = [
            WhiteRook,
            WhiteKnight,
            WhiteBishop,
            WhiteQueen,
            WhiteKing,
            WhiteBishop,
            WhiteKnight,
            WhiteRook,
        ];

        for i in 0..8 {
            board.squares[0][i].piece = Some(back_rank[i]);
            board.squares[7][i].piece = Some(front_rank[i]);
        }

        board
    }
}
