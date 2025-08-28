use crate::{core::board::Board, gui::launch::Cactus};

use eframe::{
    Frame,
    egui::{Context, Pos2, Rect, Response, Sense, Ui, Vec2},
};

impl Cactus {
    pub fn handle_event(&mut self, ctx: &Context, _frame: &mut Frame, ui: &mut Ui) -> Response {
        let max_size = ui.available_size();
        let size = Vec2::splat(max_size.x.min(max_size.y));
        let (rect, _) = ui.allocate_exact_size(size, Sense::hover());
        let response = ui.interact(rect, ui.id().with("chessboard"), Sense::click_and_drag());
        let painter = ui.painter_at(rect);
        self.painter = Some(painter);
        self.size = size;

        if self.board.center_at((0, 0)) == Some(Pos2::ZERO)
            || self.board_size != response.rect.size()
        {
            let mut new_board = self.board.refresh(response.rect);
            for rank in 0..8 {
                for file in 0..8 {
                    let pos = (rank, file);
                    new_board.set_piece(pos, self.board.piece_at(pos));
                }
            }
            self.board = new_board;
            self.board_size = response.rect.size();
        }

        let square_size = size.x / 8.0;
        self.maybe_update_textures(ctx, square_size);

        self.clear_selection = false;

        if self.show_game_over_popup {
            return response;
        }

        let pointer = ctx.input(|i| i.pointer.clone());
        if let Some(pos) = pointer.interact_pos() {
            if pointer.primary_pressed() {
                self.handle_pointer_pressed(pos, &response);
            }
            if pointer.primary_down() {
                self.handle_pointer_down(pos);
            }
            if pointer.primary_released() {
                self.handle_pointer_released(pos, &response);
            }
            if response.clicked() {
                self.handle_click_selection(&response);
            }

            if self.clear_selection {
                self.selected = None;
            }
        }

        response
    }

    pub fn maybe_update_textures(&mut self, ctx: &Context, square_size: f32) {
        let threshold = 25.0;
        if (square_size - self.board_size.x).abs() > threshold {
            self.images.update_textures(ctx, square_size * 0.9);
            self.board_size = Vec2::splat(square_size);
        }
    }

    pub fn get_square_at_pos(&self, pos: Pos2, board_rect: Rect) -> Option<(usize, usize)> {
        let square_size = board_rect.width() / 8.0;
        let col = ((pos.x - board_rect.left()) / square_size).floor() as usize;
        let row = ((pos.y - board_rect.top()) / square_size).floor() as usize;
        if Board::is_valid_pos((row, col)) {
            Some((row, col))
        } else {
            None
        }
    }

    pub fn reset_game(&mut self) {
        self.board = Board::default();
        self.board_size = Vec2::splat(400.0);
        self.dragging = None;
        self.drag_pos = Pos2::default();
        self.selected = None;
        self.clear_selection = false;
        self.painter = None;
        self.size = Vec2::default();
        self.promotion_pending = None;
        self.show_game_over_popup = false;
    }
}
