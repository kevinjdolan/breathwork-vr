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
        self.assertEqual(len(entries), 8)
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

    def test_seven_distinct_scores_are_eight_minutes_and_match_provenance(self):
        catalog = json.loads((ROOT/'experiences/catalog.json').read_text())[1:]
        provenance = json.loads((ROOT/'audio/suite_provenance.json').read_text())
        self.assertEqual(len(provenance['tracks']), 7)
        self.assertEqual(len({r['sha256'] for r in provenance['tracks']}), 7)
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


if __name__ == '__main__':
    unittest.main()
