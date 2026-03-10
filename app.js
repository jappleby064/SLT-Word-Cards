// SLT Word Cards Web Application Logic
let allCards = [];

// DOM Elements
const searchBtn = document.getElementById('searchBtn');
const initialSoundInput = document.getElementById('initialSound');
const finalSoundInput = document.getElementById('finalSound');
const structureInput = document.getElementById('structure');
const resultsList = document.getElementById('resultsList');
const statusLabel = document.getElementById('statusLabel');
const selectAllCheckbox = document.getElementById('selectAllCheckbox');
const instanceCountInput = document.getElementById('instanceCount');
const printBtn = document.getElementById('printBtn');

// Action Elements
const infoBtn = document.getElementById('infoBtn');

// Init
document.addEventListener('DOMContentLoaded', () => {
    loadCards();
    setupEventListeners();
});

// Load and parse CSV
function loadCards() {
    statusLabel.textContent = "Loading cards...";
    // Assuming cards.csv is in the same directory (root for static hosting)
    Papa.parse('cards.csv', {
        download: true,
        header: true,
        skipEmptyLines: true,
        complete: function (results) {
            allCards = results.data.map(row => {
                return {
                    word: row['Word'].trim(),
                    initial: row['Word Initial'].trim().toLowerCase(),
                    final: row['Word Final'].trim().toLowerCase(),
                    structure: row['Structure'].trim().toLowerCase(),
                    image: `images/${row['Word'].trim()}.jpg`
                };
            });
            console.log("Loaded cards:", allCards);
            statusLabel.textContent = `Loaded ${allCards.length} cards. Ready.`;
        },
        error: function (err) {
            console.error("Error loading CSV:", err);
            statusLabel.textContent = "Error loading cards.csv";

            // Fallback for local files without a server allowing fetch
            statusLabel.innerHTML = "<span style='color:red;'>Make sure you are running via a local web server to fetch the CSV.</span>";
        }
    });
}

function setupEventListeners() {
    // Search Action
    searchBtn.addEventListener('click', onSearch);

    // Allow 'Enter' key to trigger search in inputs
    const inputs = [initialSoundInput, finalSoundInput, structureInput];
    inputs.forEach(input => {
        input.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') {
                onSearch();
            }
        });
    });

    // Select All Checkbox
    selectAllCheckbox.addEventListener('change', (e) => {
        const checkboxes = resultsList.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(cb => {
            cb.checked = e.target.checked;
        });
    });

    // Print Action
    printBtn.addEventListener('click', generatePrintSelection);

    // Request Card Email
    infoBtn.addEventListener('click', () => {
        const email = 'james@applebytechnical.com';
        const subject = encodeURIComponent('Card Request');
        const body = encodeURIComponent('Name:\n\nWord Initial Sound:\n\nWord Final Sound:\n\nStructure (eg.cvc):\n\n500x500 Image:');
        window.location.href = `mailto:${email}?subject=${subject}&body=${body}`;
    });
}

function onSearch() {
    const initial = initialSoundInput.value.trim().toLowerCase();
    const final = finalSoundInput.value.trim().toLowerCase();
    const structure = structureInput.value.trim().toLowerCase();

    // Replicating Python perform_search behavior
    const matches = allCards.filter(card => {
        if (initial && card.initial !== initial) return false;
        if (final && card.final !== final) return false;
        if (structure && card.structure !== structure) return false;
        return true;
    });

    renderResults(matches);
}

function renderResults(matches) {
    resultsList.innerHTML = '';
    selectAllCheckbox.checked = false;

    if (matches.length === 0) {
        statusLabel.textContent = "No matches found.";
        return;
    }

    statusLabel.textContent = `Found ${matches.length} matches.`;

    matches.forEach(card => {
        const label = document.createElement('label');
        label.className = 'custom-checkbox';

        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.value = card.word;
        checkbox.dataset.image = card.image;

        const checkmark = document.createElement('span');
        checkmark.className = 'checkmark';

        label.appendChild(checkbox);
        label.appendChild(checkmark);
        label.appendChild(document.createTextNode(` ${card.word}`));

        resultsList.appendChild(label);
    });
}

async function generatePrintSelection() {
    const selectedCheckboxes = Array.from(resultsList.querySelectorAll('input[type="checkbox"]:checked'));

    if (selectedCheckboxes.length === 0) {
        alert("Please select at least one word to generate a PDF.");
        return;
    }

    const selectedWords = selectedCheckboxes.map(cb => ({
        word: cb.value,
        image: cb.dataset.image
    }));

    let count = parseInt(instanceCountInput.value, 10);
    if (isNaN(count) || count < 1) count = 1;

    const printList = [];
    for (let i = 0; i < count; i++) {
        printList.push(...selectedWords);
    }

    printBtn.disabled = true;
    printBtn.textContent = 'Generating…';

    try {
        await generatePDF(printList);
    } finally {
        printBtn.disabled = false;
        printBtn.textContent = 'Download PDF';
    }
}

async function generatePDF(items) {
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

    // Mirror Python QPrinter logic exactly
    const pageW = 210, pageH = 297;
    const marginX = pageW * 0.05;          // 10.5mm
    const marginY = pageH * 0.05;          // 14.85mm
    const cols = 3, rows = 4;
    const itemsPerPage = cols * rows;      // 12
    const cellW = (pageW - 2 * marginX) / cols;   // 63mm
    const cellH = (pageH - 2 * marginY) / rows;   // 66.825mm
    const cardSize = Math.min(cellW, cellH) * 0.9; // 56.7mm

    // Load one image src -> base64 data URL, falling back to no_image.jpg
    async function toDataUrl(src) {
        try {
            const resp = await fetch(src);
            if (!resp.ok) throw new Error('missing');
            const blob = await resp.blob();
            return await new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(reader.result);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
        } catch {
            const blob = await fetch('images/no_image.jpg').then(r => r.blob());
            return await new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(reader.result);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
        }
    }

    // Pre-load all images in parallel
    const dataUrls = await Promise.all(items.map(item => toDataUrl(item.image)));

    doc.setLineWidth(0.3);
    doc.setDrawColor(0, 0, 0);

    for (let i = 0; i < items.length; i++) {
        const slot = i % itemsPerPage;
        if (slot === 0 && i > 0) doc.addPage();

        const col = slot % cols;
        const row = Math.floor(slot / cols);

        // Centre card within its cell
        const cardX = marginX + col * cellW + (cellW - cardSize) / 2;
        const cardY = marginY + row * cellH + (cellH - cardSize) / 2;

        // Image fills card area, border drawn on top
        doc.addImage(dataUrls[i], 'JPEG', cardX, cardY, cardSize, cardSize, '', 'FAST');
        doc.rect(cardX, cardY, cardSize, cardSize, 'S');
    }

    doc.save('word-cards.pdf');
}
