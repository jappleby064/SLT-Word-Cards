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

| Carrier | Form | Opens in |
|---|---|---|
| **Link** (primary) | `https://speakeasy-slt.uk/deck/#deck=<base64url>` | the app where installed, the web app otherwise |
| File | `Name.sltdeck` (pretty JSON) | the app, or the web app's "Open a Deck File" |
| App link | `sltcards://deck?d=<base64url>` | fallback for the web page's "Open in the app" |

The link payload lives in the URL **fragment**, so it is never sent to a server.
The base64url transform and compact JSON keys (`v`, `n`, `c`, `p`) are identical
in `DeckPack.swift` and `app.js`, verified round-tripping in both directions —
including the web app opening a `.sltdeck` written by the Swift encoder.

Incoming packs are always confirmed before saving, are never allowed to overwrite
an existing deck (a second import becomes "Name 2"), and report how many cards
aren't in the local card set yet — those resolve on their own after a content sync.

### Universal links: what the host must do

Shared decks are addressed as `/deck/` rather than `/` so that claiming the path
does not hijack every link to the site. `deck/index.html` forwards to the web app,
keeping the fragment, for devices without the app.

Three things have to line up, and only the first is outside this repo:

1. `/.well-known/apple-app-site-association` must be served **as
   `application/json`**, over HTTPS, with no redirect. The file has no extension,
   so most static hosts guess `application/octet-stream` and verification fails
   silently. `_headers` at the repo root covers Netlify and Cloudflare Pages. For
   Vercel use a `headers` entry in `vercel.json`; for GitHub Pages you cannot set
   headers at all, so universal links will not verify there. A `.nojekyll` file is
   also present, because Jekyll otherwise drops the `.well-known` directory.
2. `com.apple.developer.associated-domains` — `applinks:speakeasy-slt.uk`. Present
   in the entitlements and verified in the signed build.
3. The Associated Domains capability on the App ID, which automatic signing
   registers on first build.

Apple fetches the association file through their CDN, so a change can take a while
to propagate. Append `?mode=developer` to the associated domain and enable
Developer Mode on the device to bypass the CDN while testing.

## Your own cards

Cards you make yourself are stored beside your decks, in the same private iCloud
container, so they follow you between your devices and go nowhere else:

```
<root>/CustomCards/<uuid>.json
<root>/CustomCards/Images/<uuid>.jpg
```

Word, both sounds and structure are required, so a custom card is findable on the
same criteria as every other card. The picture is optional; without one the card
shows a placeholder. Pictures are squared off to 500×500 and padded with white
rather than cropped or stretched, matching the shared image set so printed sheets
stay consistent.

They use a separate id namespace (`custom|<uuid>`), which does three jobs: it can
never collide with the catalogue, it keeps them out of the GitHub image backfill,
and it lets a pack recognise and exclude them — a recipient has no copy, so
sending their ids would only produce cards that can't resolve. `SendDeckSheet`
says how many were left behind.

## Requesting a card

Both platforms collect the same fields, with the picture optional and the rest
enforced. The app uses the system mail composer, attaching the picture as a
squared-off JPEG, and falls back to `mailto:` where no mail account is set up.

The web form never exposes the destination address — see the note in `app.js`.

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
