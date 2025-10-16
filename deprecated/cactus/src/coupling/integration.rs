use crate::{
    core::{
        Color,
        board::{Board, State},
        piece::{PieceKind, PieceType},
    },
    gui::launch::Cactus,
    moves::moves::Move,
};

impl Board {
    pub fn parse_uci_move(&self, uci: &str) -> Option<Move> {
        let bytes = uci.as_bytes();
        if bytes.len() < 4 {
            return None;
        }

        let f1 = (bytes[0] - b'a') as usize;
        let r1 = 8 - (bytes[1] - b'0') as usize;
        let f2 = (bytes[2] - b'a') as usize;
        let r2 = 8 - (bytes[3] - b'0') as usize;

        let from = (r1, f1);
        let to = (r2, f2);

        let piece = self.piece_at(from)?;

        let promotion = if bytes.len() == 5 {
            Some(match bytes[4] as char {
                'q' => PieceType::Queen,
                'r' => PieceType::Rook,
                'b' => PieceType::Bishop,
                'n' => PieceType::Knight,
                _ => return None,
            })
        } else {
            None
        };

        Some(Move {
            from,
            to,
            promotion,
            piece,
        })
    }

    pub fn move_history_uci(&self) -> Vec<String> {
        self.moves.iter().map(|m| m.to_uci()).collect()
    }

    pub fn apply_uci_move(&mut self, uci: &str) -> (Option<PieceKind>, bool) {
        if let Some(mv) = self.parse_uci_move(uci) {
            let promotion = mv.promotion.map(|pt| PieceKind::new(pt, mv.piece.color()));
            match self.move_piece(mv.from, mv.to, promotion) {
                Ok((_, captured)) => (captured, true),
                Err(e) => {
                    eprintln!("Failed to apply UCI move `{}`: {}", uci, e);
                    (None, false)
                }
            }
        } else {
            eprintln!("Invalid UCI move: `{}`", uci);
            (None, false)
        }
    }
}

impl Cactus {
    pub fn try_engine_turn(&mut self, thinking_time_ms: usize) {
        let engine = match self.board.state {
            State::Playing { turn: Color::White } => self.white_engine.as_ref(),
            State::Playing { turn: Color::Black } => self.black_engine.as_ref(),
            _ => return,
        };

        if self.is_engine_turn() && !self.waiting_for_engine_move {
            if let Some(engine) = engine {
                let uci_moves = self.board.move_history_uci();
                let position_cmd = format!("position startpos moves {}", uci_moves.join(" "));
                engine.send_command(position_cmd);
                engine.send_command(format!("go movetime {thinking_time_ms}"));

                self.waiting_for_engine_move = true;
            }
            return;
        }

        if let Some(engine) = engine {
            if let Some(bestmove_line) = engine.try_receive_response() {
                if let Some(bestmove) = uci_word(&bestmove_line) {
                    let result = self.board.apply_uci_move(&bestmove);
                    match result {
                        (Some(_), true) => self.capture_sound(),
                        (None, true) => self.move_sound(),
                        _ => {}
                    }
                    self.board.update_state();
                    match self.board.state {
                        State::Checkmate { .. } | State::Stalemate | State::Draw => {
                            self.handle_game_over();
                        }
                        _ => {}
                    }
                    self.waiting_for_engine_move = false;
                }
            }
        }
    }

    fn is_engine_turn(&self) -> bool {
        match &self.board.state {
            State::Playing { turn: Color::White } => self.white_engine.is_some(),
            State::Playing { turn: Color::Black } => self.black_engine.is_some(),
            _ => false,
        }
    }
}

pub fn uci_word(line: &str) -> Option<String> {
    let tokens: Vec<&str> = line.trim().split_whitespace().collect();
    if tokens.len() >= 2 && tokens[0] == "bestmove" {
        Some(tokens[1].to_string())
    } else {
        None
    }
}
