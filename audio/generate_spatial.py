"""Generate and master resumable Lyria water loops and spatial particle cues."""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

import numpy as np
import requests
from scipy.io import wavfile

from audio.generate_music import probe

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / 'audio/masters/spatial'
STAGE = ROOT / 'audio/masters/spatial/delivery'
MODEL = 'lyria-3-clip-preview'
ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions'
RATE = 48000


def digest(path: Path) -> str:
    """Hash complete artifacts for resume and provenance checks."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def master_clip(source: Path, item: dict) -> dict:
    """Downmix, soften and shape a sample-exact delivery without altering its source."""
    lowpass = 1100 if item['kind'] == 'water' else 2300
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-ac', '1', '-ar', str(RATE),
                          '-af', f'highpass=f=90,lowpass=f={lowpass}', '-f', 'f32le', '-'], check=True, capture_output=True).stdout
    samples = np.frombuffer(raw, dtype='<f4').astype(float)
    count = round(item['seconds'] * RATE)
    if item['kind'] == 'water':
        overlap = RATE * 2
        required = count + overlap + RATE
        if len(samples) < required:
            assert required / len(samples) < 1.15, 'Water master too short for a gentle stretch'
            samples = np.interp(np.linspace(0, len(samples) - 1, required), np.arange(len(samples)), samples)
        part = samples[RATE:RATE + count + overlap]
        w = np.linspace(0, 1, overlap)
        w = w * w * (3 - 2 * w)
        samples = np.concatenate([part[overlap:count], part[count:] * (1 - w) + part[:overlap] * w])
        gain = min(0.030 / max(np.sqrt(np.mean(samples ** 2)), 1e-9), 0.14 / max(np.max(np.abs(samples)), 1e-9))
    else:
        # Choose a sustained section, avoiding quiet lead-ins and large transients.
        candidates = []
        for offset in range(RATE, len(samples) - count, RATE // 2):
            part = samples[offset:offset + count]
            rms = np.sqrt(np.mean(part ** 2))
            if rms > 0.003:
                blocks = np.sqrt(np.mean(part[:count // 4800 * 4800].reshape(-1, 4800) ** 2, axis=1))
                candidates.append((float(np.std(blocks) / rms + np.max(np.abs(part)) / rms * 0.05), offset))
        assert candidates, 'No usable non-silent cue section'
        offset = min(candidates)[1]
        samples = samples[offset:offset + count].copy()
        samples *= np.sin(np.linspace(0, np.pi, count)) ** 3
        gain = 0.085 / max(np.max(np.abs(samples)), 1e-9)
    samples *= gain
    pcm = np.round(samples * 32767).astype(np.int16)
    assert len(pcm) == count and np.sqrt(np.mean(pcm.astype(float) ** 2)) > 20
    assert np.max(np.abs(pcm.astype(float))) <= 4600
    if item['kind'] == 'water':
        assert abs(int(pcm[0]) - int(pcm[-1])) < 200, 'Loop seam discontinuity'
    else:
        assert pcm[0] == pcm[-1] == 0
    target = STAGE / item['file']
    temp = target.with_suffix('.pending.wav')
    wavfile.write(temp, RATE, pcm)
    read_rate, decoded = wavfile.read(temp)
    assert read_rate == RATE and np.array_equal(decoded, pcm)
    temp.replace(target)
    meter = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(target), '-af', 'loudnorm=I=-30:print_format=json', '-f', 'null', '-'], capture_output=True, text=True, check=True)
    loudness = json.JSONDecoder().raw_decode(meter.stderr[meter.stderr.rfind('{'):])[0]
    return {'file': item['file'], 'sha256': digest(target), 'bytes': target.stat().st_size,
            'seconds': item['seconds'], 'sample_rate': RATE, 'samples': count, 'channels': 1,
            'seam_delta': abs(int(pcm[0]) - int(pcm[-1])), 'loudness': loudness}


def generate(item: dict) -> dict:
    """Retain a validated original response, then stage its mastered delivery."""
    evidence_path = MASTER / (item['id'] + '.json')
    evidence = json.loads(evidence_path.read_text()) if evidence_path.exists() else None
    if evidence and evidence.get('prompt') == item['prompt'] and digest(MASTER / evidence['master']) == evidence['master_sha256']:
        source = MASTER / evidence['master']
        probe(source)
        status = 'skipped'
    else:
        key = os.getenv('GEMINI_API_KEY') or os.getenv('GOOGLE_API_KEY')
        if not key:
            raise RuntimeError('Lyria credential unavailable')
        print('Generating ' + item['id'], flush=True)
        for attempt in range(4):
            response = requests.post(ENDPOINT, headers={'x-goog-api-key': key}, json={'model': MODEL, 'input': item['prompt']}, timeout=600)
            if response.status_code not in (408, 409, 429, 500, 502, 503, 504):
                break
            print(f'{item["id"]}: transient HTTP {response.status_code}', flush=True)
            time.sleep(min(30, 2 ** (attempt + 2)))
        if not response.ok:
            raise RuntimeError(f'Lyria HTTP {response.status_code}')
        payload = response.json()
        blocks = [b for step in payload.get('steps', []) if step.get('type') == 'model_output' for b in step.get('content', [])]
        audio = [b for b in blocks if b.get('type') == 'audio']
        assert len(audio) == 1, 'Expected one generated audio clip'
        data = base64.b64decode(audio[0]['data'])
        source = MASTER / (item['id'] + ('.wav' if data[:4] == b'RIFF' else '.mp3'))
        pending = source.with_suffix(source.suffix + '.pending')
        pending.write_bytes(data)
        details = probe(pending)
        assert float(details['format']['duration']) >= 24
        pending.replace(source)
        evidence = dict(item, model=MODEL, endpoint=ENDPOINT, interaction_id=payload.get('id'),
                        master=source.name, master_sha256=digest(source), source_probe=details,
                        response_text=[b.get('text', '') for b in blocks if b.get('type') == 'text'])
        status = 'generated'
    evidence['delivery'] = master_clip(source, item)
    temp = evidence_path.with_suffix('.json.pending')
    temp.write_text(json.dumps(evidence, indent=2) + '\n')
    temp.replace(evidence_path)
    print(f'{item["id"]}: {status}, delivery validated', flush=True)
    return dict(id=item['id'], status=status, master_bytes=source.stat().st_size, delivery=evidence['delivery'])


def main() -> None:
    """Generate one initial proof or a bounded batch, installing only a complete set."""
    parser = argparse.ArgumentParser()
    parser.add_argument('selection', nargs='?', default='all')
    args = parser.parse_args()
    catalog = json.loads((ROOT / 'audio/spatial_catalog.json').read_text())
    assert len(catalog) == len({i['id'] for i in catalog}) == len({i['file'] for i in catalog}) == 8
    MASTER.mkdir(parents=True, exist_ok=True)
    STAGE.mkdir(exist_ok=True)
    selected = catalog if args.selection == 'all' else [i for i in catalog if i['id'] == args.selection]
    assert selected
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(generate, selected))
    if args.selection == 'all':
        for item in catalog:
            target = ROOT / 'assets/audio' / item['file']
            pending = target.with_suffix('.pending.wav')
            pending.write_bytes((STAGE / item['file']).read_bytes())
            pending.replace(target)
        (ROOT / 'audio/spatial_provenance.json').write_text(json.dumps({'model': MODEL, 'catalog': results}, indent=2) + '\n')
    print(json.dumps({'generated': sum(r['status'] == 'generated' for r in results), 'skipped': sum(r['status'] == 'skipped' for r in results), 'failed': 0,
                      'master_bytes': sum(r['master_bytes'] for r in results), 'delivery_bytes': sum(r['delivery']['bytes'] for r in results)}), flush=True)


if __name__ == '__main__':
    main()
