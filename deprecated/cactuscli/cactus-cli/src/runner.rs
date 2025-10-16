mod dryrun;

use crate::args::RunFlags;
use crate::runner::dryrun::dry_run_event_from_config;
use owo_colors::OwoColorize;

pub fn run_event_from_cactus_toml(args: Vec<String>) {
    match RunFlags::parse_run_command_args(&args) {
        Ok(flags) => {
            if !flags.cwd.join("cactus.toml").exists() {
                println!(
                    "{}",
                    "-> Error: Current working directory is not initialized.".red()
                );
                println!(
                    "{}",
                    "-> Run `cactus-cli init <cwd>` to initialize it first.".green()
                );
                println!(
                    "{}",
                    "-> Or specify a different cwd using `cactus-cli run --cwd <cwd>`".green()
                );
            }

            if flags.dry_run {
                dry_run_event_from_config(&flags);
                return;
            }
        }
        Err(e) => {
            eprintln!("{}", format!("-> Error: {}", e).red());
            // handle error (exit, return, etc.)
        }
    }
}
