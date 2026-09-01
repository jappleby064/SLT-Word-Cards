# Local dictionary data

Generated files. Do not edit them by hand — run
`tools/build_dictionary_data.py` instead, which documents its two inputs.

`<n>.json` is one shard of the word list: a word is hashed with FNV-1a and
taken modulo 1024, and the browser fetches only the shard its word lands in.
`dictionary.js` implements the same hash; changing the shard count or the hash
in one place means changing it in the other.

Each record is kept short because it travels over the wire:

    "father": {
      "i": "/fˈɑːðɐ/",                      pronunciation, British English
      "m": [                                meanings, in dictionary order
        { "p": "noun", "s": [               part of speech, then senses
          { "d": "a male parent",           definition
            "x": "his father was born…" }   example, where there is one
        ]}
      ],
      "y": ["male parent", "begetter"]      synonyms
    }

Some records carry only `i` — a word with a known pronunciation that WordNet
does not define. Those fall through to the online sources, which may do better.

## Sources and licences

Definitions, parts of speech, examples and synonyms come from **WordNet 3.0**,
Copyright 2006 by Princeton University. Its licence is in
`WORDNET-LICENSE.txt` and requires that notice to accompany all copies,
including this one.

Pronunciations come from **ipa-dict** (`en_UK`), MIT licensed:
https://github.com/open-dict-data/ipa-dict

Both are credited on the dictionary page itself.
