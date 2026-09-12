"""Validate captured motion and the revised inhale, pause, and exhale rhythm."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    """Check distinct rendered frames and silence of both streams during each pause."""
    directory = ROOT / 'verification/depth_motion'
    paths = sorted(directory.glob('frame_*.json'))
    snapshots = [json.loads(path.read_text()) for path in paths]
    assert len(snapshots) >= 60
    times = [item['seconds'] for item in snapshots]
    assert all(b > a for a, b in zip(times, times[1:])), 'Captures must correspond to distinct simulation times'
    holds = [item for item in snapshots if item['pause']]
    assert len(holds) == 8, 'Two-second pause must span eight quarter-second captures'
    assert all(item['inhale_visibility'] == 0 and item['exhale_visibility'] == 0 for item in holds)
    assert all(item['breath_fill'] == 1 for item in holds)
    assert all(item['exhale_visibility'] == 0 for item in snapshots if item['inhale'])
    incoming_fade = [item['inhale_visibility'] for item in snapshots if 31.1 < item['seconds'] < 32.0]
    assert all(b < a for a, b in zip(incoming_fade, incoming_fade[1:])), 'Incoming stream must dissolve before pause'
    first = np.asarray(Image.open(paths[2].with_suffix('.png')), dtype=float)
    second = np.asarray(Image.open(paths[14].with_suffix('.png')), dtype=float)
    sky_change = float(np.abs(first[:320] - second[:320]).mean())
    water_change = float(np.abs(first[550:, :450] - second[550:, :450]).mean())
    assert sky_change > 0.3 and water_change > 1.0, 'Auroras and water must visibly animate'
    result = {'status': 'pass', 'distinct_capture_times': len(times), 'silent_pause_frames': len(holds),
              'inhale_fades_monotonically': True, 'sky_pixel_change': sky_change,
              'water_pixel_change': water_change, 'fixed_timestep_review_not_fps_measurement': True}
    (ROOT / 'verification/depth_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
