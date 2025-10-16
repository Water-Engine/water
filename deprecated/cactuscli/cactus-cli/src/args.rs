use crate::helper::{display_global_help, display_program_info, display_run_command_help};
use crate::initializer::initialize_cactus_resources;
use crate::runner::run_event_from_cactus_toml;
use crate::utils::make_path_abs;
use owo_colors::OwoColorize;
use std::path::PathBuf;
use std::{env, process::exit};

#[derive(Debug)]
pub struct RunFlags {
    pub cwd: PathBuf,
    pub dry_run: bool,
    pub event: String,
}

impl RunFlags {
    pub fn parse_run_command_args(args: &[String]) -> Result<Self, String> {
        let base =
            env::current_dir().map_err(|e| format!("Failed to get current directory: {}", e))?;

        let mut cwd = None;
        let mut dry_run = false;
        let mut event = None;
        let mut iter = args.iter();

        while let Some(arg) = iter.next() {
            match arg.as_str() {
                "--cwd" => {
                    if cwd.is_some() {
                        return Err("--cwd flag specified multiple times".to_string());
                    }
                    cwd = Some(iter.next().ok_or("--cwd requires a value")?.as_str());
                }
                "--dry" => {
                    if dry_run {
                        return Err("--dry flag specified multiple times".to_string());
                    }
                    dry_run = true;
                }
                "--event" => {
                    if event.is_some() {
                        return Err("--event flag specified multiple times".to_string());
                    }
                    event = Some(iter.next().ok_or("--event requires a value")?.as_str());
                }
                "--help" => {
                    display_run_command_help();
                    return Err("help displayed".to_string());
                }
                other if other.starts_with("--") => {
                    return Err(format!("Unknown flag: {}", other));
                }
                other => {
                    return Err(format!("Unexpected argument: {}", other));
                }
            }
        }

        Ok(Self {
            cwd: cwd.map(make_path_abs).unwrap_or(base),
            dry_run,
            event:
                event
                    .map(String::from)
                    .unwrap_or_else(|| "default".to_string()),
        })
    }
}

pub fn argument_parser() {
    let args: Vec<String> = std::env::args().collect();

    // Handle the case of no command provided
    if args.len() < 2 {
        eprint!("{}", "-> Error: No command provided".red());
        eprint!("\n-> Run ");
        eprint!("{}", "cactus-cli --help".bright_green());
        eprintln!(" to list all commands and usage info.");
        exit(1);
    }

    let arg = &args[1];

    match arg.as_str() {
        // Call resp functions for commands
        "init" => {
            // This variable looks for the 3rd argument provided to the cli.
            // Reads it as path and uses it as working directory, and
            // defaults to $pwd if nothing is provided
            let working_dir = args
                .get(2)
                .map(|s| make_path_abs(s))
                .unwrap_or_else(|| env::current_dir().expect("Failed to get current directory"));
            initialize_cactus_resources(working_dir)
        }
        "run" => run_event_from_cactus_toml(args),
        // Handling global flags
        "--help" => display_global_help(),
        "--info" => display_program_info(),
        _ => {
            print!(
                "{}",
                format!("-> Error: Invalid command provided: {}", arg).red()
            );
            print!("\n-> Run ");
            print!("{}", "cactus-cli --help".bright_green());
            println!(" to list all commands and usage info.");
        }
    }
}
