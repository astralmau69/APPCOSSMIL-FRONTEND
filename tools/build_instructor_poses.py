#!/usr/bin/env python3
"""Extrae poses expresivas sueltas de la lámina grande de la instructora.

Reusa el recorte por componentes de `build_instructor_walk.py` (que a su vez usa
el quitado de damero de `extract_instructor_frames.py`) y guarda, con su nombre
definitivo, las casillas de gesto que la app anima además de las poses base.

`POSES` mapea el índice del volcado `--auto` de la lámina `6fesow…png` al nombre.
Se escalan a ~520 px de alto (las casillas nativas rondan 240 px porque la lámina
empaca ~120 poses) y se cuantizan a 256 colores, igual que el resto.

    python3 tools/build_instructor_poses.py LAMINA.png --out assets/images
"""

import argparse
import os
import sys

from PIL import Image

from build_instructor_walk import figuras_auto
from extract_instructor_frames import COLORES

ALTO = 520

# índice en el volcado --auto de la lámina 6fesow → nombre del asset
POSES = {
    38: "instructora_piensa",   # dedo al mentón, ojos cerrados: "déjame ver…"
    39: "instructora_festeja",  # riendo con las manos en alto: festejo
}


def construir(lamina, out_dir):
    figuras = figuras_auto(lamina)
    os.makedirs(out_dir, exist_ok=True)
    for idx, nombre in POSES.items():
        if idx - 1 >= len(figuras):
            sys.exit(f"La lámina no tiene la figura {idx}; revisa POSES.")
        fig = figuras[idx - 1]
        fig = fig.crop(fig.getbbox())
        ancho = round(fig.width * ALTO / fig.height)
        fig = fig.resize((ancho, ALTO), Image.LANCZOS)
        fig = fig.quantize(colors=COLORES, method=Image.FASTOCTREE)
        ruta = os.path.join(out_dir, f"{nombre}.png")
        fig.save(ruta, optimize=True)
        kb = os.path.getsize(ruta) / 1024
        print(f"  {idx:2d} → {nombre}  {fig.size[0]}x{fig.size[1]}  {kb:5.1f} KB")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("lamina")
    ap.add_argument("--out", default="assets/images")
    a = ap.parse_args()
    if not os.path.exists(a.lamina):
        sys.exit(f"No existe: {a.lamina}")
    construir(a.lamina, a.out)
