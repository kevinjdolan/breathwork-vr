"""Generate and master seven distinct resumable eight-minute Lyria scores."""

from concurrent.futures import ThreadPoolExecutor
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

import numpy as np
import requests
from scipy.io import wavfile

from audio.generate_music import ENDPOINT, MODEL, probe
from audio.stitch_music import RATE, decode, run

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / 'audio/masters/suite'


def movement(entry: dict, index: int, seconds: int) -> tuple[Path, dict]:
    """Persist an untouched original movement with verifiable non-secret evidence."""
    identifier = f"{entry['id']}_{index}"
    evidence_path = MASTERS / f'{identifier}.json'
    stage = ['Establish a quiet spacious welcome, gradually open into a sustained texture.', 'Deepen gently into richer consonant overtones, keep intensity restrained and stable.', 'Gently resolve and thin into stillness, with a long soft final decay.'][index]
    prompt = f"Create {seconds} seconds of original instrumental meditation music. {entry['music_direction']} {stage} No vocals, speech, drums, beat, climaxes, sudden attacks, harsh high frequencies, ominous tension, or dramatic tempo changes. The listener is lying still and breathing slowly. Calming energy throughout. Very soft edges and deep continuous musical development. End naturally; preserve ample reverb decay."
    if evidence_path.exists():
        evidence = json.loads(evidence_path.read_text())
        path = MASTERS / evidence['file']
        if evidence['prompt'] == prompt and path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == evidence['sha256']:
            probe(path)
            print(f'Skipped valid master {identifier}', flush=True)
            return path, evidence
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        raise RuntimeError('Lyria credential unavailable')
    print(f'Generating {identifier}', flush=True)
    for attempt in range(4):
        response = requests.post(ENDPOINT, headers={'x-goog-api-key': key}, json={'model': MODEL, 'input': prompt, 'response_format': {'type': 'audio'}}, timeout=600)
        if response.status_code not in (408,409,429,500,502,503,504):
            break
        time.sleep(min(30, 2 ** (attempt + 2)))
    if not response.ok:
        message = response.json().get('error', {}).get('message', 'No error detail')[:300]
        raise RuntimeError(f'Lyria HTTP {response.status_code} for {identifier}: {message}')
    payload = response.json()
    blocks = [b for s in payload.get('steps',[]) if s.get('type') == 'model_output' for b in s.get('content',[])]
    audio = [b for b in blocks if b.get('type') == 'audio']
    if len(audio) != 1:
        raise RuntimeError(f'Expected one audio block for {identifier}')
    raw = base64.b64decode(audio[0]['data'])
    path = MASTERS / (identifier + ('.wav' if raw[:4] == b'RIFF' else '.mp3'))
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_bytes(raw)
    details = probe(temporary)
    if float(details['format']['duration']) < 110:
        raise RuntimeError(f'Unexpected short master {identifier}; retained temporary audio')
    temporary.replace(path)
    evidence = dict(id=identifier, model=MODEL, endpoint=ENDPOINT, interaction_id=payload.get('id'), prompt=prompt, file=path.name, sha256=hashlib.sha256(raw).hexdigest(), probe=details, response_text=[b.get('text','') for b in blocks if b.get('type') == 'text'])
    evidence_path.write_text(json.dumps(evidence, indent=2)+'\n')
    print(f'Saved {identifier}: {details["format"]["duration"]} seconds', flush=True)
    return path, evidence


def score(entry: dict) -> dict:
    """Assemble three musical movements and verify a sample-exact delivery."""
    if entry.get('tempo_bpm') == 90 and entry['id'] == 'prismatic_sanctuary':
        from audio.generate_prismatic_trance import score as trance_score
        return trance_score(entry)
    report_path = MASTERS / f'{entry["id"]}_delivery.json'
    target = ROOT / entry['music']
    sources = [movement(entry, index, seconds) for index, seconds in enumerate([178,178,144])]
    if report_path.exists() and target.exists():
        report = json.loads(report_path.read_text())
        if hashlib.sha256(target.read_bytes()).hexdigest() == report['sha256'] and [s[1]['sha256'] for s in sources] == [s['sha256'] for s in report['sources']]:
            print(f'Skipped validated delivery {entry["id"]}', flush=True)
            return report
    mix = np.zeros((480 * RATE, 2), dtype=np.float32)
    ramp = np.linspace(0, np.pi / 2, 10 * RATE)
    for index, (path, evidence) in enumerate(sources):
        start, seconds = [(0,178),(168,178),(336,144)][index]
        samples = decode(path, seconds)
        if index:
            samples[:len(ramp)] *= np.sin(ramp)[:,None]
        if index < 2:
            samples[-len(ramp):] *= np.cos(ramp)[:,None]
        mix[start*RATE:start*RATE+len(samples)] += samples
    mix[:12*RATE] *= np.linspace(0,1,12*RATE)[:,None]
    mix[-6*RATE:] *= np.linspace(1,0,6*RATE)[:,None]
    with tempfile.TemporaryDirectory() as temp:
        wav = Path(temp)/'mix.wav'
        wavfile.write(wav, RATE, mix)
        first = run(['ffmpeg','-hide_banner','-i',str(wav),'-af','loudnorm=I=-20:TP=-2:LRA=10:print_format=json','-f','null','-'])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
        normalization = f"loudnorm=I=-20:TP=-2:LRA=10:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true,lowpass=f=7000"
        pending = target.with_suffix('.pending.ogg')
        normalized = Path(temp)/'normalized.wav'
        run(['ffmpeg','-v','error','-y','-i',str(wav),'-af',normalization,'-ar',str(RATE),'-c:a','pcm_s24le','-t','480',str(normalized)])
        run(['oggenc','-Q','-q','5','-o',str(pending),str(normalized)])
        details = probe(pending)
        if abs(float(details['format']['duration']) - 480) > .01:
            raise RuntimeError('Delivery length mismatch')
        pending.replace(target)
    report = dict(id=entry['id'],title=entry['title'],artist=entry['artist'],model=MODEL,duration=480,file=entry['music'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),delivery_bytes=target.stat().st_size,target_lufs=-20,transition_starts=[168,336],crossfade_seconds=10,sources=[s[1] for s in sources])
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print(f'Mastered {entry["id"]}: 480 seconds',flush=True)
    return report


def main() -> None:
    """Validate the authored catalog and run a bounded resumable batch."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--one')
    args = parser.parse_args()
    entries = json.loads((ROOT/'experiences/catalog.json').read_text())[1:]
    assert len(entries) == 7 and len({e['id'] for e in entries}) == 7
    MASTERS.mkdir(parents=True,exist_ok=True)
    if args.one:
        score(next(e for e in entries if e['id'] == args.one))
        return
    with ThreadPoolExecutor(max_workers=2) as pool:
        reports = list(pool.map(score, entries))
    for report in reports:
        for source in report['sources']:
            source['probe']['format']['filename'] = source['file']
    output = dict(tracks=reports,generated_tracks=7,master_count=21,failed=0,master_bytes=sum((MASTERS/s['file']).stat().st_size for r in reports for s in r['sources']),delivery_bytes=sum(r['delivery_bytes'] for r in reports))
    (ROOT/'audio/suite_provenance.json').write_text(json.dumps(output,indent=2)+'\n')
    print('Validated all seven scores',flush=True)


if __name__ == '__main__':
    main()
