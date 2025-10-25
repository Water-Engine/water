import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Lock
import signal
import sys

BASE_URL = "https://www.pgnmentor.com/files.html"
DEST_ROOT = "full_pgn_db"
MAX_WORKERS = 16

extract_lock = Lock()
stop_flag = False

def signal_handler(sig, frame):
    global stop_flag
    print("\nCtrl+C detected. Stopping downloads...")
    stop_flag = True

signal.signal(signal.SIGINT, signal_handler)

def process_link(link, subfolder=None):
    global stop_flag
    if stop_flag:
        return

    try:
        file_url = urljoin(BASE_URL, link)
        if subfolder:
            local_path = os.path.join(DEST_ROOT, "general", subfolder, os.path.basename(link))
        else:
            local_path = os.path.join(DEST_ROOT, link.replace("/", os.sep))

        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        print(f"Downloading {local_path}...")
        r = requests.get(file_url, timeout=30)
        r.raise_for_status()
        with open(local_path, 'wb') as f:
            f.write(r.content)

        if stop_flag:
            return

        if local_path.lower().endswith('.zip'):
            with extract_lock:
                print(f"Extracting {local_path}...")
                with zipfile.ZipFile(local_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.dirname(local_path))
                os.remove(local_path)

    except Exception as e:
        pass

def download_and_extract_threaded():
    response = requests.get(BASE_URL)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")

    tasks = []

    for anchor in soup.find_all('a', id=True):
        flavor_id = anchor['id']
        heading = anchor.find_next('h2')
        flavor_name = heading.get_text(strip=True) if heading else flavor_id

        # Find the next <table> after the heading
        table = heading.find_next('table') if heading else None
        if table:
            for a_tag in table.find_all('a', href=True):
                href = a_tag['href']
                if href.lower().endswith(('.zip', '.pgn')):
                    tasks.append((href, flavor_name))

    general_links = [
        a['href']
        for a in soup.find_all('a', href=True)
        if a['href'].lower().endswith(('.zip', '.pgn')) and not any(a['href'] == t[0] for t in tasks)
    ]
    tasks += [(link, None) for link in general_links]

    print(f"Found {len(tasks)} PGN files/zips.")

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(process_link, link, subfolder) for link, subfolder in tasks]
        try:
            for future in as_completed(futures):
                if stop_flag:
                    break
        except KeyboardInterrupt:
            print("Caught KeyboardInterrupt, shutting down executor...")
            executor.shutdown(wait=False)
            sys.exit(1)

    print("All PGN files downloaded and extracted!")

if __name__ == "__main__":
    download_and_extract_threaded()
