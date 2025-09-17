import os
import requests

# Directory where files will be saved
save_dir = "assets/nnue/oasis"
os.makedirs(save_dir, exist_ok=True)

# URLs and filenames
files = {
    ".nnue": ".nnue",
    ".nnue": ".nnue"
}

def download():
    raise NotImplementedError("Oasis is currently under development, use stockfish_nnue.py")
    for url, filename in files.items():
        print(f"Downloading {filename}...")
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        filepath = os.path.join(save_dir, filename)
        with open(filepath, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"Saved to {filepath}")

    print("All downloads completed.")

if __name__ == "__main__":
    download()