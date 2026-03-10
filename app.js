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
        image: cb.dataset.image
    }));

    let count = parseInt(instanceCountInput.value, 10);
    if (isNaN(count) || count < 1) count = 1;

    // Multiply selection by count
    const printList = [];
    for (let i = 0; i < count; i++) {
        printList.push(...selectedWords);
    }

    renderPrintGrids(printList);

    // Trigger print dialog
    setTimeout(() => {
        window.print();
    }, 500); // Give DOM a brief moment to render images
}

function renderPrintGrids(items) {
    printArea.innerHTML = ''; // Clear previous

    // Python code logic: 3 cols, 4 rows = 12 items per page
    const itemsPerPage = 12;

    // Chunk items into pages
    for (let i = 0; i < items.length; i += itemsPerPage) {
        const pageItems = items.slice(i, i + itemsPerPage);
        const isLastPage = (i + itemsPerPage >= items.length);

        // Wrapper provides the 5% margins; grid fills its content area
        const page = document.createElement('div');
        page.className = 'print-page';

        // Only force a page break after non-last pages; never after the last
        if (!isLastPage) {
            page.style.pageBreakAfter = 'always';
            page.style.breakAfter = 'page';
        }

        const grid = document.createElement('div');
        grid.className = 'print-grid';

        pageItems.forEach(item => {
            const cell = document.createElement('div');
            cell.className = 'print-cell';

            const card = document.createElement('div');
            card.className = 'print-card';

            const img = document.createElement('img');
            img.src = item.image;
            img.alt = item.word;

            // Fallback to no_image.jpg if image is missing
            img.onerror = function () {
                if (this.src !== 'images/no_image.jpg') {
                    this.src = 'images/no_image.jpg';
                }
            };

            card.appendChild(img);
            cell.appendChild(card);
            grid.appendChild(cell);
        });

        // Fill remaining cells on the last page with empty spaces to maintain grid layout
        if (pageItems.length < itemsPerPage) {
            const emptyCellsNeeded = itemsPerPage - pageItems.length;
            for (let j = 0; j < emptyCellsNeeded; j++) {
                const emptyCell = document.createElement('div');
                emptyCell.className = 'print-cell';
                grid.appendChild(emptyCell);
            }
        }

        page.appendChild(grid);
        printArea.appendChild(page);
    }
}
