#!/usr/bin/env python3
"""Fetch missing IPA audio from Wikimedia Commons and convert to MP3."""

import os, subprocess, urllib.request, urllib.error, time

AUDIO_DIR = os.path.join(os.path.dirname(__file__), "audio")

# symbol -> (slug for local mp3, wikimedia commons filename without extension)
MISSING = {
    # Plosives
    'ʈ': ('retroflex_plosive_vl',     'Voiceless_retroflex_plosive'),
    'ɖ': ('retroflex_plosive_vd',     'Voiced_retroflex_plosive'),
    'c': ('palatal_plosive_vl',       'Voiceless_palatal_plosive'),
    'ɟ': ('palatal_plosive_vd',       'Voiced_palatal_plosive'),
    'q': ('uvular_plosive_vl',        'Voiceless_uvular_plosive'),
    'ɢ': ('uvular_plosive_vd',        'Voiced_uvular_plosive'),
    'ʔ': ('glottal_stop',             'Glottal_stop'),
    # Nasals
    'ɱ': ('labiodental_nasal',        'Labiodental_nasal'),
    'ɳ': ('retroflex_nasal',          'Retroflex_nasal'),
    'ɲ': ('palatal_nasal',            'Palatal_nasal'),
    'ɴ': ('uvular_nasal',             'Uvular_nasal'),
    # Trills
    'ʙ': ('bilabial_trill',           'Bilabial_trill'),
    'ʀ': ('uvular_trill',             'Uvular_trill'),
    # Taps / Flaps
    'ⱱ': ('labiodental_flap',         'Labiodental_flap'),
    'ɾ': ('alveolar_tap',             'Alveolar_tap'),
    'ɽ': ('retroflex_flap',           'Retroflex_flap'),
    # Fricatives
    'ɸ': ('bilabial_fric_vl',         'Voiceless_bilabial_fricative'),
    'β': ('bilabial_fric_vd',         'Voiced_bilabial_fricative'),
    'ʂ': ('retroflex_fric_vl',        'Voiceless_retroflex_sibilant'),
    'ʐ': ('retroflex_fric_vd',        'Voiced_retroflex_sibilant'),
    'ç': ('palatal_fric_vl',          'Voiceless_palatal_fricative'),
    'ʝ': ('palatal_fric_vd',          'Voiced_palatal_fricative'),
    'x': ('velar_fric_vl',            'Voiceless_velar_fricative'),
    'ɣ': ('velar_fric_vd',            'Voiced_velar_fricative'),
    'χ': ('uvular_fric_vl',           'Voiceless_uvular_fricative'),
    'ʁ': ('uvular_fric_vd',           'Voiced_uvular_fricative'),
    'ħ': ('pharyngeal_fric_vl',       'Voiceless_pharyngeal_fricative'),
    'ʕ': ('pharyngeal_fric_vd',       'Voiced_pharyngeal_fricative'),
    'ɦ': ('glottal_fric_vd',          'Voiced_glottal_fricative'),
    # Lateral fricatives
    'ɬ': ('alveolar_lat_fric_vl',     'Voiceless_alveolar_lateral_fricative'),
    'ɮ': ('alveolar_lat_fric_vd',     'Voiced_alveolar_lateral_fricative'),
    # Approximants
    'ʋ': ('labiodental_approx',       'Labiodental_approximant'),
    'ɻ': ('retroflex_approx',         'Retroflex_approximant'),
    'ɰ': ('velar_approx',             'Voiced_velar_approximant'),
    # Lateral approximants
    'ɭ': ('retroflex_lat_approx',     'Retroflex_lateral_approximant'),
    'ʎ': ('palatal_lat_approx',       'Palatal_lateral_approximant'),
    'ʟ': ('velar_lat_approx',         'Velar_lateral_approximant'),
    # Clicks
    'ʘ': ('bilabial_click',           'Bilabial_click'),
    'ǀ': ('dental_click',             'Dental_click'),
    'ǃ': ('alveolar_click',           'Postalveolar_click'),
    'ǂ': ('palatoalveolar_click',     'Palatoalveolar_click'),
    'ǁ': ('alveolar_lat_click',       'Alveolar_lateral_click'),
    # Implosives
    'ɓ': ('bilabial_implosive',       'Voiced_bilabial_implosive'),
    'ɗ': ('alveolar_implosive',       'Voiced_alveolar_implosive'),
    'ʄ': ('palatal_implosive',        'Voiced_palatal_implosive'),
    'ɠ': ('velar_implosive',          'Voiced_velar_implosive'),
    'ʛ': ('uvular_implosive',         'Voiced_uvular_implosive'),
    # Other symbols
    'ʍ': ('labial_velar_fric_vl',     'Voiceless_labial%E2%80%93velar_fricative'),
    'ɥ': ('labial_palatal_approx',    'Voiced_labial-palatal_approximant'),
    'ʜ': ('epiglottal_fric_vl',       'Voiceless_epiglottal_fricative'),
    'ʢ': ('epiglottal_fric_vd',       'Voiced_epiglottal_fricative'),
    'ʡ': ('epiglottal_stop',          'Epiglottal_stop'),
    'ɕ': ('alveolo_palatal_fric_vl',  'Voiceless_alveolo-palatal_sibilant'),
    'ʑ': ('alveolo_palatal_fric_vd',  'Voiced_alveolo-palatal_sibilant'),
    # ɺ and ɧ have no Wikimedia recordings; ejectives (ʼ pʼ tʼ kʼ sʼ) are omitted likewise
    # Vowels
    'ɨ': ('close_central_unrounded',  'Close_central_unrounded_vowel'),
    'ʉ': ('close_central_rounded',    'Close_central_rounded_vowel'),
    'ɯ': ('close_back_unrounded',     'Close_back_unrounded_vowel'),
    'ʏ': ('nearclose_nearfront_rounded', 'Near-close_near-front_rounded_vowel'),
    'ɘ': ('closemid_central_unrounded', 'Close-mid_central_unrounded_vowel'),
    'ɵ': ('closemid_central_rounded', 'Close-mid_central_rounded_vowel'),
    'ɤ': ('closemid_back_unrounded',  'Close-mid_back_unrounded_vowel'),
    'œ': ('openmid_front_rounded',    'Open-mid_front_rounded_vowel'),
    'ɞ': ('openmid_central_rounded',  'Open-mid_central_rounded_vowel'),
    'ɶ': ('open_front_rounded',       'Open_front_rounded_vowel'),
}

def fetch_and_convert(sym, slug, wiki_name):
    mp3_path = os.path.join(AUDIO_DIR, slug + '.mp3')
    if os.path.exists(mp3_path):
        print(f"  already exists: {slug}.mp3")
        return True

    # try .ogg, then .oga as fallback
    ogg_url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{wiki_name}.ogg"
    ogg_tmp = os.path.join(AUDIO_DIR, slug + '.ogg')

    for attempt in range(4):
        try:
            req = urllib.request.Request(ogg_url, headers={'User-Agent': 'Mozilla/5.0 IPA-audio-fetcher/1.0'})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
            if len(data) < 1000:
                print(f"  SKIP {sym} ({wiki_name}): response too small ({len(data)} bytes)")
                return False
            with open(ogg_tmp, 'wb') as f:
                f.write(data)
            break
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 3:
                wait = 10 * (attempt + 1)
                print(f"  rate-limited, waiting {wait}s ({sym})…")
                time.sleep(wait)
            else:
                print(f"  FAIL {sym} ({wiki_name}): {e}")
                return False
        except Exception as e:
            print(f"  FAIL {sym} ({wiki_name}): {e}")
            return False

    result = subprocess.run(
        ['ffmpeg', '-y', '-i', ogg_tmp, '-codec:a', 'libmp3lame', '-q:a', '4', mp3_path],
        capture_output=True
    )
    os.remove(ogg_tmp)
    if result.returncode != 0:
        print(f"  FAIL ffmpeg for {sym}: {result.stderr.decode()[-200:]}")
        return False

    print(f"  OK  {sym}  →  {slug}.mp3")
    return True

if __name__ == '__main__':
    os.makedirs(AUDIO_DIR, exist_ok=True)
    ok, fail = [], []
    for sym, (slug, wiki) in MISSING.items():
        success = fetch_and_convert(sym, slug, wiki)
        (ok if success else fail).append(sym)
        time.sleep(2.5)

    print(f"\nDone: {len(ok)} fetched, {len(fail)} failed")
    if fail:
        print("Failed:", ' '.join(fail))

    # Print JS AUDIO additions for successful ones
    print("\nAdd to AUDIO object:")
    for sym, (slug, _) in MISSING.items():
        if sym in ok:
            print(f"  '{sym}': '{slug}',")
