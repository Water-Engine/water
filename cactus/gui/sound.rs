use crate::gui::launch::Cactus;

use std::io::Cursor;

use rodio::OutputStream;

pub static MOVE_SOUND: &[u8] = include_bytes!("../../assets/standard/Move.mp3");
pub static CAPTURE_SOUND: &[u8] = include_bytes!("../../assets/standard/Capture.mp3");
pub static GAME_OVER_SOUND: &[u8] = include_bytes!("../../assets/standard/GenericNotify.mp3");
pub static CONFIRMATION_SOUND: &[u8] = include_bytes!("../../assets/standard/Confirmation.mp3");

impl Cactus {
    fn play(handle: &OutputStream, bytes: &'static [u8]) {
        let mixer = handle.mixer();
        let sink = rodio::play(mixer, Cursor::new(bytes)).expect("Failed to play audio");
        sink.detach();
    }

    pub fn move_sound(&self) {
        if let Some(handle) = &self.audio_stream {
            Self::play(handle, MOVE_SOUND);
        }
    }

    pub fn capture_sound(&self) {
        if let Some(handle) = &self.audio_stream {
            Self::play(handle, CAPTURE_SOUND);
        }
    }

    pub fn game_over_sound(&self) {
        if let Some(handle) = &self.audio_stream {
            Self::play(handle, GAME_OVER_SOUND);
        }
    }

    pub fn confirmation_sound(&self) {
        if let Some(handle) = &self.audio_stream {
            Self::play(handle, CONFIRMATION_SOUND);
        }
    }
}
