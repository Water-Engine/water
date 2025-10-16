use crate::core::Color;

use std::collections::HashMap;

use eframe::egui::{self, ColorImage, Context, TextureHandle, Vec2};
use resvg::usvg;
use tiny_skia::{Pixmap, Transform};

pub static BLACK_BISHOP: &[u8] = include_bytes!("../../assets/cburnett/bB.svg");
pub static BLACK_KING: &[u8] = include_bytes!("../../assets/cburnett/bK.svg");
pub static BLACK_KNIGHT: &[u8] = include_bytes!("../../assets/cburnett/bN.svg");
pub static BLACK_PAWN: &[u8] = include_bytes!("../../assets/cburnett/bP.svg");
pub static BLACK_QUEEN: &[u8] = include_bytes!("../../assets/cburnett/bQ.svg");
pub static BLACK_ROOK: &[u8] = include_bytes!("../../assets/cburnett/bR.svg");
pub static WHITE_BISHOP: &[u8] = include_bytes!("../../assets/cburnett/wB.svg");
pub static WHITE_KING: &[u8] = include_bytes!("../../assets/cburnett/wK.svg");
pub static WHITE_KNIGHT: &[u8] = include_bytes!("../../assets/cburnett/wN.svg");
pub static WHITE_PAWN: &[u8] = include_bytes!("../../assets/cburnett/wP.svg");
pub static WHITE_QUEEN: &[u8] = include_bytes!("../../assets/cburnett/wQ.svg");
pub static WHITE_ROOK: &[u8] = include_bytes!("../../assets/cburnett/wR.svg");

pub struct Piece<'a> {
    pub bytes: &'a [u8],
}

#[derive(Copy, Clone, Debug, Hash, Eq, PartialEq)]
pub enum PieceKind {
    BlackBishop,
    BlackKing,
    BlackKnight,
    BlackPawn,
    BlackQueen,
    BlackRook,
    WhiteBishop,
    WhiteKing,
    WhiteKnight,
    WhitePawn,
    WhiteQueen,
    WhiteRook,
}

#[derive(Copy, Clone, PartialEq, Eq, Debug)]
pub enum PieceType {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
}

impl PieceKind {
    pub fn new(piece_type: PieceType, color: Color) -> Self {
        use Color::*;
        use PieceKind::*;
        use PieceType::*;

        match (piece_type, color) {
            (Pawn, White) => WhitePawn,
            (Knight, White) => WhiteKnight,
            (Bishop, White) => WhiteBishop,
            (Rook, White) => WhiteRook,
            (Queen, White) => WhiteQueen,
            (King, White) => WhiteKing,

            (Pawn, Black) => BlackPawn,
            (Knight, Black) => BlackKnight,
            (Bishop, Black) => BlackBishop,
            (Rook, Black) => BlackRook,
            (Queen, Black) => BlackQueen,
            (King, Black) => BlackKing,
        }
    }

    pub fn color(&self) -> Color {
        use PieceKind::*;

        match self {
            WhiteBishop | WhiteKing | WhiteKnight | WhitePawn | WhiteQueen | WhiteRook => {
                Color::White
            }
            BlackBishop | BlackKing | BlackKnight | BlackPawn | BlackQueen | BlackRook => {
                Color::Black
            }
        }
    }

    pub fn to_type(&self) -> PieceType {
        use PieceKind::*;
        use PieceType::*;

        match self {
            WhitePawn | BlackPawn => Pawn,
            WhiteKnight | BlackKnight => Knight,
            WhiteBishop | BlackBishop => Bishop,
            WhiteRook | BlackRook => Rook,
            WhiteQueen | BlackQueen => Queen,
            WhiteKing | BlackKing => King,
        }
    }

    pub fn score(&self) -> usize {
        match self.to_type() {
            PieceType::Pawn => 1,
            PieceType::Knight => 3,
            PieceType::Bishop => 3,
            PieceType::Rook => 5,
            PieceType::Queen => 9,
            PieceType::King => 0,
        }
    }
}

impl<'a> Piece<'a> {
    pub fn from_kind(kind: PieceKind) -> Self {
        let bytes = match kind {
            PieceKind::BlackBishop => BLACK_BISHOP,
            PieceKind::BlackKing => BLACK_KING,
            PieceKind::BlackKnight => BLACK_KNIGHT,
            PieceKind::BlackPawn => BLACK_PAWN,
            PieceKind::BlackQueen => BLACK_QUEEN,
            PieceKind::BlackRook => BLACK_ROOK,
            PieceKind::WhiteBishop => WHITE_BISHOP,
            PieceKind::WhiteKing => WHITE_KING,
            PieceKind::WhiteKnight => WHITE_KNIGHT,
            PieceKind::WhitePawn => WHITE_PAWN,
            PieceKind::WhiteQueen => WHITE_QUEEN,
            PieceKind::WhiteRook => WHITE_ROOK,
        };

        Self { bytes }
    }
}

pub struct PieceImages {
    textures: HashMap<PieceKind, TextureHandle>,
    captures: HashMap<PieceKind, TextureHandle>,
}

impl PieceImages {
    pub fn new(ctx: &Context, pixel_size: f32) -> Self {
        let mut textures = HashMap::new();
        let mut captures = HashMap::new();

        let data = [
            (PieceKind::WhitePawn, WHITE_PAWN),
            (PieceKind::WhiteKnight, WHITE_KNIGHT),
            (PieceKind::WhiteBishop, WHITE_BISHOP),
            (PieceKind::WhiteRook, WHITE_ROOK),
            (PieceKind::WhiteQueen, WHITE_QUEEN),
            (PieceKind::WhiteKing, WHITE_KING),
            (PieceKind::BlackPawn, BLACK_PAWN),
            (PieceKind::BlackKnight, BLACK_KNIGHT),
            (PieceKind::BlackBishop, BLACK_BISHOP),
            (PieceKind::BlackRook, BLACK_ROOK),
            (PieceKind::BlackQueen, BLACK_QUEEN),
            (PieceKind::BlackKing, BLACK_KING),
        ];

        for (kind, svg_bytes) in data {
            let img = Self::svg_to_image(svg_bytes, pixel_size);
            let texture =
                ctx.load_texture(format!("{:?}", kind), img, egui::TextureOptions::default());
            textures.insert(kind, texture);

            let img = Self::svg_to_image(svg_bytes, pixel_size / 2.0);
            let texture =
                ctx.load_texture(format!("{:?}", kind), img, egui::TextureOptions::default());
            captures.insert(kind, texture);
        }

        Self { textures, captures }
    }

    pub fn update_textures(&mut self, ctx: &egui::Context, pixel_size: f32) {
        for (kind, texture) in self.textures.iter_mut() {
            let piece = Piece::from_kind(*kind);
            let svg_bytes = piece.bytes;

            let img = Self::svg_to_image(svg_bytes, pixel_size);

            *texture =
                ctx.load_texture(format!("{:?}", kind), img, egui::TextureOptions::default());
        }

        for (kind, texture) in self.captures.iter_mut() {
            let piece = Piece::from_kind(*kind);
            let svg_bytes = piece.bytes;

            let img = Self::svg_to_image(svg_bytes, pixel_size / 2.0);

            *texture =
                ctx.load_texture(format!("{:?}", kind), img, egui::TextureOptions::default());
        }
    }

    pub fn get_texture(&self, kind: PieceKind) -> &TextureHandle {
        self.textures.get(&kind).expect("Unknown PieceKind")
    }

    fn svg_to_image(svg_data: &[u8], size: f32) -> ColorImage {
        let opt = usvg::Options::default();
        let rtree = usvg::Tree::from_data(svg_data, &opt).expect("Invalid SVG");

        let pixmap_size = size.ceil() as u32;
        let mut pixmap = Pixmap::new(pixmap_size, pixmap_size).unwrap();
        let scale_factor = pixmap_size as f32 / rtree.size().width();

        resvg::render(
            &rtree,
            Transform::from_scale(scale_factor, scale_factor),
            &mut pixmap.as_mut(),
        );

        let image = pixmap.data();
        let mut pixels = Vec::with_capacity((pixmap_size * pixmap_size) as usize);
        for chunk in image.chunks(4) {
            pixels.push(egui::Color32::from_rgba_unmultiplied(
                chunk[0], chunk[1], chunk[2], chunk[3],
            ));
        }

        ColorImage {
            size: [pixmap_size as usize, pixmap_size as usize],
            source_size: Vec2::splat(pixmap_size as f32),
            pixels,
        }
    }
}
