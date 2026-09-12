"""Generate resumable Lyria movements with untouched masters and safe provenance."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

import requests

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions"
MODEL = "lyria-3.5"
MOVEMENTS = {"calm": 178.0, "deepening": 178.0, "peak_resolve": 144.0}


def probe(path: Path) -> dict:
    """Read source format evidence without decoding or changing the master."""
    result = subprocess.run(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def generate(name: str) -> None:
    """Request one movement and atomically retain its original audio and metadata."""
    directory = ROOT / "audio" / "masters"
    directory.mkdir(exist_ok=True)
    evidence_path = directory / f"{name}.json"
    prompt = (ROOT / "audio" / "lyria_prompts.md").read_text().split(f"## {name}\n", 1)[1].split("\n## ", 1)[0].split("\nAlternative", 1)[0].strip()
    if evidence_path.exists():
        evidence = json.loads(evidence_path.read_text())
        path = directory / evidence["file"]
        if path.exists() and evidence["prompt"] == prompt and hashlib.sha256(path.read_bytes()).hexdigest() == evidence["sha256"]:
            probe(path)
            print(f"Validated existing master: {name}", flush=True)
            return
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise SystemExit("No Lyria credential; use python -m audio.stitch_music --placeholder")
    print(f"Generating {name} with {MODEL}", flush=True)
    for attempt in range(4):
        response = requests.post(ENDPOINT, headers={"x-goog-api-key": key}, json={"model": MODEL, "input": prompt, "response_format": {"type": "audio"}}, timeout=600)
        if response.status_code not in (408, 409, 429, 500, 502, 503, 504):
            break
        print(f"Transient HTTP {response.status_code}; retry {attempt + 1}/4", flush=True)
        time.sleep(min(30, 2 ** (attempt + 2)))
    if not response.ok:
        raise SystemExit(f"Lyria request unavailable: HTTP {response.status_code}; {response.json().get('error', {}).get('message', '')[:300]}")
    payload = response.json()
    blocks = [block for step in payload.get("steps", []) if step.get("type") == "model_output" for block in step.get("content", [])]
    audio = [block for block in blocks if block.get("type") == "audio"]
    if len(audio) != 1:
        raise SystemExit(f"Expected one audio block, received {len(audio)}")
    raw = base64.b64decode(audio[0]["data"])
    extension = ".wav" if raw[:4] == b"RIFF" else ".mp3"
    path = directory / (name + extension)
    temporary = path.with_suffix(extension + ".tmp")
    temporary.write_bytes(raw)
    details = probe(temporary)
    if float(details["format"]["duration"]) < 120:
        raise SystemExit("Master is unexpectedly short; original remains in temporary file")
    temporary.replace(path)
    evidence = {"id": name, "artist": "Breathwork VR / Google Lyria", "model": MODEL, "endpoint": ENDPOINT, "interaction_id": payload.get("id"), "prompt": prompt, "file": path.name, "sha256": hashlib.sha256(raw).hexdigest(), "probe": details, "response_text": [b.get("text", "") for b in blocks if b.get("type") == "text"]}
    pending = evidence_path.with_suffix(".json.tmp")
    pending.write_text(json.dumps(evidence, indent=2) + "\n")
    pending.replace(evidence_path)
    print(f"Saved {name}: {details['format']['duration']} seconds, {len(raw)} bytes", flush=True)


def main() -> None:
    """Generate one selected movement or the complete authored collection."""
    parser = argparse.ArgumentParser()
    parser.add_argument("movement", choices=[*MOVEMENTS, "all"], default="all", nargs="?")
    args = parser.parse_args()
    for name in MOVEMENTS if args.movement == "all" else [args.movement]:
        generate(name)


if __name__ == "__main__":
    main()
