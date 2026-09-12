"""Audit complete delivered scores for calmness and unintended musical surprises."""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]


def review(entry: dict) -> dict:
    """Assess actual audio and retain a content-addressed automated review."""
    path = ROOT / entry['music']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    evidence = ROOT/'verification'/f"music_review_{entry['id']}.json"
    if evidence.exists():
        report = json.loads(evidence.read_text())
        if report['sha256'] == digest:
            return report
    prompt = 'Listen to this complete instrumental meditation score. Describe actual instrumentation and character. Identify any voices, rhythmic percussion, harsh attacks, sudden startling changes, or ominous tension. The goal is calming energy, not merely slow tempo. Be candid, do not infer from filename. Return JSON with description, voices_detected (boolean), rhythmic_percussion_detected (boolean), harsh_attacks_detected (boolean), startling_transitions_detected (boolean), ominous_tension_detected (boolean), suitability_notes, and any_problem_timestamps.'
    if entry.get('tempo_bpm') == 90:
        prompt += ' This score intentionally uses a constant soft 90 BPM electronic trance rhythm. Assess whether that pulse stays gentle and even, and whether the timbres sound electronic and distinct from acoustic ambient music.'
    response = requests.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent', headers={'x-goog-api-key': os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')}, json={'contents':[{'parts':[{'text':prompt},{'inline_data':{'mime_type':'audio/ogg','data':base64.b64encode(path.read_bytes()).decode()}}]}], 'generationConfig':{'responseMimeType':'application/json'}}, timeout=240)
    if not response.ok:
        raise RuntimeError(f'Audio review HTTP {response.status_code}')
    parts = response.json()['candidates'][0]['content']['parts']
    result = json.loads(''.join(p.get('text','') for p in parts))
    report = dict(id=entry['id'],sha256=digest,reviewer='gemini-3.8-flash',review=result)
    evidence.write_text(json.dumps(report,indent=2)+'\n')
    print(entry['id']+': '+json.dumps(result),flush=True)
    return report


def main() -> None:
    """Review one ready delivery or every completed score with bounded concurrency."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--one')
    args = parser.parse_args()
    entries = json.loads((ROOT/'experiences/catalog.json').read_text())[1:]
    if args.one:
        review(next(e for e in entries if e['id'] == args.one))
        return
    with ThreadPoolExecutor(max_workers=2) as pool:
        reports = list(pool.map(review,entries))
    (ROOT/'verification/music_suite_audition.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__ == '__main__':
    main()
