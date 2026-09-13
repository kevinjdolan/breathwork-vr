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


    def test_visionary_score_is_clocked_to_the_breath_and_documented(self):
        report = json.loads((ROOT/'audio/visionary_journey_provenance.json').read_text())
        self.assertEqual(report['tempo_bpm'], 60)
        self.assertEqual(report['beat_frames'], 48000)
        self.assertEqual(report['beat_count'], 480)
        self.assertEqual(report['cycle_beats'], 16)
        self.assertEqual(len(report['passages']), 4)
        rate, pcm = wavfile.read(ROOT/'assets/audio/breath_visionary_temple.wav')
        self.assertEqual(pcm.shape[0], 16*rate)
        suite = json.loads((ROOT/'audio/suite_provenance.json').read_text())
        self.assertEqual(next(r for r in suite['tracks'] if r['id'] == 'visionary_temple')['sha256'], report['sha256'])

    def test_visionary_tiles_are_original_bakes_with_height_channels(self):
        from PIL import Image
        for name, size in (('eyes', (1024, 1024)), ('flames', (1024, 1024)), ('rings', (1024, 1024)), ('temple', (1024, 2048))):
            with self.subTest(tile=name):
                image = Image.open(ROOT/f'experiences/visionary_temple/tiles/{name}.png')
                self.assertEqual(image.size, size)
                alpha = np.asarray(image.getchannel('A'), dtype=float)/255
                self.assertGreater(alpha.min(), .1)
                self.assertGreater(alpha.max()-alpha.min(), .5)
                self.assertGreater(np.asarray(image.convert('RGB'), dtype=float).std(), 40)
        sheet = Image.open(ROOT/'experiences/visionary_temple/tiles/sigils.png')
        self.assertEqual(sheet.size, (1024, 1024))
        alpha = np.asarray(sheet.getchannel('A'))
        for corner in ((0, 0), (0, 512), (512, 0), (512, 512)):
            self.assertGreater(alpha[corner[0]:corner[0]+512, corner[1]:corner[1]+512].max(), 200)
        self.assertEqual(alpha[:8, :8].max(), 0)


if __name__ == '__main__':
    unittest.main()
