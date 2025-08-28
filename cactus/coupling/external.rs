use crate::coupling::EngineHandle;

use std::io::{BufRead, BufReader, Read, Write};
use std::process::{ChildStdin, ChildStdout, Command, Stdio};
use std::sync::mpsc::channel;
use std::thread;

pub struct ExternalEngine {
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl ExternalEngine {
    pub fn spawn_threaded(path: &str) -> std::io::Result<EngineHandle> {
        let (cmd_sender, cmd_receiver) = channel::<String>();
        let (response_sender, response_receiver) = channel::<String>();

        let path = path.to_string();

        thread::spawn(move || {
            let mut engine = ExternalEngine::new(&path).expect("Failed to start engine");
            engine.start();

            for cmd in cmd_receiver.iter() {
                engine.send(&cmd);

                if cmd.starts_with("go") {
                    let lines = engine.read_lines_until("bestmove");
                    for line in lines {
                        if line.starts_with("bestmove") {
                            let _ = response_sender.send(line);
                            break;
                        }
                    }
                }
            }
        });

        Ok(EngineHandle {
            cmd_sender,
            response_receiver,
        })
    }

    fn new(path: &str) -> std::io::Result<Self> {
        let mut process = Command::new(path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;

        let stdin = process.stdin.take().expect("Failed to open stdin");
        let stdout = BufReader::new(process.stdout.take().expect("Failed to open stdout"));

        let mut engine = Self { stdin, stdout };
        engine.start();
        Ok(engine)
    }

    fn send(&mut self, cmd: &str) {
        writeln!(self.stdin, "{}", cmd).unwrap();
        self.stdin.flush().unwrap();
    }

    fn read_lines_until(&mut self, keyword: &str) -> Vec<String> {
        let mut lines = Vec::new();
        for line in self.stdout.by_ref().lines() {
            let line = line.unwrap();
            lines.push(line.clone());
            if line.contains(keyword) {
                break;
            }
        }
        lines
    }

    fn start(&mut self) {
        self.send("uci");
        self.read_lines_until("uciok");

        self.send("setoption name Ponder value false");

        self.send("isready");
        self.read_lines_until("readyok");
    }
}
