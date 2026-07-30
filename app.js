// SLT Word Cards Web Application Logic
let allCards = [];

// Chosen cards, in the order they were ticked. Held here rather than read back
// out of the checkboxes so a selection survives re-running the search, and so
// present / print / share all work from the same list.
let selectedIds = [];

function isSelected(id) {
    return selectedIds.includes(id);
}

function setSelected(id, on) {
    const at = selectedIds.indexOf(id);
    if (on && at === -1) selectedIds.push(id);
    if (!on && at !== -1) selectedIds.splice(at, 1);
}

function cardById(id) {
    return allCards.find(card => card.id === id);
}

function selectedCards() {
    return selectedIds.map(cardById).filter(Boolean);
}

function capitalize(str) {
    return str ? str.charAt(0).toUpperCase() + str.slice(1) : str;
}

// DOM Elements
const searchBtn = document.getElementById('searchBtn');
const wordSearchInput = document.getElementById('wordSearch');
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
const presentBtn = document.getElementById('presentBtn');
const shareBtn = document.getElementById('shareBtn');

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
    setupPresenter();
    setupSharing();
    setupDeckFileImport();
    setupCardRequest();
    setupIssueReport();
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
                    // Stable identity, shared with the iOS/Mac app so a deck can
                    // travel between them as a list of ids.
                    id: `${word}|${type}|${variant}`,
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

            // Drop exact duplicates (cards.csv lists "peg" twice) so ids stay unique.
            const seenIds = new Set();
            allCards = allCards.filter(card => {
                if (seenIds.has(card.id)) return false;
                seenIds.add(card.id);
                return true;
            });

            console.log("Loaded cards:", allCards);
            statusLabel.textContent = `Loaded ${allCards.length} cards. Ready.`;

            // A shared deck in the address can only be resolved once the cards
            // are known.
            window.dispatchEvent(new Event('cards-loaded'));
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
    const inputs = [wordSearchInput, initialSoundInput, finalSoundInput, structureInput];
    inputs.forEach(input => {
        input.addEventListener('keyup', (e) => {
            if (e.key === 'Enter') {
                onSearch();
            }
        });
    });

    // Re-run the search immediately when the card type filter changes
    typeFilterSelect.addEventListener('change', onSearch);

    // Keep the ordered selection in step with the checkboxes.
    resultsList.addEventListener('change', (e) => {
        const checkbox = e.target;
        if (checkbox.type !== 'checkbox') return;
        setSelected(checkbox.dataset.id, checkbox.checked);
    });

    // Select All Checkbox
    selectAllCheckbox.addEventListener('change', (e) => {
        const checkboxes = resultsList.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(cb => {
            cb.checked = e.target.checked;
            setSelected(cb.dataset.id, e.target.checked);
        });
    });

    // Print Action
    printBtn.addEventListener('click', generatePrintSelection);

    // "Request a Card" opens the form — see setupCardRequest. It used to build a
    // mailto:, which put the destination address in front of the user.
}

function onSearch() {
    const initial = initialSoundInput.value.trim().toLowerCase();
    const final = finalSoundInput.value.trim().toLowerCase();
    const structure = structureInput.value.trim().toLowerCase();
    const typeFilter = typeFilterSelect.value;            // 'all' | 'word' | 'number'
    const query = wordSearchInput.value.trim().toLowerCase();

    // Replicating Python perform_search behavior, plus type + word/number text search.
    const matches = allCards.filter(card => {
        if (typeFilter !== 'all' && card.type !== typeFilter) return false;
        if (initial && card.initial !== initial) return false;
        if (final && card.final !== final) return false;
        if (structure && card.structure !== structure) return false;
        if (query && !matchesQuery(card, query)) return false;
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
        checkbox.dataset.id = card.id;
        checkbox.dataset.type = card.type;
        if (isSelected(card.id)) checkbox.checked = true;
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
    const chosen = selectedCards();

    if (chosen.length === 0) {
        alert("Please select at least one word to generate a PDF.");
        return;
    }

    const selectedWords = chosen.map(card => ({
        word: card.label,
        type: card.type,
        image: card.image,
        text: card.renderText
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

// ---------------------------------------------------------------------------
// Present mode
//
// One card at a time, click or tap to reveal the word — the same flow as the
// iOS/Mac app's presenter, including arrow keys and space to reveal.
// ---------------------------------------------------------------------------

const presenter = {
    root: null,
    order: [],
    index: 0,
    revealed: false,
    // 'present' just shows cards; 'test' marks each answer and keeps a score.
    mode: 'present',
    // Marks for this run only, keyed by card id. Deliberately not stored: a score
    // is about the session in front of you, not a record kept on a client.
    marks: {},
    source: []
};

function setupPresenter() {
    presenter.root = document.getElementById('presenter');

    presentBtn.addEventListener('click', () => {
        const chosen = selectedCards();
        if (chosen.length === 0) {
            alert('Select at least one card to present.');
            return;
        }
        openPresenter(chosen, 'Selection', 'present');
    });

    document.getElementById('testBtn').addEventListener('click', () => {
        const chosen = selectedCards();
        if (chosen.length === 0) {
            alert('Select at least one card to test.');
            return;
        }
        openPresenter(chosen, 'Selection', 'test');
    });

    document.getElementById('presenterRight').addEventListener('click', () => markAnswer(true));
    document.getElementById('presenterWrong').addEventListener('click', () => markAnswer(false));
    document.getElementById('presenterSummaryDone').addEventListener('click', () => {
        closePresenter({ confirmIfUnfinished: false });
    });
    document.getElementById('presenterRetryAll').addEventListener('click', () => {
        startRun(presenter.source);
    });
    document.getElementById('presenterRetryMissed').addEventListener('click', () => {
        startRun(presenter.order.filter(card => presenter.marks[card.id] === false));
    });

    // Wrapped rather than passed directly: the handler would hand the click event
    // in as the options object.
    document.getElementById('presenterClose').addEventListener('click', () => closePresenter());
    document.getElementById('presenterPrev').addEventListener('click', () => movePresenter(-1));
    document.getElementById('presenterNext').addEventListener('click', () => movePresenter(1));
    document.getElementById('presenterCard').addEventListener('click', toggleReveal);

    document.getElementById('presenterShuffle').addEventListener('click', () => {
        for (let i = presenter.order.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [presenter.order[i], presenter.order[j]] = [presenter.order[j], presenter.order[i]];
        }
        presenter.index = 0;
        presenter.revealed = false;
        renderPresenter();
    });

    document.getElementById('presenterAlwaysShow').addEventListener('change', renderPresenter);

    document.addEventListener('keydown', (e) => {
        if (presenter.root.hidden) return;
        const testing = presenter.mode === 'test';
        const summaryShowing = !document.getElementById('presenterSummary').hidden;
        if (summaryShowing) {
            if (e.key === 'Escape') closePresenter();
            return;
        }
        if (e.key === 'ArrowRight') {
            if (!testing) movePresenter(1);
            e.preventDefault();
        } else if (e.key === 'ArrowLeft') { movePresenter(-1); e.preventDefault(); }
        else if (e.key === ' ' || e.key === 'Enter') { toggleReveal(); e.preventDefault(); }
        else if (testing && showingWord() && (e.key === '1' || e.key === 'x')) { markAnswer(false); e.preventDefault(); }
        else if (testing && showingWord() && (e.key === '2' || e.key === 'c')) { markAnswer(true); e.preventDefault(); }
        else if (e.key === 'Escape') { closePresenter(); }
    });
}

function openPresenter(cards, title, mode = 'present') {
    presenter.mode = mode;
    presenter.source = cards.slice();
    document.getElementById('presenterTitle').textContent =
        mode === 'test' ? `${title} · Test` : title;

    // Always showing the word would defeat a test.
    document.getElementById('presenterAlwaysShowRow').hidden = mode === 'test';
    document.getElementById('presenterAlwaysShow').checked = false;
    document.getElementById('presenterScore').hidden = mode !== 'test';

    presenter.root.hidden = false;
    document.body.classList.add('presenting');
    startRun(cards);
}

// Resets for a fresh run over `cards`, keeping the mode and the original deck.
function startRun(cards) {
    presenter.order = cards.slice();
    presenter.index = 0;
    presenter.revealed = false;
    presenter.marks = {};
    document.getElementById('presenterSummary').hidden = true;
    document.querySelector('.presenter-stage').hidden = false;
    document.querySelector('.presenter-controls').hidden = false;
    renderPresenter();
}

function showingWord() {
    return presenter.mode === 'test'
        ? presenter.revealed
        : presenter.revealed || document.getElementById('presenterAlwaysShow').checked;
}

// Records the answer and moves on, or finishes the run on the last card.
function markAnswer(correct) {
    if (presenter.mode !== 'test' || !showingWord()) return;
    const card = presenter.order[presenter.index];
    if (!card) return;

    presenter.marks[card.id] = correct;

    if (presenter.index >= presenter.order.length - 1) {
        showTestSummary();
    } else {
        movePresenter(1);
    }
}

function scoreCounts() {
    const values = Object.values(presenter.marks);
    return {
        correct: values.filter(Boolean).length,
        wrong: values.filter(v => v === false).length,
        marked: values.length
    };
}

function showTestSummary() {
    const { correct, marked } = scoreCounts();
    const missed = presenter.order.filter(card => presenter.marks[card.id] === false);

    document.getElementById('presenterSummaryScore').textContent = `${correct} of ${marked}`;
    const percent = marked ? Math.round(correct / marked * 100) : 0;
    document.getElementById('presenterSummaryLine').textContent =
        missed.length === 0 ? `All correct · ${percent}%` : `${percent}% correct`;

    const missedBox = document.getElementById('presenterSummaryMissed');
    missedBox.innerHTML = '';
    if (missed.length > 0) {
        const heading = document.createElement('p');
        heading.className = 'presenter-summary-heading';
        heading.textContent = 'Not yet';
        missedBox.appendChild(heading);
        missed.forEach(card => {
            const row = document.createElement('span');
            row.className = 'presenter-summary-chip';
            row.textContent = card.label;
            missedBox.appendChild(row);
        });
    }
    document.getElementById('presenterRetryMissed').hidden = missed.length === 0;

    document.querySelector('.presenter-stage').hidden = true;
    document.querySelector('.presenter-controls').hidden = true;
    document.getElementById('presenterSummary').hidden = false;
}

// A part-finished score exists only in memory, so closing has to be deliberate —
// there is nothing to fall back on afterwards.
function testInProgress() {
    return presenter.mode === 'test'
        && Object.keys(presenter.marks).length > 0
        && document.getElementById('presenterSummary').hidden;
}

function closePresenter({ confirmIfUnfinished = true } = {}) {
    if (confirmIfUnfinished && testInProgress()) {
        const ok = window.confirm(
            "Discard this test? The score so far isn't saved anywhere, so closing now loses it."
        );
        if (!ok) return;
    }

    presenter.root.hidden = true;
    document.body.classList.remove('presenting');

    // The score lasts exactly as long as the test is open.
    presenter.marks = {};
    presenter.order = [];
    presenter.source = [];
}

function movePresenter(step) {
    const next = presenter.index + step;
    if (next < 0 || next >= presenter.order.length) return;
    if (presenter.mode === 'test' && step < 0) {
        delete presenter.marks[presenter.order[next].id];
    }
    presenter.index = next;
    presenter.revealed = false;
    renderPresenter();
}

function toggleReveal() {
    presenter.revealed = !presenter.revealed;
    renderPresenter();
}

function renderPresenter() {
    const card = presenter.order[presenter.index];
    if (!card) return;

    const image = document.getElementById('presenterImage');
    const faceText = document.getElementById('presenterFaceText');

    // Number cards show their numeral or spelled word where the picture goes,
    // matching the printed card.
    if (card.type === 'number') {
        image.hidden = true;
        image.removeAttribute('src');
        faceText.hidden = false;
        faceText.textContent = card.renderText;
    } else {
        faceText.hidden = true;
        image.hidden = false;
        image.src = card.image;
        image.alt = '';
        image.onerror = () => { image.src = 'images/no_image.jpg'; };
    }

    const testing = presenter.mode === 'test';
    const showWord = showingWord();

    const word = document.getElementById('presenterWord');
    word.textContent = capitalize(card.label);
    word.style.opacity = showWord ? '1' : '0';
    const hint = document.getElementById('presenterHint');
    hint.textContent = testing
        ? 'Tap the card to check the answer'
        : 'Tap the card to show the word';
    hint.style.opacity = showWord ? '0' : '1';

    // Marking appears only after the reveal; the row keeps its height regardless.
    const markSlot = document.getElementById('presenterMarkSlot');
    markSlot.hidden = !testing;
    markSlot.style.visibility = testing && showWord ? 'visible' : 'hidden';

    const { correct, wrong } = scoreCounts();
    document.getElementById('presenterScore').textContent =
        `\u2713 ${correct} \u00b7 \u2717 ${wrong}`;

    document.getElementById('presenterCount').textContent =
        `${presenter.index + 1} of ${presenter.order.length}`;
    const progress = document.getElementById('presenterProgress');
    progress.max = presenter.order.length;
    progress.value = presenter.index + 1;

    document.getElementById('presenterPrev').disabled = presenter.index === 0;
    const next = document.getElementById('presenterNext');
    // In a test you advance by marking, so the score can't be skipped past.
    next.disabled = testing || presenter.index >= presenter.order.length - 1;
    next.style.visibility = testing ? 'hidden' : 'visible';
}

// ---------------------------------------------------------------------------
// Sharing a deck
//
// A deck is just a list of card ids, because every copy of the app — web, iOS
// and Mac — resolves pictures from the same cards.csv and images/. That list is
// base64url-encoded JSON in the URL *fragment*, so it never reaches a server.
// The encoding is byte-for-byte the same as the app's .sltdeck payload.
// ---------------------------------------------------------------------------

const DECK_PAYLOAD_VERSION = 1;
const APP_URL_SCHEME = 'sltcards://deck?d=';
const DECK_LINK_PATH = '/deck/';

// Shared links always name the canonical host, never whatever the user happens to
// be browsing. iOS matches a universal link's hostname exactly and decides before
// any redirect runs, so a link built from www.speakeasy-slt.uk would open Safari
// instead of the app — the redirect to the apex comes too late to help.
const CANONICAL_ORIGIN = 'https://speakeasy-slt.uk';
const CANONICAL_HOST_SUFFIX = 'speakeasy-slt.uk';

function shareOrigin() {
    // Any variant of the live domain shares as the canonical apex. Localhost and
    // Netlify deploy previews keep their own origin so links work while testing.
    return location.hostname.endsWith(CANONICAL_HOST_SUFFIX)
        ? CANONICAL_ORIGIN
        : location.origin;
}

// The native app exists on Apple platforms only, so app-specific affordances
// stay hidden elsewhere rather than offering a link that can't work.
function isApplePlatform() {
    const ua = navigator.userAgent || '';
    return /iPhone|iPad|iPod|Macintosh|Mac OS X/i.test(ua);
}

function base64UrlEncode(text) {
    const bytes = new TextEncoder().encode(text);
    let binary = '';
    bytes.forEach(byte => { binary += String.fromCharCode(byte); });
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(encoded) {
    let padded = encoded.replace(/-/g, '+').replace(/_/g, '/');
    while (padded.length % 4 !== 0) padded += '=';
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, ch => ch.charCodeAt(0));
    return new TextDecoder().decode(bytes);
}

// Word-card ids all end in the same `|word|`, which is pure repetition in a
// link. Send the bare word instead and expand it on the way back in. Number
// cards keep their full id because their variant matters. No version bump is
// needed: an entry containing "|" is a full id, so older links still open.
function shortenCardId(id) {
    const parts = id.split('|');
    if (parts.length === 3 && parts[1] === 'word' && parts[2] === '') return parts[0];
    return id;
}

function expandCardId(token) {
    return token.includes('|') ? token : `${token}|word|`;
}

function encodeDeckPayload(name, cards, copies) {
    return base64UrlEncode(JSON.stringify({
        v: DECK_PAYLOAD_VERSION,
        n: name,
        c: cards.map(card => shortenCardId(card.id)),
        p: copies
    }));
}

function decodeDeckPayload(encoded) {
    try {
        const payload = JSON.parse(base64UrlDecode(encoded));
        if (!payload || typeof payload !== 'object') return null;
        if (Number(payload.v) > DECK_PAYLOAD_VERSION) return null;
        if (!Array.isArray(payload.c) || payload.c.length === 0) return null;
        return {
            version: Number(payload.v) || 1,
            name: typeof payload.n === 'string' ? payload.n : 'Shared deck',
            cardIds: payload.c.filter(id => typeof id === 'string').map(expandCardId),
            copies: Number(payload.p) > 0 ? Number(payload.p) : 1
        };
    } catch (err) {
        return null;
    }
}

function setupSharing() {
    const dialog = document.getElementById('shareDialog');
    const nameInput = document.getElementById('shareDeckName');
    const linkField = document.getElementById('shareLink');
    const lengthNote = document.getElementById('shareLength');
    const systemShareBtn = document.getElementById('shareSystemBtn');

    const refresh = () => {
        const chosen = selectedCards();
        const copies = Math.max(1, parseInt(instanceCountInput.value, 10) || 1);
        const name = nameInput.value.trim() || 'Shared deck';
        const payload = encodeDeckPayload(name, chosen, copies);
        // Shared decks live at /deck/ so that Apple's universal links can claim
        // that one path — a device with the app opens it there, one without it
        // lands on the web app.
        linkField.value = `${shareOrigin()}${DECK_LINK_PATH}#deck=${payload}`;
        lengthNote.textContent =
            `${chosen.length} card${chosen.length === 1 ? '' : 's'} · ${linkField.value.length} characters`;
    };

    shareBtn.addEventListener('click', () => {
        if (selectedCards().length === 0) {
            alert('Select at least one card to share.');
            return;
        }
        if (!nameInput.value.trim()) nameInput.value = 'Shared deck';
        refresh();
        dialog.hidden = false;
    });

    nameInput.addEventListener('input', refresh);

    document.getElementById('shareCloseBtn').addEventListener('click', () => {
        dialog.hidden = true;
    });

    document.getElementById('shareCopyBtn').addEventListener('click', async () => {
        const button = document.getElementById('shareCopyBtn');
        try {
            await navigator.clipboard.writeText(linkField.value);
        } catch (err) {
            // Clipboard API needs a secure context; fall back to selecting the text.
            linkField.select();
            document.execCommand('copy');
        }
        button.textContent = 'Copied';
        setTimeout(() => { button.textContent = 'Copy Link'; }, 2000);
    });

    // Only offer the system share sheet where the browser actually has one.
    if (navigator.share) {
        systemShareBtn.hidden = false;
        systemShareBtn.addEventListener('click', () => {
            navigator.share({
                title: nameInput.value.trim() || 'SLT card deck',
                text: 'Practise these cards:',
                url: linkField.value
            }).catch(() => { /* dismissed */ });
        });
    }

    setupIncomingDeck();
}

// A link opened with #deck=… offers to present it or tick the cards.
function setupIncomingDeck() {
    document.getElementById('incomingDismissBtn').addEventListener('click', () => {
        document.getElementById('incomingDialog').hidden = true;
    });

    // On first load, and again if a new deck link is pasted into the address bar
    // of an already-open page — a fragment change alone never reloads.
    window.addEventListener('cards-loaded', offerIncomingDeck);
    window.addEventListener('hashchange', () => {
        if (allCards.length > 0) offerIncomingDeck();
    });
}

function offerIncomingDeck() {
    const payload = readDeckFromLocation();
    if (payload) offerDeck(payload, 'the link');
}

// Presents a decoded deck for confirmation, however it arrived — a link, or a
// file dropped onto the page.
function offerDeck(payload, source) {
    const dialog = document.getElementById('incomingDialog');
    const cards = payload.cardIds.map(cardById).filter(Boolean);
    const missing = payload.cardIds.length - cards.length;

    if (cards.length === 0) {
        alert('That deck has no cards this version of the card set knows about.');
        return;
    }

    document.getElementById('incomingTitle').textContent = payload.name;
    document.getElementById('incomingSummary').textContent =
        `${cards.length} card${cards.length === 1 ? '' : 's'} ready` +
        (missing > 0 ? ` · ${missing} not in this card set yet` : '') +
        `. Nothing was uploaded — the deck came from ${source}.`;
    // The app only exists on Apple platforms, so don't dangle a dead link
    // elsewhere. On those platforms a verified universal link means people with
    // the app never see this page anyway — this covers the ones where it didn't
    // resolve.
    const appRow = document.getElementById('incomingAppRow');
    if (isApplePlatform()) {
        document.getElementById('incomingAppLink').href =
            APP_URL_SCHEME + encodeDeckPayload(payload.name, cards, payload.copies);
        appRow.hidden = false;
    } else {
        appRow.hidden = true;
    }

    document.getElementById('incomingPresentBtn').onclick = () => {
        dialog.hidden = true;
        openPresenter(cards, payload.name);
    };

    document.getElementById('incomingSelectBtn').onclick = () => {
        dialog.hidden = true;
        selectedIds = cards.map(card => card.id);
        instanceCountInput.value = payload.copies;
        wordSearchInput.value = '';
        initialSoundInput.value = '';
        finalSoundInput.value = '';
        structureInput.value = '';
        typeFilterSelect.value = 'all';
        renderResults(cards);
        statusLabel.textContent = `${cards.length} cards from "${payload.name}" selected.`;
    };

    dialog.hidden = false;
}

function readDeckFromLocation() {
    const fragment = location.hash.startsWith('#') ? location.hash.slice(1) : location.hash;
    const params = new URLSearchParams(fragment);
    const encoded = params.get('deck');
    return encoded ? decodeDeckPayload(encoded) : null;
}

// ---------------------------------------------------------------------------
// Opening a deck file
//
// A link is the main way decks travel, but a .sltdeck file still arrives by
// AirDrop or email — and works with no connection at all. Reading one here means
// a deck can be opened on any platform, not only where the app runs.
//
// Two shapes are accepted: the file's full-key JSON, and the compact payload
// used in links, in case someone saved a link's contents to a file.
// ---------------------------------------------------------------------------

const DECK_FILE_FORMAT = 'slt-word-cards.deck';

function decodeDeckFile(text) {
    let parsed;
    try {
        parsed = JSON.parse(text);
    } catch (err) {
        throw new Error("That file isn't a deck — it couldn't be read as JSON.");
    }
    if (!parsed || typeof parsed !== 'object') {
        throw new Error("That file isn't a deck.");
    }

    // The compact link payload, saved to a file.
    if (Array.isArray(parsed.c)) {
        const compact = decodeDeckPayload(base64UrlEncode(text));
        if (compact) return compact;
    }

    if (parsed.format !== DECK_FILE_FORMAT) {
        throw new Error("That file isn't an SLT card deck.");
    }
    if (Number(parsed.version) > DECK_PAYLOAD_VERSION) {
        throw new Error('That deck was made with a newer version. Refresh the page and try again.');
    }
    const cardIds = Array.isArray(parsed.cardIDs)
        ? parsed.cardIDs.filter(id => typeof id === 'string').map(expandCardId)
        : [];
    if (cardIds.length === 0) {
        throw new Error('That deck is empty.');
    }

    return {
        version: Number(parsed.version) || 1,
        name: typeof parsed.name === 'string' && parsed.name.trim() ? parsed.name : 'Shared deck',
        cardIds,
        copies: Number(parsed.printCopies) > 0 ? Number(parsed.printCopies) : 1
    };
}

function setupDeckFileImport() {
    const openBtn = document.getElementById('openDeckBtn');
    const fileInput = document.getElementById('deckFileInput');

    openBtn.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', () => {
        const file = fileInput.files && fileInput.files[0];
        if (file) readDeckFile(file);
        // Clear it so choosing the same file twice still fires a change.
        fileInput.value = '';
    });

    // Drag a deck anywhere onto the page.
    ['dragenter', 'dragover'].forEach(name => {
        document.addEventListener(name, (e) => {
            if (!eventHasFiles(e)) return;
            e.preventDefault();
            document.body.classList.add('deck-drop-active');
        });
    });

    ['dragleave', 'dragend'].forEach(name => {
        document.addEventListener(name, (e) => {
            if (e.relatedTarget === null) document.body.classList.remove('deck-drop-active');
        });
    });

    document.addEventListener('drop', (e) => {
        if (!eventHasFiles(e)) return;
        e.preventDefault();
        document.body.classList.remove('deck-drop-active');
        const file = e.dataTransfer.files && e.dataTransfer.files[0];
        if (file) readDeckFile(file);
    });
}

function eventHasFiles(event) {
    return event.dataTransfer && Array.from(event.dataTransfer.types || []).includes('Files');
}

function readDeckFile(file) {
    const reader = new FileReader();
    reader.onload = () => {
        try {
            offerDeck(decodeDeckFile(String(reader.result)), `"${file.name}"`);
        } catch (err) {
            alert(err.message);
        }
    };
    reader.onerror = () => alert("That file couldn't be read.");
    reader.readAsText(file);
}

// ---------------------------------------------------------------------------
// Requesting a card, and reporting an issue
//
// Both collect their fields here, format them, and hand a ready-made message to
// the user's own mail app. The sounds are chosen from the same IPA keyboard the
// search fields use, so a phoneme is picked rather than typed — which is what
// makes the request usable without a round of clarification.
//
// mailto: cannot carry an attachment, so a chosen picture is squared off to
// 500x500 and downloaded for the user to attach to the message themselves.
// ---------------------------------------------------------------------------

const SUPPORT_ADDRESS = 'james@applebytechnical.com';

function openFormattedEmail(subject, body) {
    const url = `mailto:${SUPPORT_ADDRESS}`
        + `?subject=${encodeURIComponent(subject)}`
        + `&body=${encodeURIComponent(body)}`;
    window.location.href = url;
}

function setupCardRequest() {
    const dialog = document.getElementById('requestDialog');
    const status = document.getElementById('requestStatus');
    const structureSelect = document.getElementById('requestStructure');

    // The same IPA keyboards as the search fields.
    setupIpaField(
        document.getElementById('requestInitial'),
        document.getElementById('requestInitialToggle'),
        document.getElementById('requestInitialKeyboard')
    );
    setupIpaField(
        document.getElementById('requestFinal'),
        document.getElementById('requestFinalToggle'),
        document.getElementById('requestFinalKeyboard')
    );

    // Offer the structures already in use, so requests stay consistent with the set.
    window.addEventListener('cards-loaded', () => {
        const structures = [...new Set(allCards.map(card => card.structure))]
            .filter(Boolean)
            .sort((a, b) => a.length - b.length || a.localeCompare(b));
        structures.forEach(structure => {
            const option = document.createElement('option');
            option.value = structure;
            option.textContent = structure.toUpperCase();
            structureSelect.appendChild(option);
        });
    });

    document.getElementById('infoBtn').addEventListener('click', () => {
        status.textContent = '';
        status.style.color = '';
        dialog.hidden = false;
        document.getElementById('requestWord').focus();
    });

    document.getElementById('requestCloseBtn').addEventListener('click', () => {
        dialog.hidden = true;
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !dialog.hidden) dialog.hidden = true;
    });

    document.getElementById('requestSubmitBtn').addEventListener('click', async () => {
        const word = document.getElementById('requestWord').value.trim();
        const initial = document.getElementById('requestInitial').value.trim();
        const final = document.getElementById('requestFinal').value.trim();
        const structure = structureSelect.value;
        const notes = document.getElementById('requestNotes').value.trim();
        const file = document.getElementById('requestImage').files[0];

        // Everything but the picture is required.
        if (!word || !initial || !final || !structure) {
            status.style.color = '#b91c1c';
            status.textContent = 'Fill in the word, both sounds, and the structure.';
            return;
        }

        // A picture can't be attached to a mailto, so save it for the user to add.
        let imageNote = 'no';
        if (file) {
            const saved = await downloadSquaredImage(file, word);
            imageNote = saved
                ? `yes — "${saved}" has been saved to your downloads, please attach it`
                : 'yes, to follow separately';
        }

        const lines = [
            `Word: ${word}`,
            `Type: ${document.getElementById('requestType').value}`,
            `Word initial sound: ${initial}`,
            `Word final sound: ${final}`,
            `Structure: ${structure.toUpperCase()}`,
            `Image: ${imageNote}`
        ];
        if (notes) lines.push('', 'Notes:', notes);
        lines.push('', 'Sent from the SLT Word Cards website.');

        openFormattedEmail(`Card request: ${word}`, lines.join('\n'));

        status.style.color = '';
        status.textContent = file
            ? 'Your email is open — remember to attach the saved picture.'
            : 'Your email is open, ready to send.';
    });
}

// Squares a picture to 500x500 with white padding — matching how the app treats
// pictures — and saves it so it can be attached. Returns the filename, or null.
async function downloadSquaredImage(file, word) {
    try {
        const bitmap = await createImageBitmap(file);
        const side = 500;
        const canvas = document.createElement('canvas');
        canvas.width = side;
        canvas.height = side;

        const ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, side, side);

        // Aspect fit, centred — never crop, never warp.
        const scale = Math.min(side / bitmap.width, side / bitmap.height);
        const width = bitmap.width * scale;
        const height = bitmap.height * scale;
        ctx.drawImage(bitmap, (side - width) / 2, (side - height) / 2, width, height);
        bitmap.close();

        const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.9));
        if (!blob) return null;

        const name = `${(word || 'card').replace(/[^\w-]+/g, '-')}.jpg`;
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = name;
        link.click();
        URL.revokeObjectURL(url);
        return name;
    } catch (err) {
        console.warn('Could not prepare the picture.', err);
        return null;
    }
}

function setupIssueReport() {
    const dialog = document.getElementById('issueDialog');
    const status = document.getElementById('issueStatus');
    const description = document.getElementById('issueDescription');

    document.getElementById('issueBtn').addEventListener('click', () => {
        status.textContent = '';
        status.style.color = '';
        dialog.hidden = false;
        description.focus();
    });

    document.getElementById('issueCloseBtn').addEventListener('click', () => {
        dialog.hidden = true;
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !dialog.hidden) dialog.hidden = true;
    });

    document.getElementById('issueSubmitBtn').addEventListener('click', () => {
        const what = description.value.trim();
        if (!what) {
            status.style.color = '#b91c1c';
            status.textContent = 'Please describe what went wrong.';
            description.focus();
            return;
        }
        const steps = document.getElementById('issueSteps').value.trim();

        const lines = ['What happened:', what];
        if (steps) lines.push('', 'What they did just before:', steps);
        // Filled in rather than asked for.
        lines.push('', `Browser: ${navigator.userAgent}`, `Page: ${location.href}`);

        openFormattedEmail('SLT Word Cards issue report', lines.join('\n'));

        status.style.color = '';
        status.textContent = 'Your email is open, ready to send.';
    });
}
