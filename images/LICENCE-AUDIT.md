# Card image licence audit

**Status: closed. Every shipped picture has a licence on record.**

All 82 pictures in `images/` are listed in [CREDITS.md](CREDITS.md) with source,
author and licence — from freesvg.org (CC0), OpenMoji (CC BY-SA 4.0), Twemoji
(CC BY 4.0), Pixabay, and licence-filtered Wikimedia Commons.

Every watermarked file is gone. `net` and `rug` were cut from the card set
entirely rather than ship on a picture whose origin could not be established;
21 newly added words that never found a suitable picture were dropped for the
same reason.

The originals are preserved in `backup/original-images/` — git-ignored, so they
are never published — and in git history at `9a54146`.

What follows is the original audit, kept as the record of why the whole set had
to be replaced.

---

This file records an attempt, made on 4 August 2026, to recover the provenance
and licence of every picture in `images/`. It failed for every file, and turned
up watermarked commercial stock in the process. It is written down here rather
than fixed quietly because the fix is a sourcing decision, not a code change.

Compare `audio/CREDITS.md`, which does this properly: every phoneme recording
has a named source, author and licence. The pictures have none of that.

## Why there is nothing to recover

`fetch_images.py` and `fetch_images_retry.py` search Wikimedia Commons, take the
**first** search hit, download it, and write it out as `<word>.jpg`. They do not
filter by licence, and they record nothing at all — not the source file name, not
the author, not the licence. Once the file is written the trail is gone.

The scripts also fall back to Wikipedia article thumbnails, and the words on disk
do not match the scripts' own word list (`cake`, `comb`, `dart`, `dome`, `door`,
`kart`, `key`, `kick`, `king`, `kiss`, `ring`, `sock`, `sore`, `back`, `cog` are
all present in `images/` but absent from `fetch_images.py`). So some pictures
arrived by a route that is not in the repository at all.

## What the recovery attempt did

For each file: re-ran the original Commons search logic, pulled the top
candidates, re-applied the original image processing (centre-crop to square,
resize to 500×500) to each, and compared pixel fingerprints against the file on
disk. A match would have identified the source file, and with it the author and
licence via the Commons `extmetadata` API.

**Nothing matched — 65 files checked, 65 unidentified.** Not one picture in
`images/` corresponds to anything Wikimedia Commons returns for its own word; the
closest candidates are visibly different pictures. Taken with the watermarks
below, the Commons hypothesis is dead: these pictures are not Commons material,
which is why there is no licence to recover.

## Confirmed watermarked commercial stock

Visible agency watermarks, legible at full resolution. These are comp/preview
images from paid stock libraries — using them is copyright infringement, not a
missing-attribution problem:

| File | Watermark |
|---|---|
| `nut.jpg` | **Adobe Stock**, tiled across the image, plus "Adobe Stock \| #288981648" down the left edge |
| `flag.jpg` | **Dreamstime** |
| `vet.jpg` | **classroomclipart.com**, with © notice |
| `duck.jpg` | **classroomclipart.com** |
| `kick.jpg` | **classroomclipart.com** |
| `cat.jpg` | **Colourbox** |
| `can.jpg` | Small agency mark, bottom right, too small to read |

## Scraped-preview artefacts

No text watermark, but these carry physical evidence of having been saved from a
preview rather than obtained as a licensed asset:

| File | Evidence |
|---|---|
| `bin.jpg` | The grey/white transparency checkerboard is **baked into the JPEG** — this is a screenshot of a PNG preview, not an exported asset |
| `frog.jpg` | Grey preview-panel background baked in |
| `cap.jpg` | Preview-panel background baked in |

## Everything else

The remaining ~55 files carry no visible mark, but they are flat commercial
vector illustration in the current stock-library house style (`band`, `sore`,
`kiss`, `bed`, `bat`, `cake`, `crab`, `hut`, `jam` and so on). That style is not
what Wikimedia Commons is full of, and none of them matched Commons. Treat their
provenance as **unknown**, which for shipping purposes is the same as unusable:
there is no licence to point at.

`no_image.jpg` is the built-in placeholder and is not part of this problem.

## Why this matters

- **Copyright.** Redistributing watermarked stock comps inside an app and on a
  public website infringes, regardless of intent. The watermark is the rights
  holder's own evidence.
- **App Review, Guideline 5.2.1.** Apple rejects apps using third-party material
  without the rights to it. A visible "Adobe Stock" watermark on a card is about
  as clear-cut as this gets, and reviewers page through screens.
- **Attribution.** Even for the files that turn out to be freely licensed, CC BY
  and CC BY-SA both require credit that the app and site do not currently give.

## What would fix it

Re-source the whole set from somewhere with per-file licence records, and keep
those records this time. Options, best first:

1. **OpenMoji** (CC BY-SA 4.0) or **Twemoji** (CC BY 4.0) — complete, consistent,
   one known licence for the whole set, one attribution line covers everything.
2. **Openclipart** / **SVG Repo** public-domain and CC0 collections — no
   attribution obligation at all, which removes the problem rather than managing
   it.
3. **Wikimedia Commons done properly** — filter the API response by licence,
   reject anything non-free, and write `title`, `artist`, `licence` and
   `licence_url` to a manifest as each file is saved.

Whichever is chosen, the fetch script should refuse to save a file it cannot
record a licence for, and `images/CREDITS.md` should be generated from that
manifest the way `audio/CREDITS.md` already is.

Until then, no `images/CREDITS.md` has been written. Publishing invented
attribution would be worse than publishing none.
