"""Render and validate one-minute movies with runtime audio for every catalog world."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get('GODOT_BIN', ROOT/'.tools/Godot.app/Contents/MacOS/Godot'))
WORK = ROOT/'verification/previews'


def run(args: list[str], log: Path) -> None:
    """Run a bounded artifact operation and retain its complete diagnostic output."""
    with log.open('w') as output:
        subprocess.run(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, check=True)


def render(item: tuple[int, dict], output: Path, full: bool = False) -> dict:
    """Capture runtime footage (one minute, or the whole session), encode a portable movie, and check every stream."""
    number, entry = item
    id = entry['id']
    duration = entry['duration'] if full else 60
    suffix = '-full' if full else ''
    raw = WORK/f'{id}{suffix}.avi'
    log = WORK/f'{id}{suffix}_render.log'
    target = output/f'{number:02d}-{id}{suffix}.mp4'
    session = [f'--preview-duration={duration}','--preview-start=0','--preview-view=forward'] if full else []
    run([str(GODOT),'--xr-mode','off','--path',str(ROOT),'--fixed-fps','30','--disable-vsync','--write-movie',str(raw),'--script','tests/render_preview.gd','--','--test',f'--experience={id}',*session],log)
    if re.search(r'^(SCRIPT ERROR:|SHADER ERROR:|ERROR:)',log.read_text(),re.MULTILINE):
        raise RuntimeError(f'{id}: Godot reported an error; see {log}')
    end = duration-0.8
    run(['ffmpeg','-v','error','-y','-ss','2','-i',str(raw),'-t',str(duration),'-vf',f'fade=t=in:st=0:d=0.65,fade=t=out:st={end}:d=0.8','-af',f'afade=t=in:st=0:d=0.65,afade=t=out:st={end}:d=0.8','-c:v','libx264','-preset','fast','-crf','21' if full else '20','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-movflags','+faststart',str(target)],WORK/f'{id}{suffix}_encode.log')
    details=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(target)]))
    video=next(s for s in details['streams'] if s['codec_type']=='video')
    audio=next(s for s in details['streams'] if s['codec_type']=='audio')
    assert abs(float(details['format']['duration'])-duration)<.05
    assert int(video['nb_read_frames'])==duration*30
    assert video['codec_name']=='h264' and video['r_frame_rate']=='30/1'
    assert (video['width'],video['height'])==(1440,900)
    assert audio['channels']==2 and audio['sample_rate']=='48000'
    volume=subprocess.run(['ffmpeg','-hide_banner','-i',str(target),'-vn','-af','volumedetect','-f','null','-'],capture_output=True,text=True,check=True).stderr
    mean=float(re.search(r'mean_volume: ([-\d.]+) dB',volume)[1])
    peak=float(re.search(r'max_volume: ([-\d.]+) dB',volume)[1])
    assert -60<mean<-5 and peak<-.1, (id,mean,peak)
    for second in ((5,30,55) if not full else range(15,duration,60)):
        run(['ffmpeg','-v','error','-y','-ss',str(second),'-i',str(target),'-frames:v','1',str(WORK/f'{id}{suffix}_{second}.png')],WORK/f'{id}{suffix}_frame.log')
    raw.unlink()
    report=dict(id=id,title=entry['title'],file=target.name,duration=duration,width=1440,height=900,fps=30,frames=duration*30,audio_mean_db=mean,audio_peak_db=peak,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest())
    print(f"PREVIEW READY {number}: {entry['title']} ({target.stat().st_size/1048576:.1f} MiB)",flush=True)
    return report


def gallery(output: Path, reports: list[dict]) -> None:
    """Write a local, self-contained gallery linking every completed movie."""
    cards=''.join(f'<article><h2>{i+1}. {html.escape(r["title"])}</h2><video controls preload="none" src="{html.escape(r["file"])}"></video><a href="{html.escape(r["file"])}" download>Download · 1 minute</a></article>' for i,r in enumerate(reports))
    page='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Breathwork VR previews</title><style>body{background:#0b101c;color:#e6edf6;font:16px system-ui;margin:32px auto;max-width:1200px;padding:0 20px}h1{font-weight:500}p{color:#b6c3d3}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:28px}article{background:#141e2e;padding:18px;border-radius:16px}h2{font-size:20px;font-weight:500}video{width:100%;border-radius:8px;background:#000}a{display:block;color:#95d8ef;margin-top:12px}</style><h1>Breathwork VR</h1><p>'+str(len(reports))+' one-minute previews with music and breath cues. Each view slowly looks upward to show the reclining composition. These are desktop captures, not stereoscopic recordings.</p><main>'+cards+'</main></html>'
    (output/'index.html').write_text(page)
    (output/'manifest.json').write_text(json.dumps(reports,indent=2)+'\n')


def main() -> None:
    """Generate previews with two independent render workers and retain validation."""
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT/'build/previews')
    parser.add_argument('--only',help='Regenerate one experience and retain the rest of an existing gallery')
    parser.add_argument('--full',action='store_true',help='With --only, record the whole session looking forward as a separate movie')
    args=parser.parse_args()
    if args.full:
        if not args.only:
            raise ValueError('--full records one experience; pass --only')
        args.output.mkdir(parents=True,exist_ok=True)
        WORK.mkdir(parents=True,exist_ok=True)
        entries=json.loads((ROOT/'experiences/catalog.json').read_text())
        item=next(item for item in enumerate(entries,1) if item[1]['id']==args.only)
        report=render(item,args.output,full=True)
        (args.output/f"{report['file'][:-4]}.json").write_text(json.dumps(report,indent=2)+'\n')
        return
    args.output.mkdir(parents=True,exist_ok=True)
    WORK.mkdir(parents=True,exist_ok=True)
    entries=json.loads((ROOT/'experiences/catalog.json').read_text())
    items=[item for item in enumerate(entries,1) if not args.only or item[1]['id']==args.only]
    if not items:
        raise ValueError('Unknown experience ID')
    with ThreadPoolExecutor(max_workers=2) as pool:
        reports=list(pool.map(lambda item:render(item,args.output),items))
    manifest=args.output/'manifest.json'
    if args.only and manifest.exists():
        prior={r['id']:r for r in json.loads(manifest.read_text())}
        prior.update({r['id']:r for r in reports})
        reports=[prior[e['id']] for e in entries if e['id'] in prior]
    gallery(args.output,reports)
    print(f'{len(reports)} previews verified in gallery.',flush=True)


if __name__=='__main__':
    main()
