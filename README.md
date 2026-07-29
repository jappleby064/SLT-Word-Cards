# SLT Word Cards Website

A web-based application designed for Speech and Language Therapy (SLT). This static website allows users to search, filter, and print square word cards based on specific phonetic and structural criteria.

## Features
- **Search & Filter:** Find cards by *Word Initial Sound*, *Word Final Sound*, and *Word Structure* (e.g., CVC).
- **Print Formatting:** Automatically formats selected cards into a 3x4 grid on A4 paper for easy printing and cutting.
- **Present Mode:** Work through a selection one card at a time on screen — click or tap to reveal the word, with arrow keys, shuffle, and a progress indicator.
- **Shareable Decks:** Send a deck as a link. Only the list of cards travels, and it is held in the URL fragment so it never reaches a server.
- **Git-Integrated Data:** New cards are added simply by committing images to the `images/` directory and adding rows to the `cards.csv` file.

## Native app
`ios/` holds a SwiftUI app for iPhone, iPad and Mac that uses this repository's
`cards.csv` and `images/` as its card source, so a card added here appears there
too. It adds decks saved under client names, iCloud sync, and deck packs that
interchange with the web app's share links. See [ios/README.md](ios/README.md).

## Tech Stack
- HTML5
- CSS3 (Vanilla, Glassmorphism design)
- Vanilla JavaScript
- PapaParse (for fetching and parsing the CSV via CDN)

## Setup & Hosting
This project contains no build steps. It is a completely static website.
To host it, connect this repository to a service like **Netlify**, **Vercel**, or **GitHub Pages**. The root directory acts as the publish directory.

## Contributing / Adding Cards
If you wish to request a card addition, use the **Request a Card** button in the web interface to format your request via email. Include the word structure and a square 500x500 JPEG image.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Full Disclosure
This project is based on an original python code, revised by Gemini for the web.