// This module provides functions for printing global help/usage information
// and program metadata (name, version, license, repository, git hash).

use owo_colors::OwoColorize;

const NAME: &str = env!("CARGO_PKG_NAME");
const VERSION: &str = env!("CARGO_PKG_VERSION");
const LICENSE: &str = env!("CARGO_PKG_LICENSE");
const REPOSITORY: &str = env!("CARGO_PKG_REPOSITORY");
const GIT_HASH: &str = env!("GIT_HASH");

pub fn display_program_info() {
    print!("{}", NAME.bright_green().bold());
    print!("{}", format!(" v{}", VERSION).bright_yellow());
    println!("{}", format!(" git({})", GIT_HASH).bright_blue());
    println!(
        "Distributed under {} by Cactus developers,",
        LICENSE.yellow()
    );
    println!("for more info: {}", REPOSITORY.green());
}

pub fn display_global_help() {
    // displaying cli info at top
    println!(
        "{}",
        format!(
            "{}: A CLI tool to run and manage chess engine tournaments\n",
            NAME.bright_green().bold()
        )
        .bright_white()
        .bold()
    );

    // Display Usage
    print!("{}", "Usage: ".bright_yellow().bold());
    print!("{}", "cactus-cli ".bright_green().bold());
    println!("{}", "[COMMANDS] <FLAGS> [ARGS]\n".green());

    // Display commands
    println!("{}", "Commands: ".bright_yellow().bold());
    // The initialization command
    print!("{}", "    init".bright_green().bold());
    println!("              Initialize a new cactus.toml template at pwd");
    // The run command
    print!("{}", "    run".bright_green().bold());
    println!("               Run the matchup defined in cactus.toml");

    // Display Flags
    println!("{}", "\nFlags: ".bright_yellow().bold());
    // Help flag
    print!("{}", "    --help".bright_green().bold());
    println!("            Show context sensitive help info");
    // Version flag
    print!("{}", "    --info".bright_green().bold());
    println!("            Show program information");
}

pub fn display_run_command_help() {
    // displaying cli info at top
    println!(
        "{}",
        format!(
            "{}: A CLI tool to run and manage chess engine tournaments\n",
            NAME.bright_green().bold()
        )
        .bright_white()
        .bold()
    );

    // Display Usage
    print!("{}", "Usage: ".bright_yellow().bold());
    print!("{}", "cactus-cli run ".bright_green().bold());
    println!("{}", "[FLAGS]\n".green());

    // Display Flags
    println!("{}", "Flags: ".bright_yellow().bold());
    // working directory flag
    print!("{}", "    --cwd".bright_green().bold());
    println!("             Set a working directory");
    // Validate flag
    print!("{}", "    --dry".bright_green().bold());
    println!("             Dry run to prevent misconfigured runs");
    // event flag
    print!("{}", "    --event".bright_green().bold());
    println!("           Run a event specified in cactus.toml");
}
