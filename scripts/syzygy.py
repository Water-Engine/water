import os
import requests
from bs4 import BeautifulSoup

BASE_URLS = {
    "wdl": "https://tablebase.lichess.ovh/tables/standard/3-4-5-wdl/",
    "dtz": "https://tablebase.lichess.ovh/tables/standard/3-4-5-dtz/"
}

SAVE_DIRS = {
    "wdl": "tb/wdl",
    "dtz": "tb/dtz"
}

for dir_path in SAVE_DIRS.values():
    os.makedirs(dir_path, exist_ok=True)

PIECES = set("KQRBNP")
IMPORTANT_5MAN = [
    "KNPvKP", "KBPvKP", "KRPvKP", "KQPvKP", "KRPPvK", "KBPPvK",
    "KNPPvK", "KPPPvK",
]

def download_file(url, save_path):
    if os.path.exists(save_path):
        print(f"Skipping {save_path}, already exists")
        return
    print(f"Downloading {url} -> {save_path}")
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(save_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)

def get_file_list(url, kind):
    resp = requests.get(url)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    ext = ".rtbw" if kind == "wdl" else ".rtbz"
    links = [a['href'] for a in soup.find_all('a') if a['href'].endswith(ext)]
    return links

if __name__ == "__main__":
    for kind, base_url in BASE_URLS.items():
        save_dir = SAVE_DIRS[kind]
        file_list = get_file_list(base_url, kind)
        for file_name in file_list:
            # Count pieces in the filename (before .rtbw)
            name = file_name.split(".")[0]
            pieces_in_file = sum(1 for c in name if c in PIECES)
            # Only download 3- and 4-piece + selected 5-piece
            if pieces_in_file in [3, 4] or any(name.startswith(x) for x in IMPORTANT_5MAN):
                save_path = os.path.join(save_dir, file_name)
                download_file(base_url + file_name, save_path)
