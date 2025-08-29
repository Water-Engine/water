use crate::core::{board::*, piece::*};
use crate::coupling::EngineHandle;
use crate::gui::{DEFAULT_BOARD_SIZE, DEFAULT_PIECE_SIZE};

use eframe::egui::{self, Color32, Context, IconData, Painter, Pos2, Vec2};
use eframe::{App, Frame};
use rodio::{OutputStream, OutputStreamBuilder};

static ICON: &[u8] = include_bytes!("../../assets/cactus-icon.png");

pub struct Cactus {
    pub board: Board,
    pub images: PieceImages,
    pub board_size: Vec2,
    pub dragging: Option<(PieceKind, usize, usize)>,
    pub drag_pos: Pos2,
    pub selected: Option<(usize, usize)>,
    pub clear_selection: bool,
    pub painter: Option<Painter>,
    pub size: Vec2,
    pub audio_stream: Option<OutputStream>,
    pub promotion_pending: Option<((usize, usize), (usize, usize))>,
    pub show_game_over_popup: bool,

    pub white_engine: Option<EngineHandle>,
    pub black_engine: Option<EngineHandle>,
    pub waiting_for_engine_move: bool,
}

impl Cactus {
    pub fn new(
        ctx: &egui::Context,
        white_engine: Option<EngineHandle>,
        black_engine: Option<EngineHandle>,
    ) -> Self {
        let mut handle =
            OutputStreamBuilder::open_default_stream().expect("Failed to initialize audio");
        handle.log_on_drop(false);

        Self {
            board: Board::default(),
            images: PieceImages::new(ctx, DEFAULT_PIECE_SIZE),
            board_size: Vec2::splat(400.0),
            dragging: None,
            drag_pos: Pos2::default(),
            selected: None,
            clear_selection: false,
            painter: None,
            size: Vec2::default(),
            audio_stream: Some(handle),
            promotion_pending: None,
            show_game_over_popup: false,

            white_engine: white_engine,
            black_engine: black_engine,
            waiting_for_engine_move: false,
        }
    }
}

impl App for Cactus {
    fn update(&mut self, ctx: &Context, frame: &mut Frame) {
        egui::CentralPanel::default()
            .frame(egui::Frame::new().fill(Color32::from_rgb(83, 83, 83)))
            .show(ctx, |ui| {
                let response = self.handle_event(ctx, frame, ui);
                self.render(&response, ctx);

                self.try_engine_turn(1000);
            });

        // Force a reload even if the user is not interacting with the app
        ctx.request_repaint_after(std::time::Duration::from_millis(16));
    }
}

pub fn launch(white_engine: Option<EngineHandle>, black_engine: Option<EngineHandle>) {
    let image = image::load_from_memory(ICON)
        .expect("Failed to decode icon")
        .into_rgba8();
    let (width, height) = image.dimensions();
    let rgba = image.into_raw();

    let icon_data = IconData {
        rgba,
        width,
        height,
    };

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder {
            min_inner_size: Some(Vec2::from((DEFAULT_BOARD_SIZE, DEFAULT_BOARD_SIZE))),
            max_inner_size: Some(Vec2::from((DEFAULT_BOARD_SIZE, DEFAULT_BOARD_SIZE))),
            resizable: Some(false),
            fullscreen: Some(false),
            maximize_button: Some(false),
            icon: Some(std::sync::Arc::new(icon_data)),
            ..Default::default()
        },
        ..Default::default()
    };

    eframe::run_native(
        "Cactus",
        options,
        Box::new(|cc| {
            Ok(Box::new(Cactus::new(
                &cc.egui_ctx,
                white_engine,
                black_engine,
            )))
        }),
    )
    .expect("Failed to launch Cactus")
}
