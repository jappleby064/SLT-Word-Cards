/*
    Rosie's Dictionary — ported from the standalone project at
    github.com/jappleby064/dictionary. The logic is unchanged; only the
    presentation was brought onto this site's palette and type, in the
    page-local stylesheet inside dictionary.html.

    Every lookup here leaves the device: this page queries dictionaryapi.dev,
    Wikipedia, Wiktionary, Etymology Explorer and Datamuse. That is the one
    tool on the site that does, and the privacy page says so.
*/

const searchInput  = document.getElementById('search-input');
const searchBtn    = document.getElementById('search-btn');
const clearBtn     = document.getElementById('clear-btn');
const resultsEl    = document.getElementById('results');
const errorEl      = document.getElementById('error');
const suggestionsEl = document.getElementById('suggestions');

// Cache word IDs from autocomplete so etymology fetch skips the extra round-trip
const wordIdCache = {};
let autocompleteTimer = null;

// ── Search box events ─────────────────────────────────────────────────────────

searchBtn.addEventListener('click', search);
searchInput.addEventListener('keydown', e => {
    if (e.key === 'Enter') { hideSuggestions(); search(); }
    if (e.key === 'Escape') hideSuggestions();
});
clearBtn.addEventListener('click', () => {
    searchInput.value = '';
    clearBtn.classList.add('hidden');
    searchInput.focus();
    hideSuggestions();
    hide(resultsEl);
    hide(errorEl);
});
searchInput.addEventListener('input', () => {
    clearBtn.classList.toggle('hidden', searchInput.value === '');
    clearTimeout(autocompleteTimer);
    const val = searchInput.value.trim();
    if (val.length < 2) { hideSuggestions(); return; }
    autocompleteTimer = setTimeout(() => loadSuggestions(val), 280);
});

// Close suggestions when clicking outside the search wrapper
document.addEventListener('click', e => {
    if (!e.target.closest('.search-wrapper')) hideSuggestions();
});

// Suggestion item clicks
suggestionsEl.addEventListener('click', e => {
    const item = e.target.closest('.suggestion-item');
    if (!item) return;
    searchInput.value = item.dataset.word;
    clearBtn.classList.remove('hidden');
    hideSuggestions();
    search();
});

// Chip clicks — covers both synonym chips in results and spelling suggestions in error
[resultsEl, errorEl].forEach(el => el.addEventListener('click', e => {
    const chip = e.target.closest('.synonym-chip');
    if (chip) searchWord(chip.dataset.word);
}));

// ── Autocomplete ──────────────────────────────────────────────────────────────

async function loadSuggestions(prefix) {
    try {
        const res  = await fetch(
            `https://api.etymologyexplorer.com/prod/autocomplete?word=${enc(prefix)}&language=English`
        );
        const data = await res.json();
        const items = data.auto_complete_data || [];
        items.forEach(item => { wordIdCache[item.word.toLowerCase()] = item._id; });
        const clean = items
            .map(i => i.word)
            .filter(w => /^[a-zA-Z'-]{2,25}$/.test(w) && !/^\d/.test(w));
        showSuggestions(clean.slice(0, 7));
    } catch {
        hideSuggestions();
    }
}

function showSuggestions(words) {
    if (!words.length) { hideSuggestions(); return; }
    suggestionsEl.innerHTML = words.map(w =>
        `<div class="suggestion-item" data-word="${esc(w)}">
             <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                 <path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
             </svg>
             ${esc(w)}
         </div>`
    ).join('');
    suggestionsEl.classList.remove('hidden');
}

function hideSuggestions() {
    suggestionsEl.classList.add('hidden');
    suggestionsEl.innerHTML = '';
}

// ── Main search ───────────────────────────────────────────────────────────────

async function search() {
    const word = searchInput.value.trim();
    if (!word) return;

    const token = ++searchToken;
    hideSuggestions();
    hide(errorEl);
    networkTrouble = false;

    const cached = lookupCache.get(word.toLowerCase());
    if (cached) { paint(cached); return; }

    resultsEl.innerHTML = '<div class="loading-msg">Looking up&hellip;</div>';
    show(resultsEl);

    /*
        All three requests go out together, but the definition is the only one
        the reader is waiting for. Origin and synonyms come from services that
        can be slow or throttled, and holding a definition that arrived in half
        a second behind a tree that takes twenty is how a working page comes to
        feel broken. So the card is painted the moment the definition lands,
        and the other two sections are dropped in as they arrive.
    */
    let view = null;
    const defsP = fetchDefinitions(word, phonetic => {
        if (!view || stale(token)) return;
        view.data[0].phonetic = phonetic;
        paint(view);
    });
    const etymP = fetchEtymology(word);
    const synP  = fetchSynonyms(word);
    [etymP, synP].forEach(pr => pr.catch(() => null));

    const entries = await defsP;
    if (stale(token)) return;

    if (entries) {
        view = { kind: 'dict', data: entries, word: entries[0].word };
        paint(view);
        fillIn(view, etymP, synP, token);
        return;
    }

    const wiki = await fetchWikipedia(word);
    if (stale(token)) return;

    if (wiki) {
        const view = { kind: 'wiki', data: wiki, word: wiki.title };
        paint(view);
        fillIn(view, etymP, synP, token);
        return;
    }

    hide(resultsEl);

    /*
        Nothing came back — but "the word is not in the dictionary" and "the
        request never got through" are different answers, and only one of them
        is about the word. Saying the first when the second happened sends the
        reader hunting for a typo that was never there.
    */
    if (networkTrouble) {
        errorEl.innerHTML =
            `Could not reach the services that answer a lookup, so there is nothing to ` +
            `show for &ldquo;${esc(word)}&rdquo; — this is not a comment on the word. ` +
            `Try again in a moment; if it keeps happening, a content or tracking blocker ` +
            `is the other usual cause, since this page has to call several other sites to ` +
            `answer a search.`;
        show(errorEl);
        return;
    }

    const suggestions = await fetchSpellingSuggestions(word);
    if (stale(token)) return;
    if (suggestions.length) {
        const chips = suggestions.map(s =>
            `<button class="synonym-chip" data-word="${esc(s)}">${esc(s)}</button>`
        ).join(' ');
        errorEl.innerHTML = `No results found for &ldquo;${esc(word)}&rdquo;. Did you mean: ${chips}`;
    } else {
        errorEl.textContent = `No results found for "${word}".`;
    }
    show(errorEl);
}

// A result from a search the reader has already moved on from.
function stale(token) { return token !== searchToken; }

// Origin and synonyms arrive later and repaint the card in place. Each is
// independent: whichever comes back is shown, and one failing costs the other
// nothing.
function fillIn(view, etymP, synP, token) {
    etymP.then(etymology => {
        view.etymology = etymology;          // recorded even if we have moved on,
        if (!stale(token)) paint(view);      // so the cached copy stays complete
    });
    synP.then(synonyms => {
        view.synonyms = synonyms;
        if (!stale(token)) paint(view);
    });
}

function paint(view) {
    lookupCache.set(view.word.toLowerCase(), view);
    if (view.kind === 'wiki') renderWiki(view.data, view.etymology, view.synonyms);
    else                      render(view.data, view.etymology, view.synonyms);
}

// ── API fetchers ──────────────────────────────────────────────────────────────

/*
    Every lookup goes through here, for two reasons.

    A request that never comes back used to leave "Looking up…" on screen for
    good, because nothing imposed a deadline. And a request that was refused —
    offline, a content blocker, a service having a bad morning — was caught and
    turned into null, which the caller reported as "No results found for X".
    That sends you hunting for a typo when the word was never the problem. A
    404 is the API answering; anything else is the API not answering, and the
    two now say different things.
*/
const LOOKUP_TIMEOUT_MS = 12000;

/*
    How long dictionaryapi.dev gets to answer before Wiktionary is used
    instead. Measured on 2026-08-27: dictionaryapi.dev connects instantly and
    then takes anywhere from 2 to 20+ seconds at the origin — nine of twelve
    words timed out at ten seconds — while Wiktionary answered in under half a
    second. Both are asked at once; this is only how long the nicer answer is
    worth waiting for.
*/
const PRIMARY_GRACE_MS = 3500;

let networkTrouble = false;

// Rising counter. Type "cat" then "dog" and the slower "cat" must not land on
// top of "dog" — anything carrying a stale token is dropped on arrival.
let searchToken = 0;

// A word already looked up costs nothing to show again, which matters because
// clicking a synonym chip and coming back is the usual way to read this page.
const lookupCache = new Map();

async function getJson(url, { budget = LOOKUP_TIMEOUT_MS, retry = true } = {}) {
    const ctrl  = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), budget);
    try {
        const res = await fetch(url, { signal: ctrl.signal });
        if (res.status === 404) return null;   // asked, and answered: no entry
        // 429 is Wikimedia saying "not so fast", 5xx is a bad moment at the
        // far end. Both are worth one more try; a 404 never is.
        if ((res.status === 429 || res.status >= 500) && retry) {
            clearTimeout(timer);
            await pause(800);
            return getJson(url, { budget, retry: false });
        }
        if (!res.ok) { networkTrouble = true; return null; }
        return await res.json();
    } catch {
        networkTrouble = true;                 // blocked, offline, or timed out
        return null;
    } finally {
        clearTimeout(timer);
    }
}

function pause(ms) { return new Promise(res => setTimeout(res, ms)); }

/*
    Two sources, asked at the same time.

    dictionaryapi.dev has the nicer material — plain prose, examples, and a
    phonetic transcription, which is the reason this page exists on a speech
    therapy site. It is also a free service running on a strained origin, and
    when it stalls it stalls for twenty seconds or more.

    Wiktionary's definition endpoint is Wikimedia infrastructure: fast and
    steady, but its definitions arrive as HTML and it carries no phonetics. So
    the good source gets a few seconds' head start and the dependable one
    catches whatever it drops. Both return the same shape, so nothing
    downstream knows or cares which one answered.
*/
async function fetchDefinitions(word, onLatePhonetic) {
    const primary = fetchDictionaryApi(word);
    const backup  = fetchWiktionaryDefs(word);

    // Swallow rejections nothing else is watching; both resolve to null.
    primary.catch(() => null);
    backup.catch(() => null);

    const early = await Promise.race([primary, pause(PRIMARY_GRACE_MS)]);
    if (early) return early;

    const fallback = await backup;
    if (!fallback) return primary;

    /*
        Wiktionary carries no phonetic transcription, and on a speech therapy
        site that is the part worth waiting for. So if the slow source does
        eventually arrive, take the transcription from it and leave the
        definitions alone — a line appearing under the headword is a small
        addition, where swapping the definitions out from under someone
        mid-sentence would not be.
    */
    primary.then(entries => {
        const phonetic = entries?.[0]?.phonetic
            || entries?.[0]?.phonetics?.find(ph => ph.text)?.text;
        if (phonetic) onLatePhonetic?.(phonetic);
    });

    return fallback;
}

async function fetchDictionaryApi(word) {
    const data = await getJson(`https://api.dictionaryapi.dev/api/v2/entries/en/${enc(word)}`);
    return Array.isArray(data) && data.length ? data : null;
}

/*
    Wiktionary returns definitions as HTML fragments, and the first entry under
    a part of speech is often an empty string — a heading with nothing under
    it. Strip the markup, drop the empties, and reshape into what render()
    already expects from the other source.
*/
async function fetchWiktionaryDefs(word) {
    const data = await getJson(
        `https://en.wiktionary.org/api/rest_v1/page/definition/${enc(word)}`
    );
    const senses = data?.en;
    if (!Array.isArray(senses) || !senses.length) return null;

    const meanings = senses.map(sense => ({
        partOfSpeech: (sense.partOfSpeech || '').toLowerCase(),
        definitions: (sense.definitions || [])
            .map(d => ({
                definition: stripHtml(d.definition),
                example: d.examples?.length ? stripHtml(d.examples[0]) : '',
            }))
            .filter(d => d.definition.length > 1),
    })).filter(m => m.definitions.length);

    if (!meanings.length) return null;
    return [{ word, phonetic: '', meanings, source: 'wiktionary' }];
}

function stripHtml(html) {
    const el = document.createElement('div');
    el.innerHTML = html || '';
    return (el.textContent || '').replace(/\s+/g, ' ').trim();
}

async function fetchWikipedia(word) {
    const data = await getJson(`https://en.wikipedia.org/api/rest_v1/page/summary/${enc(word)}`);
    if (!data || data.type === 'disambiguation') return null;
    return data;
}

// Tries Etymology Explorer API first, falls back to Wiktionary HTML parsing.
async function fetchEtymology(word) {
    try {
        const result = await fetchEtymologyExplorer(word);
        if (result) return result;
    } catch {}
    return fetchEtymologyWiktionary(word);
}

async function fetchEtymologyExplorer(word) {
    const key = word.toLowerCase();

    // Resolve word ID — use cache if available from autocomplete
    let wordId = wordIdCache[key];
    if (!wordId) {
        const data = await getJson(
            `https://api.etymologyexplorer.com/prod/autocomplete?word=${enc(word)}&language=English`
        );
        const items = data?.auto_complete_data || [];
        items.forEach(i => { wordIdCache[i.word.toLowerCase()] = i._id; });
        const exact = items.find(i => i.word.toLowerCase() === key);
        wordId = exact?._id || items[0]?._id;
    }
    if (!wordId) return null;

    const treeData = await getJson(
        `https://api.etymologyexplorer.com/prod/get_trees?ids[]=${wordId}`
    );
    if (!treeData) return null;

    // Locate words map and edges array robustly (indices 1 and 3 per API spec)
    let wordsObj = null, edges = null;
    if (Array.isArray(treeData)) {
        for (const item of treeData) {
            if (item?.words && !wordsObj) wordsObj = item.words;
            if (Array.isArray(item) && Array.isArray(item[0]) && !edges) edges = item;
        }
    }
    if (!wordsObj || !edges?.length) return null;

    return buildEtymTreeFromGraph(wordsObj, edges, word);
}

function buildEtymTreeFromGraph(wordsObj, edges, searchedWord) {
    const ids = Object.keys(wordsObj);
    if (!ids.length) return null;

    // edges: [ancestor_id, descendant_id]
    const outEdges = {}, inEdges = {};
    ids.forEach(id => { outEdges[id] = []; inEdges[id] = []; });
    edges.forEach(([from, to]) => {
        if (outEdges[from]) outEdges[from].push(to);
        if (inEdges[to])    inEdges[to].push(from);
    });

    // Root = oldest node (no ancestors)
    const rootId = ids.find(id => inEdges[id].length === 0);
    if (!rootId) return null;

    // Find the node matching the searched word (the target leaf)
    const key = searchedWord.toLowerCase();
    const targetId = ids.find(id => wordsObj[id]?.word?.toLowerCase() === key)
                  || ids.find(id => outEdges[id].length === 0); // fallback: any leaf

    // Walk the longest path from root toward targetId using BFS/DFS
    // prefer the branch that leads toward targetId where possible
    function pathTo(start, goal) {
        const visited = new Set([start]);
        const stack = [[start, [start]]];
        let best = null;
        while (stack.length) {
            const [cur, p] = stack.pop();
            if (cur === goal) return p;
            const nexts = outEdges[cur] || [];
            // prefer the child that is or leads toward goal
            for (const nxt of nexts) {
                if (!visited.has(nxt)) {
                    visited.add(nxt);
                    stack.push([nxt, [...p, nxt]]);
                    if (!best || p.length + 1 > best.length) best = [...p, nxt];
                }
            }
        }
        return best || [start];
    }

    const path = targetId ? pathTo(rootId, targetId) : (() => {
        // No target found — walk greedily to longest leaf
        const p = [rootId];
        const vis = new Set([rootId]);
        let cur = rootId;
        while (outEdges[cur]?.length && p.length < 20) {
            const next = outEdges[cur].find(n => !vis.has(n));
            if (!next) break;
            vis.add(next); p.push(next); cur = next;
        }
        return p;
    })();

    // Cognates: siblings of the final node (other children of its parent)
    const cognates = [];
    if (path.length >= 2) {
        const parentId = path[path.length - 2];
        (outEdges[parentId] || [])
            .filter(id => id !== path[path.length - 1])
            .slice(0, 2)
            .forEach(id => {
                const n = wordsObj[id];
                if (n?.language_name && n?.word)
                    cognates.push({ lang: n.language_name, word: n.word });
            });
    }

    // Ancestors = all nodes in path except the final (the searched word's node)
    const ancestors = path.slice(0, -1).map(id => {
        const n = wordsObj[id];
        return { lang: n?.language_name || '', word: n?.word || '' };
    }).filter(n => n.lang && n.word);

    if (ancestors.length < 2 && cognates.length === 0) return null;
    // Reject trees where every ancestor is plain Modern English — not a useful etymology
    const hasHistoricalAncestor = ancestors.some(a => !/^English$/i.test(a.lang));
    if (!hasHistoricalAncestor && cognates.length === 0) return null;
    return { ancestors, cognates, raw: '' };
}

// Wiktionary fallback — parses raw HTML, separates "from" chain from "cognate with"
async function fetchEtymologyWiktionary(word) {
    try {
        const data = await getJson(
            `https://en.wiktionary.org/w/api.php?action=parse&page=${enc(word)}&prop=text&format=json&origin=*`
        );
        if (!data?.parse) return null;

        const doc     = new DOMParser().parseFromString(data.parse.text['*'], 'text/html');
        const heading = doc.querySelector('[id^="Etymology"]');
        if (!heading) return null;

        const el = heading.closest('.mw-heading') || heading.closest('h2,h3,h4');
        if (!el) return null;

        let next = el.nextElementSibling;
        while (next) {
            if (next.classList.contains('mw-heading') || /^H[2-4]$/.test(next.tagName)) break;
            if (next.tagName === 'P' && next.textContent.trim().length > 10)
                return parseEtymParagraph(next);
            next = next.nextElementSibling;
        }
        return null;
    } catch { return null; }
}

function parseEtymParagraph(pElem) {
    const ancestors = [], cognates = [];
    let mode = 'ancestors', pendingLang = null;

    function walk(node) {
        for (const child of node.childNodes) {
            if (child.nodeType === 3) {
                if (/cognate\s+with|compare\s+with|akin\s+to/i.test(child.textContent))
                    mode = 'cognates';
            } else if (child.nodeType === 1) {
                if (child.matches('span.etyl')) {
                    pendingLang = child.textContent.trim();
                } else if (child.matches('i.mention') && pendingLang) {
                    const word = (child.querySelector('a') || child).textContent.trim();
                    if (word) {
                        (mode === 'cognates' ? cognates : ancestors).push({ lang: pendingLang, word });
                        pendingLang = null;
                    }
                } else { walk(child); }
            }
        }
    }
    walk(pElem);

    const raw = pElem.textContent.trim().replace(/\[\d+\]/g, '');
    return { ancestors: ancestors.reverse(), cognates, raw };
}

async function fetchSynonyms(word) {
    const data = await getJson(`https://api.datamuse.com/words?rel_syn=${enc(word)}&max=14`);
    return Array.isArray(data) ? data.map(w => w.word) : [];
}

async function fetchSpellingSuggestions(word) {
    const data = await getJson(`https://api.datamuse.com/words?sp=${enc(word)}&max=5`);
    if (!Array.isArray(data)) return [];
    return data.map(w => w.word).filter(w => w.toLowerCase() !== word.toLowerCase());
}

// ── Renderers ─────────────────────────────────────────────────────────────────

function render(entries, etymology, synonyms) {
    const entry    = entries[0];
    const phonetic = entry.phonetic || entry.phonetics?.find(p => p.text)?.text || '';

    let h = `<div class="word-header"><span class="word-title">${esc(entry.word)}</span></div>`;
    if (phonetic) h += `<div class="phonetic">${esc(phonetic)}</div>`;

    // Only worth saying when it is not the usual source.
    if (entry.source === 'wiktionary') {
        h += `<div class="wiki-source">Source: Wiktionary
                  <a class="wiki-link" href="https://en.wiktionary.org/wiki/${enc(entry.word)}"
                     target="_blank" rel="noopener noreferrer">View on Wiktionary &#8599;</a>
              </div>`;
    }

    entry.meanings.forEach((meaning, i) => {
        if (i > 0) h += '<hr class="rule">';
        h += `<div class="pos-block">
                <div class="pos-label">${esc(meaning.partOfSpeech)}</div>
                <ul class="def-list">`;
        meaning.definitions.slice(0, 6).forEach(def => {
            h += `<li>
                    <div class="def-text">${esc(def.definition)}</div>
                    ${def.example ? `<div class="def-example">${esc(def.example)}</div>` : ''}
                  </li>`;
        });
        h += `</ul></div>`;
    });

    h += sharedSections(etymology, synonyms, entry.word);
    resultsEl.innerHTML = h;
    show(resultsEl);
}

function renderWiki(wiki, etymology, synonyms) {
    const pageUrl = wiki.content_urls?.desktop?.page
        || `https://en.wikipedia.org/wiki/${enc(wiki.title)}`;
    let h = `<div class="word-header"><span class="word-title">${esc(wiki.title)}</span></div>
             <div class="wiki-source">Source: Wikipedia
                 <a class="wiki-link" href="${pageUrl}" target="_blank" rel="noopener noreferrer">View on Wikipedia &#8599;</a>
             </div>
             <hr class="rule">
             <ul class="def-list">
                 <li><div class="def-text">${esc(wiki.extract)}</div></li>
             </ul>`;
    h += sharedSections(etymology, synonyms, wiki.title);
    resultsEl.innerHTML = h;
    show(resultsEl);
}

function sharedSections(etymology, synonyms, word) {
    let h = '';

    if (etymology) {
        const etymHtml = renderEtymTree(etymology, word);
        if (etymHtml) h += `<hr class="rule"><div class="section-label">Origin</div>${etymHtml}`;
    }

    if (synonyms?.length) {
        const chips = synonyms.map(s =>
            `<button class="synonym-chip" data-word="${esc(s)}">${esc(s)}</button>`
        ).join('');
        h += `<hr class="rule">
              <div class="section-label">Synonyms</div>
              <div class="synonym-chips">${chips}</div>`;
    }

    return h;
}

// ── Etymology tree ─────────────────────────────────────────────────────────────

function renderEtymTree(etym, word) {
    if (!etym) return '';
    const { ancestors, cognates, raw } = etym;

    if (ancestors.length < 2 && cognates.length === 0) return '';

    // Branching: root node → siblings row (last ancestor + cognates) → word
    if (cognates.length > 0 && ancestors.length >= 1) {
        const root    = ancestors[0];
        const lastAnc = ancestors[ancestors.length - 1];
        const sibs    = [lastAnc, ...cognates.slice(0, 2)];

        let h = '<div class="etym-tree">';
        h += etymNodeH(root);
        h += `<div class="etym-connector"></div>`;
        h += `<div class="etym-siblings-row">`;
        sibs.forEach(n => {
            h += `<div class="etym-sib-node">
                      <span class="etym-lang">${esc(n.lang.toUpperCase())}</span>
                      <span class="etym-word">${esc(n.word)}</span>
                  </div>`;
        });
        h += `</div>`;
        h += etymArrowH();
        h += `<div class="etym-final">${esc(word)}</div></div>`;
        return h;
    }

    // Linear chain
    let h = '<div class="etym-tree">';
    ancestors.forEach((n, i) => {
        h += etymNodeH(n);
        if (i < ancestors.length - 1) h += etymArrowH();
    });
    h += etymArrowH();
    h += `<div class="etym-final">${esc(word)}</div></div>`;
    return h;
}

function etymNodeH(n) {
    return `<div class="etym-node">
                <span class="etym-lang">${esc(n.lang.toUpperCase())}</span>
                <span class="etym-word">${esc(n.word)}</span>
            </div>`;
}
function etymArrowH() { return `<div class="etym-arrow"></div>`; }

// ── Helpers ───────────────────────────────────────────────────────────────────

function searchWord(word) {
    searchInput.value = word;
    clearBtn.classList.remove('hidden');
    window.scrollTo({ top: 0, behavior: 'smooth' });
    search();
}

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function enc(s)   { return encodeURIComponent(s); }
function esc(s)   { return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
