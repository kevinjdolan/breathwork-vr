"""Audit generated ambience with audio understanding, retaining non-secret evidence."""

import base64
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]


def review(item: dict) -> dict:
    """Listen for voices, percussion and harsh transients in one delivered cue."""
    path = ROOT / 'audio/masters/spatial/delivery' / item['file']
    prompt = 'Listen to the actual audio. Describe it candidly for a tranquil meditation. This is a quiet ' + item['kind'] + ' texture, played well below the music bed. Identify any voices, rhythmic percussion, or sharp attacks. Return JSON with description, voices_detected (boolean), rhythmic_percussion_detected (boolean), harsh_attacks_detected (boolean), and suitability_notes. Do not infer sound from the filename.'
    result = requests.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
                           headers={'x-goog-api-key': os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')},
                           json={'contents': [{'parts': [{'text': prompt}, {'inline_data': {'mime_type': 'audio/wav', 'data': base64.b64encode(path.read_bytes()).decode()}}]}],
                                 'generationConfig': {'responseMimeType': 'application/json'}}, timeout=120)
    if not result.ok:
        raise RuntimeError(f'Audio review HTTP {result.status_code}')
    parts = result.json()['candidates'][0]['content']['parts']
    report = json.loads(''.join(p.get('text', '') for p in parts))
    print(item['id'] + ': ' + json.dumps(report), flush=True)
    return {'id': item['id'], 'review': report}


def main() -> None:
    """Save an automated auditory review of every Lyria delivery."""
    catalog = json.loads((ROOT / 'audio/spatial_catalog.json').read_text())
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(review, catalog))
    (ROOT / 'verification/lyria_spatial_audition.json').write_text(json.dumps({'reviewer': 'gemini-3.8-flash', 'results': results}, indent=2) + '\n')


if __name__ == '__main__':
    main()
