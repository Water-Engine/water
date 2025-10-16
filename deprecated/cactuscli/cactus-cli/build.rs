fn main() {
    let output = std::process::Command::new("git")
        .args(&["rev-parse", "--short", "HEAD"])
        .output()
        .expect("Failed to get git commit hash");

    let git_hash = String::from_utf8(output.stdout).unwrap();
    println!("cargo:rustc-env=GIT_HASH={}", git_hash.trim());
}
