"""Check full-duration incoming ribbons, quiet pauses, and reclined mote coverage."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    """Validate current rendered evidence rather than relying on shader inspection."""
    paths = sorted((ROOT / 'verification/compact_seated_final').glob('*.json'))
    visible_counts = []
    quiet_counts = []
    near_face_counts = []
    for path in paths:
        data = json.loads(path.read_text())
        seconds = data['seconds']
        image = np.asarray(Image.open(path.with_suffix('.png')), dtype=float)
        lanes = np.concatenate([image[530:840, 400:670], image[530:840, 770:1040]], axis=1)
        golden = (lanes[..., 0] > 130) & (lanes[..., 1] > 90) & (lanes[..., 2] < lanes[..., 0] * .75)
        if 28.45 <= seconds <= 31.65:
            visible_counts.append(int(golden.sum()))
            close_lanes = image[760:895, 560:880]
            near_face = (close_lanes[..., 0] > 130) & (close_lanes[..., 1] > 90) & (close_lanes[..., 2] < close_lanes[..., 0] * .75)
            near_face_counts.append(int(near_face.sum()))
            assert data['inhale_visibility'] > .95
        if data['pause']:
            quiet_counts.append(int(golden.sum()))
            assert data['inhale_visibility'] == 0 and data['exhale_visibility'] == 0
    assert len(visible_counts) >= 12 and min(visible_counts) > 1000, 'Incoming lanes must stay visible into late inhale'
    assert min(near_face_counts) > 30, 'Incoming particles must remain visible in the near-face region'
    assert len(quiet_counts) == 8 and max(quiet_counts) < 30, 'Incoming lanes must disappear for the pause'
    reclined = [json.loads(path.read_text()) for path in sorted((ROOT / 'verification/compact_motes_reclined').glob('*.json'))]
    assert len(reclined) >= 100
    early = [item for item in reclined if 38.0 < item['seconds'] < 40.0]
    late = [item for item in reclined if 40.0 <= item['seconds'] < 41.0]
    assert early and late
    assert early[-1]['mote_cluster_0']['position'] != late[0]['mote_cluster_0']['position']
    assert late[0]['mote_cluster_0']['visibility'] < .001, 'Relocation must happen while invisible'
    result = {'status': 'pass', 'main_inhale_frames_checked': len(visible_counts),
              'minimum_visible_incoming_pixels': min(visible_counts), 'minimum_near_face_pixels': min(near_face_counts), 'silent_pause_frames': len(quiet_counts),
              'maximum_pause_lane_pixels': max(quiet_counts), 'reclined_frames_reviewed': len(reclined),
              'mote_relocation_hidden': True, 'review_is_not_headset_performance_measurement': True}
    (ROOT / 'verification/inhale_mote_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
