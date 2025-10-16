use std::env;
use std::path::PathBuf;

pub fn cactus_toml_exists(working_dir: &PathBuf) -> bool {
    working_dir.join("cactus.toml").exists()
}

pub fn make_path_abs(path: &str) -> PathBuf {
    PathBuf::from(path).canonicalize().unwrap_or_else(|_| {
        // Fallback if path doesn't exist yet
        let p = PathBuf::from(path);
        if p.is_absolute() {
            p
        } else {
            env::current_dir().unwrap().join(p)
        }
    })
}
