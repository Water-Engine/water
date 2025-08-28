use crate::coupling::{EngineHandle, external::ExternalEngine};

mod core;
mod coupling;
mod gui;
mod moves;

fn main() {
    let args: Vec<String> = std::env::args()
        .skip(1)
        .map(|s| s.trim().to_string())
        .collect();

    let mut maybe_white_engine: Option<EngineHandle> = None;
    let mut maybe_black_engine: Option<EngineHandle> = None;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "white" if i + 1 < args.len() => {
                let path = &args[i + 1];
                maybe_white_engine = ExternalEngine::spawn_threaded(path).ok();
                i += 2;
            }
            "black" if i + 1 < args.len() => {
                let path = &args[i + 1];
                maybe_black_engine = ExternalEngine::spawn_threaded(path).ok();
                i += 2;
            }
            _ => {
                eprintln!("Ignoring unknown argument: {}", args[i]);
                i += 1;
            }
        }
    }

    gui::launch::launch(maybe_white_engine, maybe_black_engine);
}
