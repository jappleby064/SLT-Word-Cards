// SLT Word Cards Web Application Logic
let allCards = [];

function capitalize(str) {
    return str ? str.charAt(0).toUpperCase() + str.slice(1) : str;
}

// DOM Elements
const searchBtn = document.getElementById('searchBtn');
const wordSearchInput = document.getElementById('wordSearch');
const firstLetterInput = document.getElementById('firstLetter');
const typeFilterSelect = document.getElementById('typeFilter');
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

// English (RP) phoneme inventory for the IPA keyboard, grouped for the popup.
const IPA_SOUNDS = {
    Consonants: ['p', 'b', 't', 'd', 'k', 'ɡ', 'm', 'n', 'ŋ', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'h', 'tʃ', 'dʒ', 'l', 'r', 'j', 'w'],
    Vowels: ['iː', 'ɪ', 'e', 'æ', 'ɑː', 'ɒ', 'ɔː', 'ʊ', 'uː', 'ʌ', 'ɜː', 'ə'],
    Diphthongs: ['eɪ', 'aɪ', 'ɔɪ', 'əʊ', 'aʊ', 'ɪə', 'eə', 'ʊə']
};

// Init
document.addEventListener('DOMContentLoaded', () => {
    loadCards();
    setupIpaField(initialSoundInput, document.getElementById('ipaToggle'), document.getElementById('ipaKeyboard'));
    setupIpaField(finalSoundInput, document.getElementById('ipaToggleFinal'), document.getElementById('ipaKeyboardFinal'));
    setupEventListeners();
});

// Fill `container` with the grouped phoneme keys; clicking one sets `targetInput`.
function buildIpaKeyboard(container, targetInput, close) {
    Object.entries(IPA_SOUNDS).forEach(([section, symbols]) => {
        const wrap = document.createElement('div');
        wrap.className = 'ipa-section';

        const title = document.createElement('span');
        title.className = 'ipa-section-title';
        title.textContent = section;
        wrap.appendChild(title);

        const keys = document.createElement('div');
        keys.className = 'ipa-keys';
        symbols.forEach(sym => {
            const key = document.createElement('button');
            key.type = 'button';
            key.className = 'ipa-key';
            key.textContent = sym;
            key.addEventListener('click', () => {
                targetInput.value = sym;
                close();
                targetInput.focus();
            });
            keys.appendChild(key);
        });
        wrap.appendChild(keys);
        container.appendChild(wrap);
    });
}

// Wire one IPA keyboard: an input, its in-field toggle button, and its popup.
function setupIpaField(input, toggle, popup) {
    const open = () => { popup.hidden = false; toggle.setAttribute('aria-expanded', 'true'); };
    const close = () => { popup.hidden = true; toggle.setAttribute('aria-expanded', 'false'); };

    buildIpaKeyboard(popup, input, close);

    toggle.addEventListener('click', (e) => {
        e.stopPropagation();
        popup.hidden ? open() : close();
    });
    document.addEventListener('click', (e) => {
        if (!popup.hidden && !popup.contains(e.target) && e.target !== toggle) close();
    });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') close();
    });
}

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
                const word = (row['Word'] || '').trim();
                const type = ((row['Type'] || 'word').trim().toLowerCase()) || 'word';
                const numeral = (row['Numeral'] || '').trim();
                const variant = (row['Variant'] || '').trim().toLowerCase();
                const isNumber = type === 'number';

                // Numbers come in two variants — a symbol ("1") and a spelled word ("One").
                // They have no image; the PDF renders this text where the picture would go.
                const renderText = isNumber
                    ? (variant === 'symbol' ? numeral : capitalize(word))
                    : '';

                return {
                    word,
                    initial: (row['Word Initial'] || '').trim().toLowerCase(),
                    final: (row['Word Final'] || '').trim().toLowerCase(),
                    structure: (row['Structure'] || '').trim().toLowerCase(),
                    type,
                    numeral,
                    variant,
                    // Disambiguate the two number variants in the results list.
                    label: isNumber ? `${word} (${variant})` : word,
                    renderText,
                    image: isNumber ? null : `images/${word}.jpg`
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
    const inputs = [wordSearchInput, firstLetterInput, initialSoundInput, finalSoundInput, structureInput];
    inputs.forEach(input => {
        input.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') {
                onSearch();
            }
        });
    });

    // Re-run the search immediately when the card type filter changes
    typeFilterSelect.addEventListener('change', onSearch);

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
    const typeFilter = typeFilterSelect.value;            // 'all' | 'word' | 'number'
    const query = wordSearchInput.value.trim().toLowerCase();
    const firstLetter = firstLetterInput.value.trim().toLowerCase();

    // Replicating Python perform_search behavior, plus type + word/number text search.
    const matches = allCards.filter(card => {
        if (typeFilter !== 'all' && card.type !== typeFilter) return false;
        if (initial && card.initial !== initial) return false;
        if (final && card.final !== final) return false;
        if (structure && card.structure !== structure) return false;
        if (query && !matchesQuery(card, query)) return false;
        if (firstLetter && !card.word.toLowerCase().startsWith(firstLetter)) return false;
        return true;
    });

    renderResults(matches);
}

// Free-text match: word matches as a substring; numerals match exactly so "1" does
// not also catch "10". This lets a number be found by its digit ("2") or its name ("two").
function matchesQuery(card, query) {
    if (card.word.toLowerCase().includes(query)) return true;
    if (card.numeral && card.numeral.toLowerCase() === query) return true;
    return false;
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
        checkbox.value = card.label;
        checkbox.dataset.type = card.type;
        if (card.type === 'number') {
            checkbox.dataset.text = card.renderText;
        } else {
            checkbox.dataset.image = card.image;
        }

        const checkmark = document.createElement('span');
        checkmark.className = 'checkmark';

        label.appendChild(checkbox);
        label.appendChild(checkmark);
        label.appendChild(document.createTextNode(` ${card.label}`));

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
        type: cb.dataset.type,
        image: cb.dataset.image,
        text: cb.dataset.text
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

    // Draw a number card: large centred text ("1" or "One") fitted to the card box.
    function drawNumberCard(text, cardX, cardY) {
        const maxDim = cardSize * 0.76;        // leave a margin inside the border
        doc.setFont('helvetica', 'bold');
        doc.setTextColor(0, 0, 0);

        // Size by width: text width scales linearly with font size.
        doc.setFontSize(100);
        const widthAt100 = doc.getTextWidth(text) || 1;
        const sizeByWidth = (maxDim / widthAt100) * 100;
        const sizeByHeight = maxDim / 0.3528;  // pt -> mm cap on glyph height
        const fontSize = Math.min(sizeByWidth, sizeByHeight);

        doc.setFontSize(fontSize);
        doc.text(text, cardX + cardSize / 2, cardY + cardSize / 2, {
            align: 'center',
            baseline: 'middle'
        });
    }

    // Pre-load images for word cards only (number cards render text instead).
    const dataUrls = await Promise.all(
        items.map(item => item.type === 'number' ? Promise.resolve(null) : toDataUrl(item.image))
    );

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

        // Number cards draw text; word cards fill the area with their image.
        if (items[i].type === 'number') {
            drawNumberCard(items[i].text, cardX, cardY);
        } else {
            doc.addImage(dataUrls[i], 'JPEG', cardX, cardY, cardSize, cardSize, '', 'FAST');
        }
        doc.rect(cardX, cardY, cardSize, cardSize, 'S');
    }

    doc.save('word-cards.pdf');
}
