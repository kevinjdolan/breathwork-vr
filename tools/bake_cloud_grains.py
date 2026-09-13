"""Bake fine cloud-grain opacity so mobile fragments avoid repeated procedural noise."""
from pathlib import Path
import numpy as np
from PIL import Image


def main() -> None:
    """Produce a soft, densely stippled cloud sprite with transparent edges."""
    size=128
    y,x=np.mgrid[:size,:size].astype(float)
    p=np.stack([(x+.5)/size*2-1,(y+.5)/size*2-1],axis=-1)
    cells=p*3
    cell=np.floor(cells)
    seed=np.mod(np.sin(cell[:,:,0]*12.9898+cell[:,:,1]*78.233+31.7)*43758.5453,1)
    local=np.mod(cells,1)-.5
    local[:,:,0]-=(seed-.5)*.34
    local[:,:,1]-=(np.mod(seed*7.13,1)-.5)*.34
    radius=np.linalg.norm(local,axis=-1)
    t=np.clip((radius-.09)/.25,0,1)
    fleck=1-t*t*(3-2*t)
    edge=np.linalg.norm(p,axis=-1)
    t=np.clip((edge-.38)/.62,0,1)
    alpha=(1-t*t*(3-2*t))*(.20+.80*fleck)
    rgb=np.full((size,size,4),255,dtype=np.uint8)
    rgb[:,:,3]=np.uint8(alpha*255)
    target=Path(__file__).resolve().parents[1]/'experiences/prismatic_sanctuary/cloud_grain.png'
    Image.fromarray(rgb).save(target)


if __name__=='__main__':
    main()
