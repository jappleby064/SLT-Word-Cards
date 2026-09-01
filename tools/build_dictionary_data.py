#!/usr/bin/env python3
"""
Build the local dictionary the website reads, so a lookup does not depend on
somebody else's server being up.

Two sources, both redistributable:

  WordNet 3.0 (Princeton)      definitions, part of speech, examples, synonyms
  ipa-dict en_UK (MIT)         British pronunciations, already in IPA

Output is a set of sharded JSON files under dict-data/. A word is hashed to one
of SHARDS buckets, so the browser fetches exactly one small file per lookup and
never an index. The same hash is implemented in dictionary.js; change one and
you must change the other.

Usage:
    python3 tools/build_dictionary_data.py <wordnet-dir> <en_UK.txt> <out-dir>

The two inputs are not kept in this repository — they are large, they never
change, and this script is the record of where they came from.
"""

import json
import os
import re
import sys
from collections import defaultdict

SHARDS = 1024

POS_NAME = {'n': 'noun', 'v': 'verb', 'a': 'adjective', 's': 'adjective', 'r': 'adverb'}

# Order senses the way a dictionary does rather than the way WordNet stores them.
POS_ORDER = ['noun', 'verb', 'adjective', 'adverb']

MAX_SENSES_PER_POS = 6
MAX_SYNONYMS = 12


def fnv1a(text):
    """32-bit FNV-1a. Mirrored in dictionary.js — keep the two in step."""
    h = 0x811c9dc5
    for ch in text:
        h ^= ord(ch) & 0xff
        h = (h * 0x01000193) & 0xffffffff
    return h


def parse_data_file(path):
    """offset -> {pos, words, definition, examples} from a WordNet data.* file."""
    synsets = {}
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('  '):        # licence header
                continue
            fields, _, gloss = line.partition('|')
            parts = fields.split()
            if len(parts) < 4:
                continue
            offset, _lex, ss_type = parts[0], parts[1], parts[2]
            try:
                w_cnt = int(parts[3], 16)
            except ValueError:
                continue

            words = []
            i = 4
            for _ in range(w_cnt):
                if i >= len(parts):
                    break
                # Adjective heads carry a marker: "quick(p)" — not part of the word.
                words.append(re.sub(r'\(.*?\)$', '', parts[i]).replace('_', ' '))
                i += 2                        # skip the lex_id that follows each word

            gloss = gloss.strip()
            # A gloss is "definition; \"an example\"; \"another\"".
            examples = re.findall(r'"([^"]+)"', gloss)
            definition = re.split(r';\s*"', gloss)[0].strip().rstrip(';').strip()

            synsets[offset] = {
                'pos': POS_NAME.get(ss_type, ss_type),
                'words': words,
                'definition': definition,
                'examples': examples,
            }
    return synsets


def parse_index_file(path):
    """lemma -> [synset offsets], in WordNet's own sense order (commonest first)."""
    index = defaultdict(list)
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            if line.startswith('  '):
                continue
            parts = line.split()
            if len(parts) < 6:
                continue
            lemma = parts[0].replace('_', ' ')
            try:
                p_cnt = int(parts[3])
            except ValueError:
                continue
            # lemma pos synset_cnt p_cnt [ptr_symbol...] sense_cnt tagsense_cnt offsets...
            #   0     1        2        3    4 .. 4+p_cnt-1    4+p_cnt    5+p_cnt   6+p_cnt
            offsets = parts[6 + p_cnt:]
            index[lemma].extend(offsets)
    return index


def load_pronunciations(path):
    """word -> IPA, first pronunciation only, slashes stripped."""
    out = {}
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            word, tab, rest = line.partition('\t')
            if not tab:
                continue
            first = rest.split(',')[0].strip()
            first = first.strip('/').strip()
            # Slashes back on, so it matches how the online sources hand over a
            # transcription and the renderer needs no special case.
            if first and word not in out:
                out[word.strip()] = f'/{first}/'
    return out


def build(wordnet_dir, ipa_path, out_dir):
    synsets = {}
    index = defaultdict(list)
    for pos in ('noun', 'verb', 'adj', 'adv'):
        synsets[pos] = parse_data_file(os.path.join(wordnet_dir, f'data.{pos}'))
        for lemma, offsets in parse_index_file(os.path.join(wordnet_dir, f'index.{pos}')).items():
            index[lemma].extend((pos, off) for off in offsets)

    pron = load_pronunciations(ipa_path)

    shards = defaultdict(dict)
    words_out = 0

    for lemma, refs in index.items():
        by_pos = defaultdict(list)
        synonyms = []

        for pos_file, offset in refs:
            syn = synsets[pos_file].get(offset)
            if not syn or not syn['definition']:
                continue
            entry = {'d': syn['definition']}
            if syn['examples']:
                entry['x'] = syn['examples'][0]
            by_pos[syn['pos']].append(entry)
            for w in syn['words']:
                if w.lower() != lemma.lower() and w not in synonyms:
                    synonyms.append(w)

        if not by_pos:
            continue

        meanings = []
        for pos in POS_ORDER:
            if by_pos.get(pos):
                meanings.append({'p': pos, 's': by_pos[pos][:MAX_SENSES_PER_POS]})

        record = {'m': meanings}
        ipa = pron.get(lemma.lower())
        if ipa:
            record['i'] = ipa
        if synonyms:
            record['y'] = synonyms[:MAX_SYNONYMS]

        shards[fnv1a(lemma.lower()) % SHARDS][lemma.lower()] = record
        words_out += 1

    # Words with a pronunciation but no WordNet entry still deserve their IPA:
    # inflections ("running"), names, and anything WordNet simply lacks.
    ipa_only = 0
    for word, ipa in pron.items():
        bucket = fnv1a(word) % SHARDS
        if word in shards[bucket]:
            continue
        if not re.fullmatch(r"[a-z][a-z'-]*", word):
            continue
        shards[bucket][word] = {'i': ipa}
        ipa_only += 1

    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith('.json'):
            os.remove(os.path.join(out_dir, old))

    total = 0
    largest = 0
    for bucket in range(SHARDS):
        path = os.path.join(out_dir, f'{bucket}.json')
        blob = json.dumps(shards.get(bucket, {}), ensure_ascii=False, separators=(',', ':'))
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(blob)
        size = len(blob.encode('utf-8'))
        total += size
        largest = max(largest, size)

    print(f'words with definitions : {words_out:,}')
    print(f'words with IPA only    : {ipa_only:,}')
    print(f'shards                 : {SHARDS}')
    print(f'total                  : {total/1048576:.1f} MB')
    print(f'largest shard          : {largest/1024:.0f} KB')
    print(f'average shard          : {total/SHARDS/1024:.0f} KB')


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2], sys.argv[3])
