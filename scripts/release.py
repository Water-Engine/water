import os
import shutil
import subprocess
import time

program_name = "water"
version = "0.0.1"
target_path = os.path.join("release", "targets")
compressed_path = os.path.join("release", "compressed")

# === Helpers ===
def safe_rmdir(path):
    if os.path.exists(path):
        shutil.rmtree(path)

def safe_mkdir(path):
    os.makedirs(path, exist_ok=True)

def run_command(cmd: str):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)

# === Setup output directories ===
safe_rmdir(target_path)
safe_mkdir(target_path)

safe_rmdir(compressed_path)
safe_mkdir(compressed_path)

# === Targets ===
win = ["x86_64", "aarch64", "x86"]
mac = ["x86_64", "aarch64"]
lin = ["x86_64", "arm", "aarch64", "x86", "riscv64", "loongarch64", "s390x"]

targets = {
    "windows": win,
    "macos": mac,
    "linux": lin,
}

operating_sys = ["linux", "macos", "windows"]

root = "zig build"
release_mode = "--release=fast"
target_format = "-Dtarget={}-{}"
prefix = "-p " + target_path

commands = []
folder_names = []

# === Prepare commands and release folders ===
for os_name in operating_sys:
    for target in targets[os_name]:
        opts = []
        target_formatted = target_format.format(target, os_name)
        opts.append(root)
        opts.append(release_mode)
        opts.append(target_formatted)
        opts.append(prefix)
        commands.append(" ".join(opts))

        release_path = os.path.join(
            target_path, f"{program_name}-{version}_{os_name}-{target}"
        )
        safe_mkdir(release_path)

        shutil.copy("README.md", os.path.join(release_path, "README.md"))
        shutil.copy(".github/CHANGELOG.md", os.path.join(release_path, "CHANGELOG.md"))
        shutil.copy("AUTHORS.md", os.path.join(release_path, "AUTHORS.md"))
        shutil.copy("LICENSE", os.path.join(release_path, "LICENSE"))

        folder_names.append(release_path)

# === Compile function ===
def compile(start, end):
    for command_num in range(start, end):
        start_compile = int(time.time() * 1000)
        out = run_command(commands[command_num])
        if out.stderr.strip():
            print("Process errored with:")
            print(out.stderr)
            break
        end_compile = int(time.time() * 1000)
        print(
            f"Compilation {command_num + 1} took {end_compile - start_compile} ms"
        )

        bin_path = os.path.join(target_path, "bin")
        exe_path = ""
        for root_dir, _, files in os.walk(bin_path):
            for file in files:
                if file.endswith(f"{program_name}") or file.endswith(f"{program_name}.exe"):
                    exe_path = os.path.join(root_dir, file)

        release_path = folder_names[command_num]
        release_file = os.path.join(release_path, os.path.basename(exe_path))
        shutil.copy(exe_path, release_file)
        safe_rmdir(bin_path)
    print("Compilation complete!\n")

# === Run compile ===
compile(0, len(commands))

# === Compress all builds ===
for idx, compiled in enumerate(os.listdir(target_path)):
    compiled_path = os.path.join(target_path, compiled)
    compiled_name = os.path.basename(compiled_path)
    start_compression = int(time.time() * 1000)
    run_command(
        f"tar -cvf {os.path.join(compressed_path, compiled_name)}.tar -C {compiled_path} ."
    )
    end_compression = int(time.time() * 1000)
    print(
        f"Compression {idx + 1} took {end_compression - start_compression} ms"
    )
print("Compression complete!\n")
