# SLT Word Cards Website

A web-based application designed for Speech and Language Therapy (SLT). This static website allows users to search, filter, and print square word cards based on specific phonetic and structural criteria.

## Features
- **Search & Filter:** Find cards by *Word Initial Sound*, *Word Final Sound*, and *Word Structure* (e.g., CVC).
- **Print Formatting:** Automatically formats selected cards into a 3x4 grid on A4 paper for easy printing and cutting.
- **Git-Integrated Data:** New cards are added simply by committing images to the `images/` directory and adding rows to the `cards.csv` file.

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