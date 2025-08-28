use std::hash::{DefaultHasher, Hash, Hasher};

use crate::core::{
    board::{Board, State},
    piece::PieceType,
};

impl Board {
    pub fn has_sufficient_material(&self) -> bool {
        let mut pieces = vec![];

        for rank in &self.squares {
            for square in rank {
                if let Some(piece) = square.piece {
                    pieces.push(piece);
                }
            }
        }

        match pieces.len() {
            2 => true,
            3 => pieces
                .iter()
                .any(|p| matches!(p.to_type(), PieceType::Bishop | PieceType::Knight)),
            4 => {
                let bishops: Vec<_> = pieces
                    .iter()
                    .filter(|p| p.to_type() == PieceType::Bishop)
                    .collect();
                bishops.len() == 2 && bishops.iter().all(|b| b.color() != bishops[0].color())
            }
            _ => true,
        }
    }

    pub fn compute_position_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        self.hash(&mut hasher);
        hasher.finish()
    }
}

impl Hash for Board {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        for rank in 0..8 {
            for file in 0..8 {
                if let Some(piece) = self.squares[rank][file].piece {
                    (rank, file, piece).hash(state);
                }
            }
        }

        match self.state {
            State::Playing { turn } => turn.hash(state),
            _ => {}
        }

        self.flags.has_white_king_moved.hash(state);
        self.flags.has_white_kingside_rook_moved.hash(state);
        self.flags.has_white_queenside_rook_moved.hash(state);
        self.flags.has_black_king_moved.hash(state);
        self.flags.has_black_kingside_rook_moved.hash(state);
        self.flags.has_black_queenside_rook_moved.hash(state);

        self.en_passant_target.hash(state);
    }
}
