#!/usr/bin/env python3
"""Recorta las poses de la instructora desde las láminas generadas por Gemini.

Las láminas traen un damero gris/blanco que PARECE transparencia pero son
píxeles opacos, así que hay que recortarlo de verdad. El fondo se detecta por
inundación desde los bordes con un predicado de "gris y claro": al ir por
conectividad, lo blanco del interior del personaje (la tablet) queda a salvo
aunque cumpla el mismo predicado.

Después se separan los componentes conectados para quedarse solo con la
figura: así los números de cada casilla se descartan solos por tamaño.

Las poses que usa la app salen de la lámina de 8 casillas (2×4), la de mayor
resolución. Para regenerarlas con los nombres definitivos:

    python3 tools/extract_instructor_frames.py LAMINA.png 2 4 \
        --out assets/images --named

Sin `--named` vuelca las casillas numeradas (útil para inspeccionar una lámina
nueva y decidir qué sirve).
"""

import argparse
import os
import sys
from collections import deque

from PIL import Image

# Fondo = píxel casi acromático y claro. El uniforme, el pelo y la piel quedan
# muy por debajo del umbral de brillo; la tablet lo cumple pero está en el
# interior y la inundación no la alcanza.
MAX_CROMA = 18
MIN_SUMA = 540

# Alto final y paleta. A 700 px sobra para el mayor tamaño en pantalla (el
# diálogo en tablet ronda 180 px lógicos ≈ 540 px a 3×), y la paleta indexada
# baja cada pose de ~350 KB a ~68 KB sin pérdida visible: son ilustraciones de
# color plano, justo lo que mejor cuantiza.
ALTO_FINAL = 700
COLORES = 256

# Qué casilla de la lámina 2×4 es cada pose de la app. Cambiar esto es lo único
# necesario si llega una lámina nueva con otro orden.
POSES = {
    2: "instructora_saludo",     # saludo militar — presentación del tutorial
    4: "instructora_parpadeo",   # igual que "explica" con los ojos cerrados
    6: "instructora_explica",    # señalando la tablet — dando instrucciones
    7: "instructora_celebra",    # tablet con visto verde — misión cumplida
    8: "instructora_reposo",     # de pie, relajada — coach minimizado
}


def es_fondo(p):
    r, g, b = p[0], p[1], p[2]
    return (max(r, g, b) - min(r, g, b)) <= MAX_CROMA and (r + g + b) >= MIN_SUMA


def quitar_damero(celda):
    """Devuelve (píxeles, ancho, alto) con el fondo ya en alpha 0."""
    celda = celda.convert("RGBA")
    w, h = celda.size
    px = list(celda.getdata())
    fondo = bytearray(w * h)

    cola = deque()
    for x in range(w):
        for y in (0, h - 1):
            cola.append(y * w + x)
    for y in range(h):
        for x in (0, w - 1):
            cola.append(y * w + x)

    while cola:
        i = cola.popleft()
        if fondo[i] or not es_fondo(px[i]):
            continue
        fondo[i] = 1
        x, y = i % w, i // w
        if x > 0:
            cola.append(i - 1)
        if x < w - 1:
            cola.append(i + 1)
        if y > 0:
            cola.append(i - w)
        if y < h - 1:
            cola.append(i + w)

    # Una pasada de erosión sobre el fleco: los píxeles del contorno mezclados
    # con el damero por el antialias también se van, o queda un halo claro.
    fleco = []
    for i in range(w * h):
        if fondo[i] or not es_fondo(px[i]):
            continue
        x, y = i % w, i // w
        vecinos = []
        if x > 0:
            vecinos.append(i - 1)
        if x < w - 1:
            vecinos.append(i + 1)
        if y > 0:
            vecinos.append(i - w)
        if y < h - 1:
            vecinos.append(i + w)
        if any(fondo[v] for v in vecinos):
            fleco.append(i)
    for i in fleco:
        fondo[i] = 1

    return px, fondo, w, h


def componentes(fondo, w, h, min_area):
    """Componentes conectados de lo que NO es fondo, de mayor a menor."""
    visto = bytearray(w * h)
    salida = []
    for inicio in range(w * h):
        if fondo[inicio] or visto[inicio]:
            continue
        cola = deque([inicio])
        visto[inicio] = 1
        celdas = []
        while cola:
            i = cola.popleft()
            celdas.append(i)
            x, y = i % w, i // w
            for v, ok in (
                (i - 1, x > 0),
                (i + 1, x < w - 1),
                (i - w, y > 0),
                (i + w, y < h - 1),
            ):
                if ok and not visto[v] and not fondo[v]:
                    visto[v] = 1
                    cola.append(v)
        if len(celdas) >= min_area:
            salida.append(celdas)
    salida.sort(key=len, reverse=True)
    return salida


def recortar(lamina, filas, cols, out_dir, prefijo, con_nombres):
    im = Image.open(lamina).convert("RGBA")
    W, H = im.size
    cw, ch = W // cols, H // filas
    os.makedirs(out_dir, exist_ok=True)

    n = 0
    for fila in range(filas):
        for col in range(cols):
            n += 1
            if con_nombres and n not in POSES:
                continue
            celda = im.crop((col * cw, fila * ch, (col + 1) * cw, (fila + 1) * ch))
            px, fondo, w, h = quitar_damero(celda)

            # Solo la figura: los números de casilla son componentes pequeños.
            comps = componentes(fondo, w, h, min_area=(w * h) // 200)
            if not comps:
                print(f"  {n:2d} · vacía, se omite")
                continue
            figura = set(comps[0])

            salida = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            datos = [
                px[i] if i in figura else (0, 0, 0, 0) for i in range(w * h)
            ]
            salida.putdata(datos)
            salida = salida.crop(salida.getbbox())

            if salida.height != ALTO_FINAL:
                ancho = round(salida.width * ALTO_FINAL / salida.height)
                salida = salida.resize((ancho, ALTO_FINAL), Image.LANCZOS)
            salida = salida.quantize(colors=COLORES, method=Image.FASTOCTREE)

            nombre = POSES[n] if con_nombres else f"{prefijo}{n:02d}"
            ruta = os.path.join(out_dir, f"{nombre}.png")
            salida.save(ruta, optimize=True)
            kb = os.path.getsize(ruta) / 1024
            print(f"  {n:2d} · {salida.size[0]}x{salida.size[1]}  {kb:5.1f} KB  {ruta}")


def recortar_auto(lamina, out_dir, prefijo, alto_final):
    """Recorta sin asumir rejilla: quita el fondo de la lámina entera y separa
    cada figura por componentes conectados.

    Hace falta cuando las láminas no traen las casillas alineadas (pasa cuando
    la IA mete filas de distinta altura): una rejilla fija parte los personajes
    por la mitad. Los números de casilla caen solos por tamaño.
    """
    im = Image.open(lamina).convert("RGBA")
    os.makedirs(out_dir, exist_ok=True)
    px, fondo, w, h = quitar_damero(im)

    # Una figura ocupa bastante más que un número. El umbral va en proporción
    # a la lámina para que sirva con cualquier resolución.
    comps = componentes(fondo, w, h, min_area=(w * h) // 900)

    # Orden de lectura: por bandas horizontales y dentro de cada banda por X.
    cajas = []
    for c in comps:
        xs = [i % w for i in c]
        ys = [i // w for i in c]
        cajas.append((min(xs), min(ys), max(xs), max(ys), c))
    if not cajas:
        print("  sin figuras")
        return
    alto_medio = sum(b[3] - b[1] for b in cajas) / len(cajas)
    cajas.sort(key=lambda b: (round(b[1] / max(alto_medio, 1)), b[0]))

    for n, (x0, y0, x1, y1, celdas) in enumerate(cajas, start=1):
        cw, chh = x1 - x0 + 1, y1 - y0 + 1
        fig = Image.new("RGBA", (cw, chh), (0, 0, 0, 0))
        datos = [(0, 0, 0, 0)] * (cw * chh)
        for i in celdas:
            x, y = i % w - x0, i // w - y0
            datos[y * cw + x] = px[i]
        fig.putdata(datos)

        if alto_final and fig.height != alto_final:
            ancho = round(fig.width * alto_final / fig.height)
            fig = fig.resize((ancho, alto_final), Image.LANCZOS)
        fig = fig.quantize(colors=COLORES, method=Image.FASTOCTREE)

        ruta = os.path.join(out_dir, f"{prefijo}{n:02d}.png")
        fig.save(ruta, optimize=True)
        kb = os.path.getsize(ruta) / 1024
        print(f"  {n:2d} · {fig.size[0]}x{fig.size[1]}  {kb:5.1f} KB  {ruta}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("lamina")
    ap.add_argument("filas", type=int, nargs="?", default=0)
    ap.add_argument("columnas", type=int, nargs="?", default=0)
    ap.add_argument("--out", default="frames")
    ap.add_argument("--prefix", default="pose")
    ap.add_argument(
        "--named",
        action="store_true",
        help="exporta solo las casillas de POSES, con su nombre definitivo",
    )
    ap.add_argument(
        "--auto",
        action="store_true",
        help="detecta cada figura por componentes en vez de asumir rejilla",
    )
    ap.add_argument(
        "--alto",
        type=int,
        default=ALTO_FINAL,
        help="alto final en px; 0 conserva el nativo (para láminas de baja "
        "resolución, donde ampliar solo emborrona)",
    )
    a = ap.parse_args()
    if not os.path.exists(a.lamina):
        sys.exit(f"No existe: {a.lamina}")
    if a.auto:
        recortar_auto(a.lamina, a.out, a.prefix, a.alto)
    else:
        recortar(a.lamina, a.filas, a.columnas, a.out, a.prefix, a.named)
