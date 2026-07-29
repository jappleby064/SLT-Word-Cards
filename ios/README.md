# SLT Word Cards — iOS app

A native iPhone/iPad companion to the web app. Same `cards.csv`, same search, same
print sheet — plus saved decks and an on-device presenter.

## Open it

The Xcode project is generated from `project.yml` (it is not checked in):

```bash
cd ios && xcodegen generate && open SLTWordCards.xcodeproj
```

Install `xcodegen` with `brew install xcodegen`.

## Build from the command line

Simulator:

```bash
xcodebuild -project ios/SLTWordCards.xcodeproj -scheme SLTWordCards -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO build
```

Device (team `3PJCNVU63X`, automatic signing):

```bash
xcodebuild -project ios/SLTWordCards.xcodeproj -scheme SLTWordCards -sdk iphoneos -destination 'generic/platform=iOS' -allowProvisioningUpdates build
```

## How content works

There is one source of truth for card data: the repo root. The Xcode target
references `../cards.csv` and `../images/` directly, so adding a card to the web
app adds it to the iOS app too.

At runtime content resolves newest-first:

1. **Downloaded** — `Application Support/Content/`, filled by `ContentSync`.
2. **Bundled** — shipped in the app, so a fresh install works with no network.

On open (and on foreground, at most every 15 minutes) the app requests
`cards.csv` from `raw.githubusercontent.com` with an `If-None-Match` ETag, so an
unchanged repo costs a single 304. When the CSV does change, images for any new
words are downloaded in the background. Every network step is best-effort — the
app is fully usable offline and never replaces working content with a bad
response.

## Saved decks

Two tiers, **Client → Deck**, one JSON file per deck:

```
<root>/Clients/<clientID>/client.json
<root>/Clients/<clientID>/Decks/<deckID>.json
```

`<root>` is the app's private iCloud Drive container
(`iCloud.com.applebytechnical.SLTWordCards`, Documents only) so decks follow the
user between their own devices. There is no sharing surface — no CloudKit sharing,
no public database, no share sheet for decks. With no iCloud account signed in,
the identical layout is used under Application Support and everything keeps
working locally; decks created that way are migrated up the first time iCloud
becomes available.

Note that iCloud is inert in the Simulator unless the build is signed with the
entitlement, so the Decks tab will say "Saved on this device" there. That is
expected, not a failure.

## Print layout

`PrintLayout.swift` is a direct port of `generatePDF` in `app.js`, which itself
mirrors the original PyQt `QPrinter` logic. Geometry is kept in millimetres so it
reads against the web app line for line:

| | |
|---|---|
| Page | A4, 210 × 297 mm |
| Margins | 10.5 mm × 14.85 mm (5%) |
| Grid | 3 × 4 = 12 cards per page |
| Card | `min(cellW, cellH) × 0.9` = 56.7 mm |
| Border | 0.3 mm black stroke |
| Duplicates | the whole selection repeats per pass (ABC ABC), not AAA BBB |
| Number cards | fitted bold text (`7` / `Seven`) where the picture would go |

Verified against the web app's constants: column origins 38.6929 / 217.2756 /
395.8583 pt and row origins 624.7205 / 435.2953 / 245.8701 / 56.4449 pt, matching
to four decimal places.
