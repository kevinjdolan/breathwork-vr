"""Compose a precise 90 BPM psybient journey with one cohesive electronic arrangement."""

import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

from audio.generate_suite import MASTERS
from audio.stitch_music import RATE, run
from audio.generate_music import probe

ROOT = Path(__file__).resolve().parents[1]
BEAT_FRAMES = 32000


def add_note(mix: np.ndarray, start: int, samples: np.ndarray, pan: float = 0.0) -> None:
    """Place a mono voice on the exact beat grid with restrained stereo placement."""
    count = min(len(samples), len(mix) - start)
    if count <= 0:
        return
    mix[start:start+count,0] += samples[:count] * np.sqrt((1-pan)*.5)
    mix[start:start+count,1] += samples[:count] * np.sqrt((1+pan)*.5)


def rhythm() -> np.ndarray:
    """Synthesize 720 rounded beats with offbeat bass and a quiet filtered shaker."""
    mix = np.zeros((480*RATE,2),dtype=np.float32)
    rng = np.random.default_rng(9016)
    kick_t = np.arange(int(.34*RATE))/RATE
    kick = np.sin(2*np.pi*(47*kick_t + 4.7*(1-np.exp(-kick_t/0.035))))
    kick *= (1-np.exp(-kick_t/.008))*np.exp(-kick_t/.10)*.18
    hat_t = np.arange(int(.10*RATE))/RATE
    hat = sosfilt(butter(2,[1600,4200],btype='bandpass',fs=RATE,output='sos'),rng.normal(size=len(hat_t)))
    hat *= np.sin(np.minimum(hat_t/.014,1)*np.pi/2)**2*np.exp(-hat_t/.022)*.015
    for beat in range(720):
        add_note(mix,beat*BEAT_FRAMES,kick)
        add_note(mix,beat*BEAT_FRAMES+BEAT_FRAMES//2,hat,(-1 if beat%2 else 1)*.24)
        bass_t = np.arange(int(.55*RATE))/RATE
        bass_freq = 440*2**(([38,38,38,45][(beat//16)%4]-69)/12)
        bass = np.sin(2*np.pi*bass_freq*bass_t)+.20*np.sin(2*np.pi*bass_freq*2*bass_t)
        bass *= np.sin(np.minimum(bass_t/.04,1)*np.pi/2)**2*np.exp(-bass_t/.20)*.07
        add_note(mix,beat*BEAT_FRAMES+BEAT_FRAMES//2,bass)
    return mix


def sustained_harmony() -> np.ndarray:
    """Create sustained, beat-aligned synth chords without piano or plucked attacks."""
    bed = np.zeros((480*RATE, 2), dtype=np.float32)
    chords = [(50, 57, 60, 64), (50, 55, 59, 64), (48, 55, 60, 64), (50, 57, 62, 65)]
    bar_frames = BEAT_FRAMES*32
    overlap = 4*RATE
    for index, start in enumerate(range(0, len(bed), bar_frames)):
        count = min(bar_frames+overlap, len(bed)-start)
        t = np.arange(count, dtype=np.float64)/RATE
        chord = np.zeros((count, 2), dtype=np.float32)
        for voice, note in enumerate(chords[index % len(chords)]):
            frequency = 440*2**((note-69)/12)
            for channel in range(2):
                detune = 1+(.0009 if channel else -.0009)
                phase = 2*np.pi*frequency*detune*t+voice*.7
                tone = np.sin(phase)+.23*np.sin(phase*2+.1*np.sin(t*.7))+.08*np.sin(phase*3)
                motion = .88+.12*np.sin(t*.31+index+voice)
                chord[:, channel] += (tone*motion*.010).astype(np.float32)
        fade = min(overlap, count)
        chord[:fade] *= np.linspace(0, 1, fade)[:, None]
        if start+count < len(bed):
            chord[-fade:] *= np.linspace(1, 0, fade)[:, None]
        bed[start:start+count] += chord
    return bed


def score(entry: dict) -> dict:
    """Master a single coherent synth arrangement with no generated music overlay."""
    MASTERS.mkdir(parents=True,exist_ok=True)
    mix = sustained_harmony() + rhythm()
    mix[:8*RATE] *= np.linspace(0,1,8*RATE)[:,None]
    mix[-8*RATE:] *= np.linspace(1,0,8*RATE)[:,None]
    target = ROOT/entry['music']
    with tempfile.TemporaryDirectory() as directory:
        wav = Path(directory)/'mix.wav'
        wavfile.write(wav,RATE,mix)
        first = run(['ffmpeg','-hide_banner','-i',str(wav),'-af','loudnorm=I=-20:TP=-2:LRA=8:print_format=json','-f','null','-'])
        measured = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
        normalization = f"loudnorm=I=-20:TP=-2:LRA=8:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true,lowpass=f=6500"
        normalized = Path(directory)/'normalized.wav'
        run(['ffmpeg','-v','error','-y','-i',str(wav),'-af',normalization,'-ar',str(RATE),'-c:a','pcm_s24le',str(normalized)])
        pending = target.with_suffix('.pending.ogg')
        run(['oggenc','-Q','-q','5','-o',str(pending),str(normalized)])
        assert abs(float(probe(pending)['format']['duration'])-480)<.01
        pending.replace(target)
    master = MASTERS/'prismatic_trance90_cohesive.wav'
    wavfile.write(master,RATE,mix)
    sources = [dict(file=master.name,sha256=hashlib.sha256(master.read_bytes()).hexdigest(),origin='Authored deterministic synthesis, no sampled/generated backing recording')]
    result = dict(id=entry['id'],title=entry['title'],artist='Breathwork VR',model='authored electronic synthesis',duration=480,file=entry['music'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),delivery_bytes=target.stat().st_size,target_lufs=-20,tempo_bpm=90,beat_frames=BEAT_FRAMES,beat_count=720,arrangement='One clocked arrangement: rounded kick, offbeat synth bass, filtered shaker and sustained 32-beat synth chords. No piano, plucked melody or independently timed backing recording.',sources=sources)
    (ROOT/'audio/prismatic_trance_provenance.json').write_text(json.dumps(result,indent=2)+'\n')
    print('Mastered eight-minute 90 BPM prismatic trance',flush=True)
    return result


def main() -> None:
    """Replace only Prismatic Sanctuary and update the public suite provenance."""
    entry = next(e for e in json.loads((ROOT/'experiences/catalog.json').read_text()) if e['id']=='prismatic_sanctuary')
    result = score(entry)
    path = ROOT/'audio/suite_provenance.json'
    catalog = json.loads(path.read_text())
    catalog['tracks'] = [result if item['id']==entry['id'] else item for item in catalog['tracks']]
    catalog['delivery_bytes'] = sum(item['delivery_bytes'] for item in catalog['tracks'])
    catalog['master_bytes'] = sum((MASTERS/source['file']).stat().st_size for item in catalog['tracks'] for source in item['sources'])
    path.write_text(json.dumps(catalog,indent=2)+'\n')


if __name__ == '__main__':
    main()
