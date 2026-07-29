# SLT Word Cards — iPhone, iPad and Mac app

A native companion to the web app. Same `cards.csv`, same search, same print
sheet — plus saved decks, an on-device presenter, and shareable deck packs.

One target covers all three platforms via Mac Catalyst, deliberately keeping the
same bundle id so every platform shares one iCloud container.

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

Mac:

```bash
xcodebuild -project ios/SLTWordCards.xcodeproj -scheme SLTWordCards -destination 'platform=macOS,variant=Mac Catalyst' -allowProvisioningUpdates build
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

## Modes

Chosen on first launch, changeable in Settings, and never destructive either way:

- **Therapist** — the full library: clients, decks grouped under them, and packs
  to send out.
- **Client** — one flat list of their own decks plus the ones a therapist sent.
  No client creation and no grouping.

Client mode is backed by a reserved client record (a fixed UUID named "My Decks")
so both modes share exactly one storage and sync path; the therapist-facing lists
simply filter it out. Switching to Client mode hides client folders rather than
touching them.

## Deck packs

A pack is a deck's **name and card ids** — nothing else. Every install resolves
pictures from the same `cards.csv` and `images/`, so naming the cards is enough.
That keeps a twelve-card pack around a kilobyte, and means it carries no images
and, deliberately, no client identity.

One payload, three carriers:

| Carrier | Form | Used by |
|---|---|---|
| File | `Name.sltdeck` (pretty JSON) | AirDrop, Mail, Messages, Files |
| Web link | `https://speakeasy-slt.uk/#deck=<base64url>` | the web app |
| App link | `sltcards://deck?d=<base64url>` | the web page's "Open in the app" |

The link payload lives in the URL **fragment**, so it is never sent to a server.
The base64url transform and compact JSON keys (`v`, `n`, `c`, `p`) are identical
in `DeckPack.swift` and `app.js`, verified round-tripping in both directions.

Incoming packs are always confirmed before saving, are never allowed to overwrite
an existing deck (a second import becomes "Name 2"), and report how many cards
aren't in the local card set yet — those resolve on their own after a content sync.

Universal links would let a web link open the app directly without the custom
scheme. That needs an `apple-app-site-association` file served from the domain
plus the associated-domains capability, so it is left as a follow-up rather than
half-configured here.

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
