#!/usr/bin/env python
import re
import requests
import sys
import os
from pathlib import Path
import mimetypes

WORK_DIR = os.path.dirname(__file__)
CSV_FILE_PATH = Path(WORK_DIR).joinpath("ArtDB.csv")
OUT_PUTDIR = Path(Path(WORK_DIR).parent.parent).joinpath("icons/art/tmp")

import requests

headers = {
    'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'accept-language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'dnt': '1',
    'priority': 'u=0, i',
    'sec-ch-ua': '"Not;A=Brand";v="99", "Brave";v="139", "Chromium";v="139"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Linux"',
    'sec-fetch-dest': 'document',
    'sec-fetch-mode': 'navigate',
    'sec-fetch-site': 'none',
    'sec-fetch-user': '?1',
    'sec-gpc': '1',
    'upgrade-insecure-requests': '1',
    'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
}



def get_game_url(game_id):
    print("game_id", game_id)
    print("WORK_DIR", WORK_DIR)
    print("CSV_FILE_PATH", CSV_FILE_PATH)
    print("OUT_PUTDIR", OUT_PUTDIR)
    if not game_id:
        raise TypeError("Erro gameId invalido art_downloader.py game_id")
    with open(CSV_FILE_PATH, "r", encoding="utf-8") as art_csv:

        for game in art_csv.read().split("\n"):
            if game.startswith(game_id):
                return f"https://www.ign.com/games/{game.split("|")[1]}"
    return

def extract_cover_url(game_url):
    response = requests.get(game_url, headers=headers, timeout=30)
    domain_img_patterns = [
        r'<img[^>]+src=["\'](https:\/\/assets-prd\.ignimgs\.com[^"\']*)["\']',
        r'<img[^>]+src=["\'](https:\/\/media\.ign\.com[^"\']*)["\']',
        r'<img[^>]+src=["\'](https:\/\/ps2media\.ign\.com[^"\']*)["\']',
        r'<img[^>]+src=["\'](https:\/\/ps3media\.ign\.com[^"\']*)["\']',
        r'<img[^>]+src=["\'](https:\/\/media\.gamestats\.com[^"\']*)["\']',
        r'<img[^>]+src=["\'](https:\/\/assets1\.ignimgs\.com[^"\']*)["\']',
    ]
    for pattern in domain_img_patterns:
        urls = re.findall(pattern, response.text)
        if urls:
            for url in urls:
                if url:
                    if "?" in url:
                        return url.split("?")[0]
                    return url


def download_game_image(game_id):
    if not game_id:
        raise TypeError("Erro gameId invalido art_downloader.py game_id")
    game_url = get_game_url(game_id=game_id)
    if not game_url:
        print(f"Invalide Game URL: {game_url}")
    cover_url = extract_cover_url(game_url)
    if cover_url:
        OUT_PUTDIR.mkdir(parents=True, exist_ok=True)
        image_response = requests.get(cover_url, timeout=30)
        content_type = image_response.headers["content-type"]
        extension = mimetypes.guess_extension(content_type)

        with open(OUT_PUTDIR.joinpath(f"{game_id}{extension}"), "wb") as downloaded_image:
            downloaded_image.write(image_response.content)

    return

if __name__ == "__main__":
    download_game_image(sys.argv[1])