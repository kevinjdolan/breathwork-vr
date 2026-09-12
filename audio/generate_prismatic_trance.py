"""Compose a precise 90 BPM psybient journey around original Lyria synth textures."""

import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

from audio.generate_suite import movement, MASTERS
from audio.stitch_music import RATE, decode, run
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
    """Synthesize 720 rounded beats and a slowly evolving D-Dorian arpeggio."""
    mix = np.zeros((480*RATE,2),dtype=np.float32)
    rng = np.random.default_rng(9016)
    kick_t = np.arange(int(.34*RATE))/RATE
    kick = np.sin(2*np.pi*(47*kick_t + 4.7*(1-np.exp(-kick_t/0.035))))
    kick *= (1-np.exp(-kick_t/.008))*np.exp(-kick_t/.10)*.18
    hat_t = np.arange(int(.10*RATE))/RATE
    hat = sosfilt(butter(2,[1600,4200],btype='bandpass',fs=RATE,output='sos'),rng.normal(size=len(hat_t)))
    hat *= np.sin(np.minimum(hat_t/.014,1)*np.pi/2)**2*np.exp(-hat_t/.022)*.015
    notes = [62,69,74,65,67,71,69,76,62,74,69,65,71,67,74,69]
    for beat in range(720):
        add_note(mix,beat*BEAT_FRAMES,kick)
        add_note(mix,beat*BEAT_FRAMES+BEAT_FRAMES//2,hat,(-1 if beat%2 else 1)*.24)
        bass_t = np.arange(int(.55*RATE))/RATE
        bass_freq = 440*2**(([38,38,38,45][(beat//16)%4]-69)/12)
        bass = np.sin(2*np.pi*bass_freq*bass_t)+.20*np.sin(2*np.pi*bass_freq*2*bass_t)
        bass *= np.sin(np.minimum(bass_t/.04,1)*np.pi/2)**2*np.exp(-bass_t/.20)*.07
        add_note(mix,beat*BEAT_FRAMES+BEAT_FRAMES//2,bass)
    for step in range(1440):
        note = notes[(step+(step//96)*3)%len(notes)]
        t = np.arange(int(1.4*RATE))/RATE
        freq = 440*2**((note-69)/12)
        shimmer = .0015*np.sin(2*np.pi*.7*t+step*.1)
        voice = np.sin(2*np.pi*freq*t+shimmer)+.18*np.sin(2*np.pi*freq*2*t)+.06*np.sin(2*np.pi*freq*3*t)
        voice *= np.sin(np.minimum(t/.045,1)*np.pi/2)**2*np.exp(-t/.22)*.029
        pan = .35*np.sin(step*.39)
        start = step*(BEAT_FRAMES//2)
        add_note(mix,start,voice,pan)
        add_note(mix,start+int(.5*RATE),voice*.26,-pan)
        add_note(mix,start+RATE,voice*.10,pan)
    return mix


def score(entry: dict) -> dict:
    """Generate fresh stems, add clocked electronic voices, and master eight minutes."""
    MASTERS.mkdir(parents=True,exist_ok=True)
    authored = dict(entry,id='prismatic_trance90',music_direction='Pure electronic psychedelic ambient synthesizer stem in D Dorian, an evolving luminous cosmic tunnel of warm resonant analog pads, glassy granular harmonics and liquid filtered oscillators. Bold hypnotic space, intimate electronic timbres. Strictly no piano, acoustic guitar, harp, strings, or music-box melodies. No drums or percussion in this stem: it will sit under a separately produced 90 BPM electronic rhythm. Sustained slow harmonies, no rhythmic arpeggio in the stem, no voices, no sharp transients, no dramatic drop or dark tension.')
    sources = []
    for i,seconds in enumerate([178,178,144]):
        direction = dict(authored)
        if i == 2:
            direction['music_direction'] = 'Warm sustained electronic synthesizer harmonies in D Dorian. Rounded analog pads and gentle resonant overtones, no acoustic instruments and no percussion. Gradually simplify to a peaceful held chord with a long smooth decay. Instrumental electronic background texture.'
        sources.append(movement(direction,i,seconds))
    bed = np.zeros((480*RATE,2),dtype=np.float32)
    ramp = np.linspace(0,np.pi/2,10*RATE)
    for i,(path,_) in enumerate(sources):
        start,seconds = [(0,178),(168,178),(336,144)][i]
        samples = decode(path,seconds)
        samples *= .055/max(float(np.sqrt(np.mean(samples*samples))),.00001)
        if i:
            samples[:len(ramp)] *= np.sin(ramp)[:,None]
        if i < 2:
            samples[-len(ramp):] *= np.cos(ramp)[:,None]
        bed[start*RATE:start*RATE+len(samples)] += samples
    mix = bed*.72 + rhythm()
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
    reports = []
    for _,evidence in sources:
        evidence['probe']['format']['filename'] = evidence['file']
        reports.append(evidence)
    result = dict(id=entry['id'],title=entry['title'],artist=entry['artist'],model='lyria-3.5 + authored electronic synthesis',duration=480,file=entry['music'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),delivery_bytes=target.stat().st_size,target_lufs=-20,tempo_bpm=90,beat_frames=BEAT_FRAMES,beat_count=720,transition_starts=[168,336],crossfade_seconds=10,sources=reports)
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
