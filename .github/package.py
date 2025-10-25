import tarfile
import sys
from pathlib import Path


def compress_directories(base_dir: str, version: str):
    base_path = Path(base_dir)

    if not base_path.exists() or not base_path.is_dir():
        print(f"Error: '{base_dir}' is not a valid directory.")
        return

    for item in base_path.iterdir():
        if item.is_dir():
            if item.name == "bin":
                continue
            archive_name = f"Water-{version}-{item.name}.tar.gz"
            archive_path = base_path / archive_name

            print(f"Compressing {item.name} -> {archive_name}")

            with tarfile.open(archive_path, "w:gz") as tar:
                tar.add(item, arcname=item.name)

    print("Compression complete.")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python compress_dirs.py <base_directory> <version>")
        sys.exit(1)

    base_directory = sys.argv[1]
    version = sys.argv[2]
    compress_directories(base_directory, version)
