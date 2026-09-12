"""Compose four cohesive, theme-specific eight-minute ambient scores."""

import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np
from scipy.io import wavfile

from audio.generate_prismatic_trance import add_note
from audio.generate_suite import MASTERS
from audio.stitch_music import RATE, run

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = {
    'fractal_garden': 'Recursive glass harmonics in nested three- and six-note canons, beneath slowly unfolding harmonic fields.',
    'cloud_atelier': 'Weightless sustained string-like harmonics, airy vowel-free glass tones, long overlapping swells and no rhythmic percussion.',
    'neural_constellation': 'Rounded cellular sine resonances answer across the stereo field over an evolving warm harmonic network.',
    'circuit_garden': 'Warm analogue oscillator chords and softly charged, slowly sequenced electronic tones. No acoustic instruments or percussion.',
}


def tone(note: float, duration: float, mode: int, voice: int = 0) -> np.ndarray:
    """Render a gently enveloped oscillator voice without sharp attacks or release."""
    t = np.arange(int(duration*RATE), dtype=np.float64)/RATE
    frequency = 440*2**((note-69)/12)
    phase = 2*np.pi*frequency*t
    if mode == 0:
        signal = np.sin(phase+.27*np.sin(phase*2)) + .13*np.sin(phase*3)*np.exp(-t/4)
        attack, release = .55, 2.8
    elif mode == 1:
        signal = np.sin(phase+.012*np.sin(t*.6)) + .22*np.sin(phase*2.001) + .07*np.sin(phase*3.002)
        attack, release = 4.0, 5.0
    elif mode == 2:
        signal = np.sin(phase+.38*np.sin(phase*.5)*np.exp(-t/4)) + .12*np.sin(phase*2)
        attack, release = .8, 3.0
    else:
        signal = np.sin(phase) + .25*np.sin(phase*2+.06*np.sin(t*.8)) + .10*np.sin(phase*3)
        attack, release = .6, 2.0
    envelope = np.sin(np.clip(t/attack,0,1)*np.pi/2)**2
    envelope *= np.sin(np.clip((duration-t)/release,0,1)*np.pi/2)**2
    envelope *= .90 + .10*np.sin(t*.21+voice)
    return (signal*envelope).astype(np.float32)


def compose(mode: int) -> np.ndarray:
    """Arrange harmonically related sustained voices and a theme's own motif grammar."""
    mix = np.zeros((480*RATE,2), dtype=np.float32)
    chords = [[45,52,59,64],[43,50,57,62],[48,55,59,64],[41,48,55,60]]
    if mode == 1:
        chords = [[48,55,62,67],[53,60,64,69],[50,57,64,69],[48,55,59,62]]
    for section, start in enumerate(range(0,480,24)):
        chord = chords[(section//2+mode)%4]
        for voice, note in enumerate(chord):
            samples = tone(note,32,1,voice)*(.017 if mode!=1 else .025)
            add_note(mix,start*RATE,samples,(voice-1.5)*.17)
    scales = [[69,76,81,83,88,83],[72,79,84,86],[64,71,76,78,71],[57,64,69,71,76,69,64,62]]
    interval = [3.0,12.0,4.8,2.5][mode]
    for index in range(int(474/interval)):
        start = 4+index*interval
        motif = scales[mode]
        # Phrase transformations share the score's chord root; no independent backing clip.
        section = int(start//24)
        chord = chords[(section//2+mode)%4]
        degree = index%len(motif)
        if mode==0:
            degree = (index+index//6)%len(motif)
        note = chord[0]+(motif[degree]-motif[0])+24
        if mode==3:
            note-=12
        samples = tone(note,[8,18,9,5.5][mode],mode,index)*[.021,.011,.024,.026][mode]
        add_note(mix,int(start*RATE),samples,np.sin(index*1.8)*.35)
        if mode==2:
            add_note(mix,int((start+1.8)*RATE),tone(note+7,6,mode,index)*.008,-np.sin(index*1.8)*.35)
    # Quiet cross-channel echoes are part of this single score and soften spatial edges.
    delay=int([.75,1.9,1.2,.50][mode]*RATE)
    mix[delay:]+=mix[:-delay,::-1].copy()*.12
    mix[:8*RATE]*=np.linspace(0,1,8*RATE)[:,None]**2
    mix[-8*RATE:]*=np.linspace(1,0,8*RATE)[:,None]**2
    return mix


def deliver(entry: dict, mode: int) -> dict:
    """Retain a lossless master and publish a measured stereo Vorbis delivery."""
    MASTERS.mkdir(parents=True,exist_ok=True)
    mix = compose(mode)
    master = MASTERS/f"{entry['id']}_themed_v24.wav"
    wavfile.write(master,RATE,mix)
    target=ROOT/entry['music']
    with tempfile.TemporaryDirectory() as directory:
        first=run(['ffmpeg','-hide_banner','-i',str(master),'-af','loudnorm=I=-20:TP=-2:LRA=8:print_format=json','-f','null','-'])
        measured=json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind('{'):])[0]
        normalization=f"loudnorm=I=-20:TP=-2:LRA=8:measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true,lowpass=f=6500"
        normalized=Path(directory)/'normalized.wav'
        run(['ffmpeg','-v','error','-y','-i',str(master),'-af',normalization,'-ar',str(RATE),'-c:a','pcm_s24le',str(normalized)])
        pending=target.with_suffix('.pending.ogg')
        run(['oggenc','-Q','-q','5','-o',str(pending),str(normalized)])
        pending.replace(target)
    print('Mastered '+entry['id'],flush=True)
    return dict(id=entry['id'],title=entry['title'],artist='Breathwork VR',model='authored deterministic synthesis',duration=480,file=entry['music'],sha256=hashlib.sha256(target.read_bytes()).hexdigest(),delivery_bytes=target.stat().st_size,target_lufs=-20,arrangement=DIRECTIONS[entry['id']],sources=[dict(file=master.name,sha256=hashlib.sha256(master.read_bytes()).hexdigest(),origin='Original synthesized oscillator arrangement; no sampled backing track')])


def main() -> None:
    """Replace four mismatched scores while retaining the water, human and trance music."""
    catalog_path=ROOT/'experiences/catalog.json'
    entries=json.loads(catalog_path.read_text())
    provenance_path=ROOT/'audio/suite_provenance.json'
    provenance=json.loads(provenance_path.read_text())
    for mode,id in enumerate(DIRECTIONS):
        entry=next(e for e in entries if e['id']==id)
        report=deliver(entry,mode)
        provenance['tracks']=[report if r['id']==id else r for r in provenance['tracks']]
        entry['artist']='Breathwork VR'
        entry['music_direction']=DIRECTIONS[id]
        provenance['delivery_bytes']=sum(r['delivery_bytes'] for r in provenance['tracks'])
        provenance['master_bytes']=sum((MASTERS/s['file']).stat().st_size for r in provenance['tracks'] for s in r['sources'])
        provenance_path.write_text(json.dumps(provenance,indent=2)+'\n')
        catalog_path.write_text(json.dumps(entries,indent=2)+'\n')


if __name__=='__main__':
    main()
