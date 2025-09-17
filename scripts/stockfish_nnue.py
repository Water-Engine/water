import os
import requests

# Directory where files will be saved
save_dir = "assets/nnue/stockfish"
os.makedirs(save_dir, exist_ok=True)

# URLs and filenames
files = {
    "https://tests.stockfishchess.org/api/nn/nn-1c0000000000.nnue": "nn-1c0000000000.nnue",
    "https://tests.stockfishchess.org/api/nn/nn-37f18f62d772.nnue": "nn-37f18f62d772.nnue"
}

def download():
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