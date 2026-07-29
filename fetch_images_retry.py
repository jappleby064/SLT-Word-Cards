#!/usr/bin/env python3
"""Retry failed words with slower rate and smaller thumbnails."""

import requests
import os
import time
from PIL import Image
from io import BytesIO

IMAGES_DIR = "/Users/jamesappleby/Desktop/SLT Word Cards/images"
HEADERS = {'User-Agent': 'SLT-Word-Cards-Educational/1.0 (educational SLT tool; not commercial)'}

FAILED = [
    "bin", "bug", "cot", "cut", "dad", "fan", "fun", "gap", "gas", "gum",
    "gut", "ham", "hat", "hen", "hog", "hub", "hut", "jam", "jet", "job",
    "jug", "lad", "lap", "leg", "lid", "lip", "log", "mob", "mop", "mud",
    "mum", "nap", "net", "nod", "nut", "pad", "pan", "pat", "peg", "pin",
    "pit", "pot", "rag", "ram", "rat", "rug", "sap", "set", "tab", "tan",
    "tap", "tip", "top", "tub", "van", "vat", "vet", "web", "wok", "zip",
    "band", "hand", "lamp", "vest", "frog",
]

SEARCH_HINTS = {
    "bin":  "wheelie bin rubbish",
    "bug":  "ladybug insect",
    "cot":  "baby cot crib bed",
    "cut":  "scissors cutting",
    "dad":  "father dad man",
    "fan":  "hand fan",
    "fun":  "happy smile play",
    "gap":  "gap opening hole",
    "gas":  "gas flame stove",
    "gum":  "bubble gum chewing",
    "gut":  "fish gut",
    "ham":  "ham meat food",
    "hat":  "top hat cartoon",
    "hen":  "chicken hen bird",
    "hog":  "pig hog farm animal",
    "hub":  "wheel hub centre",
    "hut":  "wooden hut cabin",
    "jam":  "jam jar strawberry",
    "jet":  "jet plane aircraft",
    "job":  "worker job",
    "jug":  "water jug pitcher",
    "lad":  "boy child",
    "lap":  "dog lap sitting",
    "leg":  "human leg",
    "lid":  "pot lid cover",
    "lip":  "mouth lips",
    "log":  "wooden log tree",
    "mob":  "crowd people",
    "mop":  "floor mop cleaning",
    "mud":  "mud puddle",
    "mum":  "mother mum woman",
    "nap":  "sleeping nap",
    "net":  "fishing net",
    "nod":  "nod head yes",
    "nut":  "walnut nut food",
    "pad":  "writing notepad",
    "pan":  "frying pan cooking",
    "pat":  "hand pat stroke",
    "peg":  "clothes peg laundry",
    "pin":  "safety pin sewing",
    "pit":  "cherry pit stone fruit",
    "pot":  "flower pot plant",
    "rag":  "cloth rag cleaning",
    "ram":  "ram male sheep",
    "rat":  "rat rodent",
    "rug":  "floor rug carpet",
    "sap":  "maple syrup tree sap",
    "set":  "drum kit set",
    "tab":  "can tab pull ring",
    "tan":  "leather tan brown",
    "tap":  "water tap faucet kitchen",
    "tip":  "arrow tip point",
    "top":  "spinning top toy",
    "tub":  "bathtub bath",
    "van":  "delivery van vehicle",
    "vat":  "vat barrel tub",
    "vet":  "veterinarian dog vet",
    "web":  "spider web",
    "wok":  "wok cooking pan Asian",
    "zip":  "zipper zip fastener",
    "band": "rubber band",
    "hand": "human hand cartoon",
    "lamp": "table lamp light",
    "vest": "waistcoat vest clothing",
    "frog": "frog green cartoon",
}


def search_commons(word):
    api = "https://commons.wikimedia.org/w/api.php"
    hint = SEARCH_HINTS.get(word, word)
    queries = [f"{hint} clipart", f"{hint} cartoon", hint, word]
    for query in queries:
        params = {
            'action': 'query', 'list': 'search',
            'srsearch': query, 'srnamespace': '6',
            'srlimit': 25, 'format': 'json'
        }
        try:
            r = requests.get(api, params=params, headers=HEADERS, timeout=15)
            results = r.json().get('query', {}).get('search', [])
            svgs = [x['title'] for x in results if x['title'].lower().endswith('.svg')]
            pngs = [x['title'] for x in results if x['title'].lower().endswith('.png')]
            jpgs = [x['title'] for x in results if x['title'].lower().endswith(('.jpg', '.jpeg'))]
            ordered = svgs + pngs + jpgs
            if ordered:
                return ordered[0]
        except Exception as e:
            print(f"    search error: {e}")
        time.sleep(1.0)
    return None


def get_commons_url(title, width=320):
    api = "https://commons.wikimedia.org/w/api.php"
    params = {
        'action': 'query', 'titles': title, 'prop': 'imageinfo',
        'iiprop': 'url|thumburl', 'iiurlwidth': width, 'format': 'json'
    }
    try:
        r = requests.get(api, params=params, headers=HEADERS, timeout=15)
        pages = r.json().get('query', {}).get('pages', {})
        for page in pages.values():
            infos = page.get('imageinfo', [])
            if infos:
                return infos[0].get('thumburl') or infos[0].get('url')
    except Exception as e:
        print(f"    url error: {e}")
    return None


def get_wikipedia_url(word):
    hint = SEARCH_HINTS.get(word, word).split()[0]
    api = "https://en.wikipedia.org/w/api.php"
    params = {
        'action': 'query', 'titles': hint, 'prop': 'pageimages',
        'pithumbsize': 400, 'format': 'json'
    }
    try:
        r = requests.get(api, params=params, headers=HEADERS, timeout=15)
        pages = r.json().get('query', {}).get('pages', {})
        for page in pages.values():
            thumb = page.get('thumbnail')
            if thumb:
                return thumb.get('source')
    except Exception as e:
        print(f"    wikipedia meta error: {e}")
    return None


def download_with_retry(url, retries=3):
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=HEADERS, timeout=30)
            if r.status_code == 429:
                wait = 10 * (attempt + 1)
                print(f"    rate limited, waiting {wait}s...")
                time.sleep(wait)
                continue
            r.raise_for_status()
            return r.content
        except requests.HTTPError as e:
            if '429' in str(e) or '403' in str(e):
                wait = 10 * (attempt + 1)
                print(f"    HTTP {e.response.status_code}, waiting {wait}s...")
                time.sleep(wait)
            else:
                print(f"    HTTP error: {e}")
                return None
        except Exception as e:
            print(f"    error: {e}")
            return None
    return None


def save_image(data, word):
    img = Image.open(BytesIO(data))
    if img.mode in ('RGBA', 'LA', 'P'):
        bg = Image.new('RGB', img.size, (255, 255, 255))
        if img.mode == 'P':
            img = img.convert('RGBA')
        if img.mode in ('RGBA', 'LA'):
            bg.paste(img, mask=img.split()[-1])
        else:
            bg.paste(img)
        img = bg
    else:
        img = img.convert('RGB')
    w, h = img.size
    m = min(w, h)
    img = img.crop(((w - m) // 2, (h - m) // 2, (w + m) // 2, (h + m) // 2))
    img = img.resize((500, 500), Image.LANCZOS)
    img.save(os.path.join(IMAGES_DIR, f"{word}.jpg"), 'JPEG', quality=90)


def process_word(word):
    out = os.path.join(IMAGES_DIR, f"{word}.jpg")
    if os.path.exists(out):
        print(f"  [skip] {word}.jpg already exists")
        return "skip"

    # Try Commons
    title = search_commons(word)
    if title:
        url = get_commons_url(title, width=320)
        if url:
            data = download_with_retry(url)
            if data:
                try:
                    save_image(data, word)
                    print(f"  [OK-commons] {word}.jpg ← {title[:55]}")
                    return "ok"
                except Exception as e:
                    print(f"    save error: {e}")

    # Fall back to Wikipedia
    url = get_wikipedia_url(word)
    if url:
        data = download_with_retry(url)
        if data:
            try:
                save_image(data, word)
                print(f"  [OK-wiki]    {word}.jpg ← Wikipedia")
                return "ok"
            except Exception as e:
                print(f"    save error: {e}")

    print(f"  [FAIL]       {word}")
    return "fail"


if __name__ == "__main__":
    ok, fail, skip = [], [], []
    print(f"Retrying {len(FAILED)} words (with longer delays)...\n")
    for i, word in enumerate(FAILED, 1):
        print(f"[{i:2}/{len(FAILED)}] {word}")
        result = process_word(word)
        if result == "ok":
            ok.append(word)
        elif result == "fail":
            fail.append(word)
        else:
            skip.append(word)
        time.sleep(2.0)  # 2s between each word

    print(f"\n{'='*50}")
    print(f"Done: {len(ok)} downloaded, {len(skip)} skipped, {len(fail)} failed")
    if fail:
        print(f"Still failed: {', '.join(fail)}")

    total = len([f for f in os.listdir(IMAGES_DIR) if f.endswith('.jpg') and f != 'no_image.jpg'])
    print(f"Total images in folder (excl. no_image.jpg): {total}")
