"""Bake escape-time and orbit-trap fields for low-cost stereo Mandelbrot rendering."""
from pathlib import Path
import numpy as np
from PIL import Image


def main() -> None:
    """Bake four numeric fields whose runtime palettes can evolve independently."""
    root=Path(__file__).resolve().parents[1]/'experiences/fractal_garden/fields'
    root.mkdir(exist_ok=True)
    regions=[(-.65,0,3.3),(-.745,.186,.055),(-.7435,.1314,.015),(-.16,1.035,.13)]
    for index,(cx,cy,span) in enumerate(regions):
        size=1536
        x=np.linspace(cx-span/2,cx+span/2,size)
        y=np.linspace(cy-span/2,cy+span/2,size)
        c=x[None,:]+1j*y[:,None]
        z=np.zeros_like(c)
        alive=np.ones(c.shape,dtype=bool)
        escape=np.zeros(c.shape)
        trap=np.full(c.shape,10.0)
        for step in range(240):
            z[alive]=z[alive]*z[alive]+c[alive]
            mag=np.abs(z)
            trap[alive]=np.minimum(trap[alive],np.abs(z[alive].real)*.5+np.abs(z[alive].imag)*.5)
            escaped=alive & (mag>4)
            escape[escaped]=step+1-np.log2(np.log2(mag[escaped]))
            alive[escaped]=False
        # Store geometric fields, not a fixed palette: runtime supplies evolving color.
        red=np.clip(escape/240,0,1)
        green=np.clip(np.exp(-trap*5),0,1)
        blue=alive.astype(float)
        rgb=np.stack([red,green,blue],axis=-1)
        Image.fromarray(np.uint8(rgb*255)).save(root/f'mandelbrot_{index}.png')
        print(index,flush=True)


if __name__ == "__main__":
    main()
