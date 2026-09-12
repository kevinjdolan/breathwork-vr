"""Check rendered breath visibility, scene motion, and phase isolation evidence."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]


def pixels(path: Path) -> np.ndarray:
    """Read a rendered viewport as normalized RGB values."""
    return np.asarray(Image.open(path).convert('RGB'), dtype=np.float32) / 255.0


def main() -> None:
    """Verify actual rendered paths and motion rather than shader text."""
    evidence = PROJECT / 'verification'
    incoming = pixels(evidence / 'side_150.png')[425:510, 530:810]
    outgoing = pixels(evidence / 'side_390.png')[425:510, 530:810]
    gold = (incoming[..., 0] > 0.65) & (incoming[..., 1] > 0.4) & (incoming[..., 2] < incoming[..., 0] * 0.85)
    blue = (outgoing[..., 2] > 0.55) & (outgoing[..., 1] > 0.35) & (outgoing[..., 0] < 0.4)
    assert int(gold.sum()) > 300, 'Water must not conceal the incoming path below the horizon'
    assert int(blue.sum()) > 300, 'Outgoing path must remain visible from the mouth'
    review = evidence / 'presence_review'
    frames = sorted(review.glob('frame_*.png'))
    first, second = pixels(frames[2]), pixels(frames[18])
    sky_change = float(np.abs(first[:320] - second[:320]).mean())
    water_change = float(np.abs(first[550:, :450] - second[550:, :450]).mean())
    assert sky_change > 0.001, 'Aurora must move while the viewer is stationary'
    assert water_change > 0.005, 'Water must ripple while the viewer is stationary'
    snapshots = [json.loads(path.read_text()) for path in sorted(review.glob('frame_*.json'))]
    inhales = [item for item in snapshots if item['inhale']]
    assert len(inhales) > 8
    assert all(item['exhale_visibility'] == 0 for item in inhales), 'Outgoing particles must clear for every inhale'
    assert max(item['trail'] for item in snapshots) > 0.8, 'Gaze turn must create an orb movement trail'
    results = {
        'status': 'pass', 'visible_incoming_pixels': int(gold.sum()),
        'visible_outgoing_pixels': int(blue.sum()), 'stationary_sky_change': sky_change,
        'stationary_water_change': water_change, 'inhale_frames_without_exhale': len(inhales),
        'review_is_fixed_timestep': True, 'review_is_headset_performance_measurement': False,
    }
    (evidence / 'visual_checks.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
