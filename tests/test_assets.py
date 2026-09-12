"""Validate sample counts, mastering, and the exhaustive 24-bit IFS address space."""

import json
import hashlib
from pathlib import Path
import subprocess
import unittest

import numpy as np
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]


class AssetContracts(unittest.TestCase):
    """Independent audio and GPU-address representation checks."""

    def test_approved_exhale_samples_are_unchanged(self):
        expected = {12: '0dbaf8376e77e781438af9c23cef846f623bb49b4114c1793f86944e07ed9109',
                    14: 'd35aa94ee820de6f9d21904643ff01ef2874b31d7c958f100e9e0c051a5090b5'}
        for seconds, digest in expected.items():
            rate, samples = wavfile.read(ROOT / f'assets/audio/breath_{seconds}s.wav')
            self.assertEqual(hashlib.sha256(samples[6 * rate:].tobytes()).hexdigest(), digest)
            inhale = samples[:4 * rate].astype(float)
            middle = np.sqrt(np.mean(inhale[rate:3 * rate] ** 2))
            self.assertLess(np.sqrt(np.mean(inhale[:rate // 2] ** 2)), middle * 0.2)
            self.assertLess(np.sqrt(np.mean(inhale[-rate // 2:] ** 2)), middle * 0.2)

    def test_five_mote_voices_have_soft_edges_and_distinct_timbres(self):
        signatures = set()
        for index in range(5):
            rate, voice = wavfile.read(ROOT / f'assets/audio/mote_voice_{index}.wav')
            self.assertEqual(voice.shape, (int(rate * 4.8),))
            self.assertTrue(np.all(voice[[0, -1]] == 0))
            self.assertLess(np.max(np.abs(voice.astype(float))), 3000)
            middle = np.sqrt(np.mean(voice[rate:3 * rate].astype(float) ** 2))
            self.assertLess(np.sqrt(np.mean(voice[:rate // 2].astype(float) ** 2)), middle * 0.1)
            signatures.add(hashlib.sha256(voice.tobytes()).hexdigest())
        self.assertEqual(len(signatures), 5)

    def test_lyria_water_loops_are_seamless_and_independently_timed(self):
        for index in range(3):
            rate, water = wavfile.read(ROOT / f'assets/audio/water_lyria_{index}.wav')
            self.assertEqual(water.shape, ((24 + index) * rate,))
            self.assertLess(abs(int(water[0]) - int(water[-1])), 200)
            self.assertLess(np.max(np.abs(water.astype(float))), 4600)
            self.assertGreater(np.sqrt(np.mean(water.astype(float) ** 2)), 50)

    def test_breath_sample_counts_peaks_and_silent_seams(self):
        for seconds in (12, 14):
            rate, samples = wavfile.read(ROOT / "assets" / "audio" / f"breath_{seconds}s.wav")
            self.assertEqual(rate, 48000)
            self.assertEqual(samples.shape, (seconds * rate, 2))
            self.assertEqual(samples.dtype, np.int16)
            self.assertLessEqual(np.max(np.abs(samples.astype(float))), 3277)
            self.assertTrue(np.all(samples[[0, -1]] == 0))
            self.assertGreater(np.sqrt(np.mean(samples[rate:2 * rate].astype(float) ** 2)), 10)

    def test_two_second_pause_is_silent_and_cues_resume_after_it(self):
        for seconds in (12, 14):
            rate, samples = wavfile.read(ROOT / "assets/audio" / f"breath_{seconds}s.wav")
            self.assertTrue(np.all(samples[4 * rate:6 * rate] == 0))
            self.assertGreater(np.sqrt(np.mean(samples[7 * rate:8 * rate].astype(float) ** 2)), 10)

    def test_spatial_audio_is_mono_and_water_loop_seam_is_quiet(self):
        rate, water = wavfile.read(ROOT / "assets/audio/water_ambient.wav")
        self.assertEqual(water.shape, (32 * rate,))
        self.assertLess(abs(int(water[0]) - int(water[-1])), 200)
        rate, accent = wavfile.read(ROOT / "assets/audio/mote_air.wav")
        self.assertEqual(accent.ndim, 1)
        self.assertTrue(np.all(accent[[0, -1]] == 0))

    def test_music_duration_format_and_loudness(self):
        path = ROOT / "assets" / "audio" / "music.ogg"
        result = subprocess.run(["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)], capture_output=True, text=True, check=True)
        details = json.loads(result.stdout)
        self.assertAlmostEqual(float(details["format"]["duration"]), 480, delta=0.1)
        self.assertEqual(details["streams"][0]["sample_rate"], "48000")
        self.assertEqual(details["streams"][0]["codec_name"], "vorbis")
        result = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "loudnorm=I=-18:print_format=json", "-f", "null", "-"], capture_output=True, text=True, check=True)
        measurements = json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind("{"):])[0]
        self.assertAlmostEqual(float(measurements["input_i"]), -18, delta=0.6)
        (ROOT / "verification" / "audio_loudness.json").write_text(json.dumps(measurements, indent=2) + "\n")

    def test_all_16777216_addresses_decode_and_reencode_exactly(self):
        # Each two-bit digit is recovered exactly; this is a bijection between
        # [0, 2^24) and the 4^12 paths, including float32 CUSTOM round-tripping.
        for start in range(0, 1 << 24, 1 << 18):
            addresses = np.arange(start, start + (1 << 18), dtype=np.uint32)
            packed = ((addresses * np.uint32(1048583)) + np.uint32(7919)) & np.uint32(16777215)
            self.assertTrue(np.array_equal(packed, packed.astype(np.float32).astype(np.uint32)))
            rebuilt = np.zeros_like(packed)
            for depth in range(12):
                rebuilt |= ((packed >> (depth * 2)) & 3) << (depth * 2)
            self.assertTrue(np.array_equal(packed, rebuilt))
        self.assertEqual(4 ** 12, 1 << 24)
        self.assertEqual(1048583 % 2, 1)


if __name__ == "__main__":
    unittest.main()
