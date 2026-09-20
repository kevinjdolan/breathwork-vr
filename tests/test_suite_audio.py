"""Check authored rhythms and every delivered score independently of Godot."""

import hashlib
import json
from pathlib import Path
import subprocess
import unittest

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]


class SuiteAudioContracts(unittest.TestCase):
    def test_all_authored_rhythms_have_silent_holds_and_soft_edges(self):
        entries = json.loads((ROOT/'experiences/catalog.json').read_text())
        self.assertEqual(len(entries), 9)
        for entry in entries[1:]:
            with self.subTest(experience=entry['id']):
                incoming, hold, outgoing, rest = entry['rhythm']
                rate, pcm = wavfile.read(ROOT/'assets/audio'/f"breath_{entry['id']}.wav")
                self.assertEqual(rate, 48000)
                self.assertEqual(pcm.shape, (sum(entry['rhythm'])*rate, 2))
                self.assertEqual(480 % sum(entry['rhythm']), 0)
                self.assertTrue(np.all(pcm[incoming*rate:(incoming+hold)*rate] == 0))
                if rest:
                    self.assertTrue(np.all(pcm[-rest*rate:] == 0))
                self.assertLessEqual(np.max(np.abs(pcm)), 3278)
                self.assertEqual(np.max(np.abs(pcm[[0,-1]])), 0)
                for start in (0, (incoming+hold)*rate):
                    edge = pcm[start:start+int(rate*.02)].astype(float)
                    self.assertLess(np.sqrt(np.mean(edge**2)), 15)

    def test_eight_distinct_scores_are_eight_minutes_and_match_provenance(self):
        catalog = json.loads((ROOT/'experiences/catalog.json').read_text())[1:]
        provenance = json.loads((ROOT/'audio/suite_provenance.json').read_text())
        self.assertEqual(len(provenance['tracks']), 8)
        self.assertEqual(len({r['sha256'] for r in provenance['tracks']}), 8)
        reports = {r['id']: r for r in provenance['tracks']}
        for entry in catalog:
            with self.subTest(experience=entry['id']):
                path = ROOT/entry['music']
                report = reports[entry['id']]
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), report['sha256'])
                result = subprocess.run(['ffprobe','-v','error','-show_format','-show_streams','-of','json',str(path)],capture_output=True,text=True,check=True)
                details = json.loads(result.stdout)
                self.assertAlmostEqual(float(details['format']['duration']),480,delta=.01)
                self.assertEqual(details['streams'][0]['channels'],2)
                self.assertEqual(details['streams'][0]['sample_rate'],'48000')
                result = subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-20:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
                measured = json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])[0]
                self.assertAlmostEqual(float(measured['input_i']),-20,delta=1)
                self.assertLessEqual(float(measured['input_tp']),-1)


    def test_every_score_locks_to_the_breath_ticks(self):
        """Every beat of every score, including through transitions, lands with the whole-second breath ticks."""
        from concurrent.futures import ProcessPoolExecutor
        from audio import beat_grid
        catalog = json.loads((ROOT/'experiences/catalog.json').read_text())
        suite = {r['id']: r for r in json.loads((ROOT/'audio/suite_provenance.json').read_text())['tracks']}
        suite['aurora_lake'] = json.loads((ROOT/'audio/music_provenance.json').read_text())
        tick_ms = beat_grid.tick_reference_ms()
        for entry in catalog:
            self.assertEqual(entry.get('tempo_bpm'), 60, entry['id'])
            self.assertEqual(suite[entry['id']].get('tempo_bpm'), 60, entry['id'])
        paths = [ROOT/entry['music'] for entry in catalog]
        transitions = [suite[entry['id']].get('transitions', []) for entry in catalog]
        with ProcessPoolExecutor(max_workers=4) as pool:
            reports = list(pool.map(beat_grid.analyze, paths, transitions, [tick_ms]*len(paths)))
        for entry, report in zip(catalog, reports):
            with self.subTest(score=entry['id']):
                self.assertEqual(beat_grid.verdict(report), [])
                # Scores with movements or dissolves are checked at every one of them.
                if entry['id'] in ('aurora_lake', 'tidal_origami', 'pilgrim_tides', 'prismatic_sanctuary', 'visionary_temple'):
                    self.assertGreaterEqual(len(report['transitions']), 3)

    def test_lyria_scores_play_their_own_60_bpm_beat(self):
        """Aurora Lake, Tidal Origami and Pilgrim Tides are steady Lyria 3.5 movements on shared bar lines, with no added pulse."""
        from audio import generate_lyria60
        suite = {r['id']: r for r in json.loads((ROOT/'audio/suite_provenance.json').read_text())['tracks']}
        suite['aurora_lake'] = json.loads((ROOT/'audio/music_provenance.json').read_text())
        for identifier in ('aurora_lake', 'tidal_origami', 'pilgrim_tides'):
            with self.subTest(score=identifier):
                report = suite[identifier]
                self.assertEqual((report['model'], report['synthesized_pulse'], report['tempo_bpm']), ('lyria-3.5', False, 60))
                self.assertEqual(len(report['movements']), 3)
                for movement in report['movements']:
                    self.assertLessEqual(movement['wander_ms'], 12.0)
                    self.assertLess(abs(movement['period_ppm']), 2000)
                    self.assertEqual(movement['session_bar_line'] % 4, 0)
                for start, end in report['crossfades']:
                    self.assertEqual((start % 4, end - start), (0, 16))
                self.assertEqual(report['transitions'], [float(t) for start, _ in report['crossfades'] for t in (start, start + 8, start + 16)])
                self.assertEqual(len(report['sources']), 4)
                # Measured on the delivery: no join sags below its quieter side or lurches between neighbouring seconds.
                decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(ROOT/report['file']), '-f', 'f32le', '-ac', '2', '-ar', '48000', '-'], capture_output=True, check=True).stdout
                level = generate_lyria60.short_term_loudness(np.frombuffer(decoded, dtype='<f4').reshape(-1, 2))
                for start, _ in report['crossfades']:
                    join = generate_lyria60.measured_join(level, start)
                    self.assertGreaterEqual(join['dip'], -generate_lyria60.JOIN_DIP_LU, (start, join))
                    self.assertLessEqual(join['step'], generate_lyria60.JOIN_STEP_LU, (start, join))

    def test_visionary_score_is_clocked_to_the_breath_and_documented(self):
        report = json.loads((ROOT/'audio/visionary_journey_provenance.json').read_text())
        self.assertEqual(report['tempo_bpm'], 60)
        self.assertEqual(report['beat_frames'], 48000)
        self.assertEqual(report['beat_count'], 480)
        self.assertEqual(report['cycle_beats'], 16)
        # One harmonic passage per visual passage, dissolving over the final half of each minute like the tunnel.
        self.assertEqual(len(report['passages']), 8)
        self.assertEqual((report['passage_seconds'], report['transition_seconds']), (60, 30))
        self.assertEqual(report['transitions'], [60.0*k - 15.0 for k in range(1, 8)])
        rate, pcm = wavfile.read(ROOT/'assets/audio/breath_visionary_temple.wav')
        self.assertEqual(pcm.shape[0], 16*rate)
        suite = json.loads((ROOT/'audio/suite_provenance.json').read_text())
        self.assertEqual(next(r for r in suite['tracks'] if r['id'] == 'visionary_temple')['sha256'], report['sha256'])

    def test_visionary_passages_have_paintings_reliefs_and_provenance(self):
        from PIL import Image

        def load(path):
            with Image.open(path) as image:
                image.load()
                return image

        tiles = ROOT/'experiences/visionary_temple/tiles'
        record = json.loads((ROOT/'art/visionary_passages_provenance.json').read_text())
        self.assertEqual(list(record['passages']), ['eyes', 'net', 'flames', 'peacock', 'rings', 'lotus', 'geode', 'temple'])
        for name, size in (('eyes', (1024, 1024)), ('flames', (1024, 1024)), ('rings', (1024, 1024)), ('temple', (1024, 2048))):
            with self.subTest(procedural=name):
                image = load(tiles/f'{name}.png')
                self.assertEqual(image.size, size)
                alpha = np.asarray(image.getchannel('A'), dtype=float)/255
                self.assertGreater(alpha.min(), .1)
                self.assertGreater(alpha.max()-alpha.min(), .5)
                self.assertGreater(np.asarray(image.convert('RGB'), dtype=float).std(), 40)
        for name in ('net', 'peacock', 'lotus', 'geode'):
            with self.subTest(painted=name):
                image = load(tiles/f'{name}.png')
                self.assertEqual(image.size, (2048, 2048))
                pixels = np.asarray(image.convert('RGB'), dtype=float)
                self.assertGreater(pixels.std(), 40)
                # Seamless: wrapped edges differ no more than neighbouring pixels do, within tolerance.
                horizontal = np.abs(pixels[:, 0]-pixels[:, -1]).mean()/np.abs(pixels[:, 1:]-pixels[:, :-1]).mean()
                vertical = np.abs(pixels[0]-pixels[-1]).mean()/np.abs(pixels[1:]-pixels[:-1]).mean()
                self.assertLess(max(horizontal, vertical), 2.0)
                painting = record['passages'][name]['painting']
                self.assertTrue(painting['model'].startswith('gpt-image') and painting['prompt'])
        for name, entry in record['passages'].items():
            with self.subTest(relief=name):
                tile = load(tiles/f'{name}.png')
                relief = load(tiles/f'{name}_relief.png')
                self.assertEqual(relief.mode, 'RGBA')
                self.assertEqual(min(relief.size), 1024)
                self.assertEqual(relief.size[0]*tile.size[1], relief.size[1]*tile.size[0])
                channels = np.asarray(relief, dtype=float)/255
                self.assertGreater(channels[..., 0].max()-channels[..., 0].min(), .9)
                self.assertLess(abs(channels[..., 1].mean()-.5), .05)
                self.assertLess(abs(channels[..., 2].mean()-.5), .05)
                # The erosion order is equalised, so a dissolve opens equal areas in equal time.
                self.assertLess(abs(np.mean(channels[..., 3] < .5)-.5), .02)
                self.assertTrue(entry['relief']['model'].startswith('gemini') and entry['relief']['prompt'])
                self.assertEqual(entry['tile_sha256'], hashlib.sha256((tiles/f'{name}.png').read_bytes()).hexdigest())
                self.assertEqual(entry['relief_sha256'], hashlib.sha256((tiles/f'{name}_relief.png').read_bytes()).hexdigest())
                importer = (tiles/f'{name}_relief.png.import').read_text()
                self.assertIn('compress/mode=0', importer)
                self.assertIn('process/fix_alpha_border=false', importer)
                self.assertIn('detect_3d/compress_to=0', importer)
        sheet = load(tiles/'sigils.png')
        self.assertEqual(sheet.size, (2048, 1024))
        alpha = np.asarray(sheet.getchannel('A'))
        for cell in range(8):
            x, y = cell % 4*512, cell//4*512
            self.assertGreater(alpha[y:y+512, x:x+512].max(), 200)
            self.assertEqual(alpha[y:y+8, x:x+8].max(), 0)
        self.assertEqual(record['sprites']['sheet_sha256'], hashlib.sha256((tiles/'sigils.png').read_bytes()).hexdigest())
        relics = json.loads((ROOT/'art/visionary_relics_provenance.json').read_text())
        atlas = np.asarray(load(tiles/'matcaps.png').convert('RGB'), dtype=float)
        self.assertEqual(atlas.shape, (1024, 1024, 3))
        self.assertEqual(relics['atlas_sha256'], hashlib.sha256((tiles/'matcaps.png').read_bytes()).hexdigest())
        self.assertEqual(len(relics['materials']), 16)
        for name, material in relics['materials'].items():
            with self.subTest(matcap=name):
                y, x = divmod(material['index'], 4)
                cell = atlas[y*256:(y+1)*256, x*256:(x+1)*256]
                self.assertGreater(cell[64:192, 64:192].mean(), 25)
                self.assertLess(cell[:6, :6].max(), 1)
                self.assertTrue(material['model'].startswith('gemini') and material['prompt'])


if __name__ == '__main__':
    unittest.main()
