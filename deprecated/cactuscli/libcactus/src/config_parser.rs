use serde::Deserialize;
use std::collections::HashMap;
use std::{fs, path::Path};

#[derive(Debug, Deserialize)]
pub struct Config {
    pub events: HashMap<String, Event>,
}

#[derive(Debug, Deserialize)]
pub struct Event {
    pub engines: Vec<Engine>,
    pub variant: String,
    pub tournament: String,
    pub time_control: String,
    pub rounds: u32,
    pub games: Option<u32>,
    pub maxmoves: Option<u32>,
    pub concurrency: Option<u32>,
    pub export_format: String,
}

#[derive(Debug, Deserialize)]
pub struct Engine {
    pub name: String,
    pub path: Option<String>,
    pub args: Option<String>,
}

#[derive(Debug)]
pub enum ConfigError {
    Io(std::io::Error),
    Parse(toml::de::Error),
}

pub fn parse_cactus_toml<P: AsRef<Path>>(path: P) -> Result<Config, ConfigError> {
    let content = fs::read_to_string(path).map_err(ConfigError::Io)?;
    let config: Config = toml::from_str(&content).map_err(ConfigError::Parse)?;
    Ok(config)
}
