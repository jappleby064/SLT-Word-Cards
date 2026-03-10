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
const printArea = document.getElementById('print-area');

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

function generatePrintSelection() {
    const selectedCheckboxes = Array.from(resultsList.querySelectorAll('input[type="checkbox"]:checked'));

    if (selectedCheckboxes.length === 0) {
        alert("Please select at least one word to print.");
        return;
    }

    const selectedWords = selectedCheckboxes.map(cb => ({
        word: cb.value,
        // Resolve to absolute URL so images load correctly in the new window
        image: new URL(cb.dataset.image, window.location.href).href
    }));

    let count = parseInt(instanceCountInput.value, 10);
    if (isNaN(count) || count < 1) count = 1;

    const printList = [];
    for (let i = 0; i < count; i++) {
        printList.push(...selectedWords);
    }

    openPrintWindow(printList);
}

function openPrintWindow(items) {
    const itemsPerPage = 12;
    const noImageUrl = new URL('images/no_image.jpg', window.location.href).href;
    let gridsHtml = '';

    for (let i = 0; i < items.length; i += itemsPerPage) {
        const pageItems = items.slice(i, i + itemsPerPage);
        const isLast = (i + itemsPerPage >= items.length);
        const breakStyle = isLast ? '' : ' style="page-break-after:always;break-after:page;"';

        let cellsHtml = pageItems.map(item =>
            `<div class="cell"><div class="card"><img src="${item.image}" alt="${item.word}" onerror="if(this.src!=='${noImageUrl}')this.src='${noImageUrl}'"></div></div>`
        ).join('');

        // Pad to fill the 3×4 grid
        for (let j = pageItems.length; j < itemsPerPage; j++) {
            cellsHtml += '<div class="cell"></div>';
        }

        gridsHtml += `<div class="grid"${breakStyle}>${cellsHtml}</div>`;
    }

    const html = `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>SLT Word Cards</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
@page{size:A4 portrait;margin:10mm}
body{background:white}
.grid{display:grid;grid-template-columns:repeat(3,1fr);grid-template-rows:repeat(4,1fr);width:100%;height:277mm}
.cell{display:flex;justify-content:center;align-items:center;width:100%;height:100%}
.card{width:90%;aspect-ratio:1/1;max-height:90%;border:3px solid black}
.card img{width:100%;height:100%;object-fit:contain;display:block}
</style></head>
<body>${gridsHtml}</body></html>`;

    const w = window.open('', '_blank');
    w.document.write(html);
    w.document.close();

    // Print once images have loaded
    setTimeout(() => {
        w.print();
        w.addEventListener('afterprint', () => w.close());
    }, 500);
}
