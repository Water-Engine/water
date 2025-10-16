use crate::core::{
    Color,
    board::Board,
    piece::{PieceKind, PieceType},
};

impl Board {
    pub fn simulate_move(
        &self,
        from: (usize, usize),
        to: (usize, usize),
        promotion: Option<PieceKind>,
    ) -> Result<Board, String> {
        let mut clone = self.clone();
        let piece = clone.piece_at(from).ok_or("No piece at from")?;

        if !Board::is_valid_pos(to) {
            return Err("Invalid target position".into());
        }

        if !clone.is_valid_piece_move(piece, from, to) {
            return Err("Invalid piece move".into());
        }

        if let Some(target) = clone.piece_at(to) {
            if target.color() == piece.color() {
                return Err("Can't capture own piece".into());
            }
        }

        clone.set_piece(to, Some(piece));
        clone.set_piece(from, None);

        if piece.to_type() == PieceType::Pawn {
            let promotion_rank = match piece.color() {
                Color::White => 0,
                Color::Black => 7,
            };

            if to.0 == promotion_rank {
                let promo_piece = match promotion {
                    Some(p) => p,
                    None => return Err("Promotion piece not specified".into()),
                };

                match promo_piece.to_type() {
                    PieceType::Queen | PieceType::Rook | PieceType::Bishop | PieceType::Knight => {}
                    _ => return Err("Invalid promotion piece".into()),
                }

                clone.set_piece(to, Some(promo_piece));
            }
        }

        Ok(clone)
    }

    pub fn simulate_move_checked(
        &self,
        from: (usize, usize),
        to: (usize, usize),
        promotion: Option<PieceKind>,
    ) -> Result<(), String> {
        let new_board = self.simulate_move(from, to, promotion)?;
        let color = self.piece_at(from).unwrap().color();
        if new_board.is_in_check(color) {
            return Err("Move leaves king in check".into());
        }
        Ok(())
    }
}
