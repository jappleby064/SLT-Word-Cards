#!/usr/bin/env python3
"""Download clipart images for SLT Word Cards from Wikimedia Commons / Wikipedia."""

import requests
import os
import time
from PIL import Image
from io import BytesIO

IMAGES_DIR = "/Users/jamesappleby/Desktop/SLT Word Cards/images"
HEADERS = {'User-Agent': 'SLT-Word-Cards-Educational/1.0'}

WORDS = [
    "bag", "bed", "bin", "bit", "bog", "bug", "bun", "bus",
    "cod", "cot", "cub", "cut", "dad", "dam", "den", "dip", "dot",
    "fan", "fig", "fin", "fog", "fun",
    "gap", "gas", "gum", "gun", "gut",
    "ham", "hat", "hen", "hip", "hog", "hub", "hut",
    "jam", "jet", "jig", "job", "jug",
    "lad", "lap", "leg", "lid", "lip", "log",
    "mob", "mop", "mud", "mug", "mum",
    "nap", "net", "nod", "nut",
    "pad", "pan", "pat", "peg", "pen", "pet", "pig", "pin", "pit", "pod", "pot", "pub", "pup",
    "rag", "ram", "rat", "rod", "rug", "rum",
    "sap", "set", "sun",
    "tab", "tan", "tap", "tin", "tip", "top", "tub", "tug",
    "van", "vat", "vet",
    "web", "wig", "wok", "zip",
    "band", "hand", "lamp", "sand", "vest",
    "frog", "flag", "crab", "slug",
]

# More descriptive search terms for ambiguous short words
SEARCH_HINTS = {
    "bit":  "drill bit tool",
    "bog":  "bog swamp marsh",
    "bun":  "bread bun food",
    "bus":  "bus vehicle transport",
    "cod":  "cod fish",
    "cot":  "baby cot crib",
    "cub":  "bear cub animal",
    "cut":  "scissors cut",
    "dam":  "beaver dam water",
    "den":  "fox den animal",
    "dip":  "sauce dip food",
    "dot":  "polka dot circle",
    "fan":  "electric fan",
    "fin":  "fish fin",
    "fog":  "fog mist weather",
    "fun":  "fun play cartoon",
    "gap":  "gap hole opening",
    "gas":  "gas fuel",
    "gum":  "chewing gum",
    "gut":  "gut fish",
    "hip":  "hip bone body",
    "hog":  "hog pig animal",
    "hub":  "wheel hub",
    "hut":  "hut cabin house",
    "jig":  "jig dance",
    "job":  "job work occupation",
    "lad":  "boy lad child",
    "lap":  "lap sitting",
    "lid":  "jar lid cover",
    "lip":  "lips mouth",
    "mob":  "crowd mob people",
    "mum":  "mum mother",
    "nap":  "sleep nap",
    "nod":  "nod head",
    "pad":  "notepad writing pad",
    "pat":  "pat hand",
    "peg":  "clothes peg",
    "pit":  "pit hole ground",
    "pod":  "pea pod vegetable",
    "pub":  "pub bar",
    "pup":  "puppy dog",
    "rag":  "rag cloth",
    "ram":  "ram sheep animal",
    "rod":  "fishing rod",
    "rum":  "rum drink",
    "sap":  "tree sap",
    "set":  "set of objects",
    "tab":  "tab label",
    "tan":  "tan colour brown",
    "tap":  "water tap faucet",
    "tin":  "tin can food",
    "tip":  "arrow tip",
    "tub":  "bathtub",
    "tug":  "tugboat ship",
    "vat":  "vat barrel container",
    "vet":  "veterinarian animal doctor",
    "wok":  "wok cooking pan",
    "zip":  "zip zipper fastener",
    "band": "wristband band",
    "vest": "vest clothing",
    "flag": "flag country",
    "slug": "slug animal",
}


def search_commons(word):
    api = "https://commons.wikimedia.org/w/api.php"
    hint = SEARCH_HINTS.get(word, word)
    queries = [f"{hint} clipart", f"{hint} cartoon", f"{hint} illustration", hint, word]
    for query in queries:
        params = {
            'action': 'query', 'list': 'search',
            'srsearch': query, 'srnamespace': '6',
            'srlimit': 20, 'format': 'json'
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
        time.sleep(0.2)
    return None


def get_commons_url(title):
    api = "https://commons.wikimedia.org/w/api.php"
    params = {
        'action': 'query', 'titles': title, 'prop': 'imageinfo',
        'iiprop': 'url|thumburl', 'iiurlwidth': 600, 'format': 'json'
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
    hint = SEARCH_HINTS.get(word, word).split()[0]  # first word of hint
    api = "https://en.wikipedia.org/w/api.php"
    params = {
        'action': 'query', 'titles': hint, 'prop': 'pageimages',
        'pithumbsize': 600, 'format': 'json'
    }
    try:
        r = requests.get(api, params=params, headers=HEADERS, timeout=15)
        pages = r.json().get('query', {}).get('pages', {})
        for page in pages.values():
            thumb = page.get('thumbnail')
            if thumb:
                return thumb.get('source')
    except Exception as e:
        print(f"    wikipedia error: {e}")
    return None


def save_image(data, word):
    img = Image.open(BytesIO(data))
    # Handle transparency
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
    # Center-crop to square
    w, h = img.size
    m = min(w, h)
    img = img.crop(((w - m) // 2, (h - m) // 2, (w + m) // 2, (h + m) // 2))
    # Resize to 500x500
    img = img.resize((500, 500), Image.LANCZOS)
    img.save(os.path.join(IMAGES_DIR, f"{word}.jpg"), 'JPEG', quality=90)


def process_word(word):
    out = os.path.join(IMAGES_DIR, f"{word}.jpg")
    if os.path.exists(out):
        print(f"  [skip] {word}.jpg already exists")
        return "skip"

    # Try Wikimedia Commons first
    title = search_commons(word)
    if title:
        url = get_commons_url(title)
        if url:
            try:
                r = requests.get(url, headers=HEADERS, timeout=30)
                r.raise_for_status()
                save_image(r.content, word)
                print(f"  [OK-commons] {word}.jpg  ← {title[:60]}")
                return "ok"
            except Exception as e:
                print(f"    download/save error: {e}")

    # Fall back to Wikipedia article thumbnail
    url = get_wikipedia_url(word)
    if url:
        try:
            r = requests.get(url, headers=HEADERS, timeout=30)
            r.raise_for_status()
            save_image(r.content, word)
            print(f"  [OK-wiki]    {word}.jpg  ← Wikipedia thumbnail")
            return "ok"
        except Exception as e:
            print(f"    wikipedia download error: {e}")

    print(f"  [FAIL]       {word} — no image found")
    return "fail"


if __name__ == "__main__":
    ok, fail, skip = [], [], []
    print(f"Processing {len(WORDS)} words...\n")
    for i, word in enumerate(WORDS, 1):
        print(f"[{i:3}/{len(WORDS)}] {word}")
        result = process_word(word)
        if result == "ok":
            ok.append(word)
        elif result == "fail":
            fail.append(word)
        else:
            skip.append(word)
        time.sleep(0.35)

    print(f"\n{'='*50}")
    print(f"Done: {len(ok)} downloaded, {len(skip)} skipped, {len(fail)} failed")
    if fail:
        print(f"Failed: {', '.join(fail)}")
    print(f"Images in: {IMAGES_DIR}")
