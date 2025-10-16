pub mod external;
pub mod integration;

use std::{
    sync::mpsc::{Receiver, Sender},
    time::Duration,
};

#[derive(Debug)]
pub struct EngineHandle {
    pub cmd_sender: Sender<String>,
    pub response_receiver: Receiver<String>,
}

impl EngineHandle {
    pub fn send_command(&self, cmd: String) {
        let _ = self.cmd_sender.send(cmd);
    }

    pub fn try_receive_response(&self) -> Option<String> {
        self.response_receiver
            .recv_timeout(Duration::from_millis(10))
            .ok()
    }
}
