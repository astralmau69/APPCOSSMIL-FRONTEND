#!/usr/bin/env python3
"""Construye el ciclo de caminata de la instructora desde la lámina grande.

La lámina `Gemini_Generated_Image_r8zz8h…png` (2816×1536) trae, además del
giro de 360° y muchas expresiones, un ciclo de caminata de perfil mirando a la
derecha. Reusa el recorte por componentes conectados de
`extract_instructor_frames.py` (mismo quitado de damero) y, sobre las figuras
que salen de ahí, arma un ciclo LISTO PARA ANIMAR:

  - Todos los frames se alinean por la CABEZA (centro horizontal del tercio
    superior) y por los PIES (borde inferior), sobre un lienzo común. Así al
    reproducirlos la cabeza queda quieta y solo las piernas se mueven —
    sin temblor ni salto de tamaño.
  - Padding vertical 0: la figura más alta (piernas juntas) llena el lienzo,
    de modo que al mostrarse a la misma altura lógica que las poses de pie
    (recortadas a bbox) el cuerpo calza y la transición caminar→parada no
    "crece".

`WALK_IDS` son los índices que devuelve el volcado `--auto` de ESA lámina
(orden de lectura por bandas). Si se regenera la lámina, volcar con
`extract_instructor_frames.py --auto` y reajustar la lista.

    python3 tools/build_instructor_walk.py LAMINA.png --out assets/images
"""

import argparse
import os
import sys

from PIL import Image

from extract_instructor_frames import componentes, quitar_damero, COLORES

# Figuras del ciclo (perfil, mirando a la derecha) en el orden del volcado
# `--auto` de la lámina r8zz. 21 = pierna izquierda adelante … 27 = zancada.
WALK_IDS = [21, 22, 23, 24, 25, 26, 27]


def figuras_auto(lamina):
    """Repite el recorte por componentes de extract_instructor_frames --auto y
    devuelve las figuras recortadas a bbox, en orden de lectura."""
    im = Image.open(lamina).convert("RGBA")
    px, fondo, w, h = quitar_damero(im)
    comps = componentes(fondo, w, h, min_area=(w * h) // 900)
    cajas = []
    for c in comps:
        xs = [i % w for i in c]
        ys = [i // w for i in c]
        cajas.append((min(xs), min(ys), max(xs), max(ys), c))
    alto_medio = sum(b[3] - b[1] for b in cajas) / max(len(cajas), 1)
    cajas.sort(key=lambda b: (round(b[1] / max(alto_medio, 1)), b[0]))

    figuras = []
    for x0, y0, x1, y1, celdas in cajas:
        cw, chh = x1 - x0 + 1, y1 - y0 + 1
        fig = Image.new("RGBA", (cw, chh), (0, 0, 0, 0))
        datos = [(0, 0, 0, 0)] * (cw * chh)
        for i in celdas:
            x, y = i % w - x0, i // w - y0
            datos[y * cw + x] = px[i]
        fig.putdata(datos)
        figuras.append(fig)
    return figuras


def head_cx(im):
    """Centro horizontal del tercio superior (≈ la cabeza)."""
    w, h = im.size
    px = im.load()
    xs = []
    for y in range(int(h * 0.30)):
        for x in range(w):
            if px[x, y][3] > 40:
                xs.append(x)
    return sum(xs) / len(xs) if xs else w / 2


def construir(lamina, out_dir):
    figuras = figuras_auto(lamina)
    frames = []
    for n in WALK_IDS:
        if n - 1 >= len(figuras):
            sys.exit(f"La lámina no tiene la figura {n}; revisa WALK_IDS.")
        frames.append(figuras[n - 1].crop(figuras[n - 1].getbbox()))

    heads = [head_cx(f) for f in frames]
    left = max(heads)
    right = max(f.size[0] - h for f, h in zip(frames, heads))
    ch = max(f.size[1] for f in frames)
    cw = int(round(left + right))

    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for i, (f, hc) in enumerate(zip(frames, heads), start=1):
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ox = int(round(left - hc))  # cabeza → columna central
        oy = ch - f.size[1]         # pies → borde inferior
        canvas.alpha_composite(f, (ox, oy))
        canvas = canvas.quantize(colors=COLORES, method=Image.FASTOCTREE)
        ruta = os.path.join(out_dir, f"instructora_walk_{i}.png")
        canvas.save(ruta, optimize=True)
        kb = os.path.getsize(ruta) / 1024
        total += kb
        print(f"  walk {i} · {cw}x{ch}  {kb:5.1f} KB  {ruta}")
    print(f"  total {total:.1f} KB en {len(frames)} frames")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("lamina")
    ap.add_argument("--out", default="assets/images")
    a = ap.parse_args()
    if not os.path.exists(a.lamina):
        sys.exit(f"No existe: {a.lamina}")
    construir(a.lamina, a.out)
