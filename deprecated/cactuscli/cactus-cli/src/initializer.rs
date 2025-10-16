use crate::utils::cactus_toml_exists;
use owo_colors::OwoColorize;
use std::{fs, path::PathBuf};

pub fn initialize_cactus_resources(working_dir: PathBuf) {
    // Check if cactus.toml already exists
    if cactus_toml_exists(&working_dir) {
        eprintln!(
            "{}",
            format!(
                "-> Error: cactus.toml already exists at: {}",
                working_dir.display().bright_yellow()
            )
            .bright_red()
        );
        eprintln!(
            "{}",
            "-> Reinitialization is not supported, please edit the existing file instead."
                .bright_red()
        );
        return;
    }

    let path = working_dir.join("cactus.toml");

    // Default cactus.toml template
    let template = r#"# This is a starter template for running cactus.
# Refer to the documentation for more info on the commands.

[events.default]
# The `default` event is used when no event is specified using the --event flag for `cactus-cli run`.
# If no event named `default` is specified in config, make sure to use the --event flag to specify your custom one.

# Define the engines participating in the event, optionally specify their paths.
# note that, if no path specified make sure that `name` matches the executable name.
engines = [
    { name = "stockfish" },
    { name = "ethereal", path = "/path/to/Ethereal" },
    { name = "lc0", args = "--threads=12"}
]

# Define a game variant to be used in event. Currently `standard` and `fisherrandom` are supported.
variant = "standard"

# Define the type of tournament
tournament = "swiss"

# Define the time control for the event
time_control = "5+0"

# Define rounds of games to play. Each game within the round uses the same opening.
rounds = 100

# Define the number of games in each round. setting this higher than 2, does not provide meaningful results.
games = 2

# Define maximum number of moves
# maxmoves = 40

# Define games played concurrently, limited by the number of hardware threads.
concurrency = 1

# Specify the format for export. Currently only PGN is supported.
export_format = "PGN"

[events.rapid]
# This is your custom event, pass `--event rapid`, to `cactus-cli run` to host this event.
engines = [
    { name = "stockfish" },
    { name = "lc0" }
]
variant = "standard"
tournament = "round-robin"
time_control = "10+0"
rounds = 50
games = 2
maxmoves = 100
concurrency = 1
export_format = "PGN"
"#;

    // Create cactus.toml
    fs::write(path, template).expect("Could not create cactus.toml");

    // Pretty success output
    println!(
        "{}",
        format!(
            "-> Successfully created cactus.toml at: {}",
            working_dir.display().bright_yellow()
        )
        .bright_green()
    );
}
