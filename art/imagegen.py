"""Small clients for Gemini (Nano Banana) and OpenAI image generation that keep untouched local masters."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from PIL import Image

GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'
OPENAI_URL = 'https://api.openai.com/v1/images/{endpoint}'
MASTERS = Path(__file__).resolve().parent / 'masters'


class GenerationError(RuntimeError):
    pass


def png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    return buffer.getvalue()


def _retry(call, attempts: int):
    delay = 8.0
    for attempt in range(attempts):
        try:
            return call()
        except (requests.RequestException, GenerationError) as error:
            # Content refusals and invalid requests will not succeed on a retry.
            if attempt == attempts - 1 or 'invalid_request' in str(error) or 'SAFETY' in str(error):
                raise
            time.sleep(delay)
            delay *= 2


def gemini(model: str, prompt: str, references: list[Image.Image] = (), aspect: str = '1:1', size: str = '2K', attempts: int = 3) -> Image.Image:
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        raise GenerationError('GEMINI_API_KEY or GOOGLE_API_KEY is required')
    parts = [{'text': prompt}]
    for reference in references:
        parts.append({'inline_data': {'mime_type': 'image/png', 'data': base64.b64encode(png_bytes(reference.convert('RGB'))).decode()}})
    image_config = {'aspectRatio': aspect}
    if size:
        image_config['imageSize'] = size
    body = {'contents': [{'role': 'user', 'parts': parts}], 'generationConfig': {'responseModalities': ['IMAGE'], 'imageConfig': image_config}}

    def call() -> Image.Image:
        response = requests.post(GEMINI_URL.format(model=model), headers={'x-goog-api-key': key}, json=body, timeout=600)
        payload = response.json()
        if response.status_code != 200:
            raise GenerationError(f'{model} HTTP {response.status_code}: {json.dumps(payload)[:500]}')
        images = []
        for candidate in payload.get('candidates', []):
            for part in candidate.get('content', {}).get('parts', []):
                data = part.get('inlineData') or part.get('inline_data')
                # Thinking models can return draft images; the final image is the last non-thought part.
                if data and not part.get('thought'):
                    images.append(data['data'])
        if not images:
            reason = [c.get('finishReason') for c in payload.get('candidates', [])] or payload.get('promptFeedback')
            raise GenerationError(f'{model} returned no image: {reason}')
        return Image.open(io.BytesIO(base64.b64decode(images[-1]))).copy()

    return _retry(call, attempts)


def _openai_key() -> str:
    key = os.environ.get('OPENAI_API_KEY')
    if not key:
        raise GenerationError('OPENAI_API_KEY is required')
    return key


def _openai_image(response: requests.Response, model: str) -> Image.Image:
    payload = response.json()
    if response.status_code != 200 or 'data' not in payload:
        raise GenerationError(f'{model} HTTP {response.status_code}: {json.dumps(payload)[:500]}')
    return Image.open(io.BytesIO(base64.b64decode(payload['data'][0]['b64_json']))).copy()


def openai_generate(model: str, prompt: str, size: str = '2048x2048', quality: str = 'high', background: str | None = None, attempts: int = 3) -> Image.Image:
    body = {'model': model, 'prompt': prompt, 'size': size, 'quality': quality, 'output_format': 'png', 'n': 1}
    if background:
        body['background'] = background

    def call() -> Image.Image:
        response = requests.post(OPENAI_URL.format(endpoint='generations'), headers={'Authorization': f'Bearer {_openai_key()}'}, json=body, timeout=600)
        return _openai_image(response, model)

    return _retry(call, attempts)


def openai_edit(model: str, prompt: str, images: list[Image.Image], mask: Image.Image | None = None, size: str = '2048x2048', quality: str = 'high', background: str | None = None, attempts: int = 3) -> Image.Image:
    """Edit or restyle images. A mask's transparent pixels mark the region the model may repaint."""
    data = {'model': model, 'prompt': prompt, 'size': size, 'quality': quality, 'output_format': 'png', 'n': '1'}
    if background:
        data['background'] = background

    def call() -> Image.Image:
        files = [('image[]', (f'input_{i}.png', png_bytes(image), 'image/png')) for i, image in enumerate(images)]
        if mask is not None:
            files.append(('mask', ('mask.png', png_bytes(mask), 'image/png')))
        response = requests.post(OPENAI_URL.format(endpoint='edits'), headers={'Authorization': f'Bearer {_openai_key()}'}, data=data, files=files, timeout=600)
        return _openai_image(response, model)

    return _retry(call, attempts)


def save_master(image: Image.Image, relative: str, record: dict) -> Path:
    """Store an untouched generation with a JSON sidecar describing exactly how it was requested."""
    path = MASTERS / f'{relative}.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    sidecar = dict(record, file=str(path.relative_to(MASTERS)), size=list(image.size), mode=image.mode, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), created=datetime.now(timezone.utc).isoformat(timespec='seconds'))
    path.with_suffix('.json').write_text(json.dumps(sidecar, indent=2) + '\n')
    return path
