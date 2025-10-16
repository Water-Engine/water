use crate::runner::RunFlags;
use libcactus::config_parser;
use std::path::Path;
use which::which;

pub fn dry_run_event_from_config(opts: &RunFlags) {
    // Define a variable to hold the path to cactus.toml
    let cactus_config = &opts.cwd.join("cactus.toml");

    // Parse the cactus.toml using libcactus api
    match config_parser::parse_cactus_toml(cactus_config) {
        Ok(cactus_config) => match cactus_config.events.get(&opts.event) {
            Some(event) => {
                for (_i, engine) in event.engines.iter().enumerate() {
                    match &engine.path {
                        Some(engine_path) => find_engine_at_path(engine_path),
                        None => check_engine_existence(&engine.name),
                    }
                }
            }
            None => {
                eprintln!("Error: Event '{}' not found in config", opts.event);
            }
        },
        Err(e) => {
            eprintln!("Error parsing config file: {:?}", e);
        }
    }
}

fn check_engine_existence(engine: &String) {
    if which(engine).is_ok() {
        println!("Engine found: {}", engine);
    } else {
        println!("Engine not found: {}", engine);
    }
}

fn find_engine_at_path(path: &String) {
    if Path::new(path).exists() {
        println!("Engine found at: {}", path);
    } else {
        println!("Engine not found at: {}", path);
    }
}
