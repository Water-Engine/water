pub mod board;
pub mod piece;

pub const STARTING_COLOR: Color = Color::White;

#[derive(Copy, Clone, PartialEq, Eq, Debug, Hash)]
pub enum Color {
    White,
    Black,
}

impl Color {
    pub fn opponent(&self) -> Self {
        match self {
            Color::White => Color::Black,
            Color::Black => Color::White,
        }
    }
}
