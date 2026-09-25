"""Corta las laminas del avatar v2 en piezas de rig, con pivote y manifest.

Entrada : tools/instructor_v2_src/*.png  (laminas evaluadas, ver su README)
Config  : tools/instructor_v2_cuts.json  (poligonos y pivotes, escritos a mano)
Salida  : assets/images/instructor/*.png + manifest.json
          tools/instructor_v2_src/_control/*.png  (control, FUERA del bundle)

La imagen de control recompone todas las piezas en su pose de reposo: si no se
ve identica a la A-pose original, el corte esta mal y se nota de inmediato.
Vive fuera de assets/ a proposito: pubspec declara la CARPETA entera, asi que
un PNG de diagnostico de 1 MB dentro de ella viaja en el APK.
"""

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CUTS = Path("tools/instructor_v2_cuts.json")
OUT = Path("assets/images/instructor")
# Diagnostico: fuera de assets/ para que no acabe en el APK.
CONTROL = Path("tools/instructor_v2_src/_control")


def alpha_from_magenta(im):
    """Quita el fondo magenta dejando alfa SUAVE y sin flecos.

    Un umbral duro deja un anillo magenta en los bordes antialiasados. Aqui se
    mide cuanto tira a magenta cada pixel (el magenta es el unico color donde
    R y B superan a G a la vez) y se usa eso como transparencia, desmultiplicando
    despues el color para recuperar el tono real del borde.
    """
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((np.minimum(r, b) - g) / 128.0, 0.0, 1.0)
    alpha = (1.0 - m)[..., None]
    bg = np.array([255.0, 0.0, 255.0])
    with np.errstate(divide="ignore", invalid="ignore"):
        col = np.where(alpha > 0.004, (a - m[..., None] * bg) / np.maximum(alpha, 1e-6), 0.0)
    out = np.concatenate(
        [np.clip(col, 0, 255), np.clip(alpha * 255.0, 0, 255)], axis=-1
    ).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def cut(src, poly):
    """Recorta el poligono de `src` conservando el alfa original."""
    mask = Image.new("L", src.size, 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in poly], fill=255)
    piece = Image.new("RGBA", src.size, (0, 0, 0, 0))
    piece.paste(src, (0, 0), mask)
    return piece


def save_quant(im, path):
    """PNG de 256 colores conservando el alfa, como el resto de assets del repo."""
    im.quantize(colors=256, method=Image.FASTOCTREE).save(path, optimize=True)


def _coverage(src, pieces_masks, body_top_y):
    """Que parte del CUERPO queda cubierta, y que parte por dos piezas.

    Solo cuenta de [body_top_y] para abajo: la cabeza no sale de esta lamina
    sino de la de caras, asi que arriba de esa linea no hay nada que cubrir y
    contarlo daria un falso hueco del 20%.
    """
    figura = np.asarray(src)[..., 3] > 40
    fig = figura.copy()
    fig[:body_top_y] = False
    total = int(fig.sum())
    if total == 0:
        return {"cubierto": 0.0, "solapado": 100.0, "peorPar": 100.0}
    masks = [m & fig for m in pieces_masks]
    veces = np.zeros(fig.shape, dtype=np.int16)
    for m in masks:
        veces += m.astype(np.int16)

    # El solape agregado siempre es alto: son las ocho articulaciones mas los
    # casquetes de hombro y cadera. Lo que si seria un fallo es que una pieza se
    # trague a otra, y eso lo dice el peor par.
    # El peor par se mide sobre las piezas ENTERAS, no sobre el recorte al
    # cuerpo: la antena vive casi toda por encima de la linea del cuello y
    # recortarla dejaria un sliver que da un falso 100%.
    enteras = [m & figura for m in pieces_masks]
    peor = 0.0
    for i in range(len(enteras)):
        for j in range(i + 1, len(enteras)):
            c = int((enteras[i] & enteras[j]).sum())
            if c == 0:
                continue
            menor = min(int(enteras[i].sum()), int(enteras[j].sum()))
            if menor:
                peor = max(peor, 100.0 * c / menor)
    return {
        "cubierto": round(100.0 * int((veces >= 1).sum()) / total, 2),
        "solapado": round(100.0 * int((veces >= 2).sum()) / total, 2),
        "peorPar": round(peor, 1),
    }


def build_body(cfg, src, s, pieces):
    """Las 10 piezas del cuerpo de la A-pose frontal."""
    x0, y0, _, _ = cfg["figureBBox"]
    by_name = {p["name"]: p for p in cfg["pieces"]}
    control = Image.new("RGBA", src.size, (0, 0, 0, 0))
    masks = []

    for p in sorted(cfg["pieces"], key=lambda q: q["z"]):
        piece = cut(src, p["polygon"])
        control.alpha_composite(piece)
        arr = np.asarray(piece)[..., 3] > 40
        masks.append(arr)
        bb = piece.getbbox()
        if bb is None:
            raise SystemExit(f"pieza vacia: {p['name']} (revisa el poligono)")
        crop = piece.crop(bb)
        w = max(1, round(crop.width * s))
        h = max(1, round(crop.height * s))
        save_quant(crop.resize((w, h), Image.LANCZOS), OUT / f"{p['name']}.png")

        px, py = p["pivot"]
        parent = p["parent"]
        if parent is None:
            pivot = [(px - x0) * s, (py - y0) * s]
        else:
            ppx, ppy = by_name[parent]["pivot"]
            pivot = [(px - ppx) * s, (py - ppy) * s]
        pieces.append(
            {
                "name": p["name"],
                "parent": parent,
                "asset": f"{p['name']}.png",
                "pivot": [round(v, 2) for v in pivot],
                "anchor": [round((px - bb[0]) * s, 2), round((py - bb[1]) * s, 2)],
                "size": [w, h],
                "z": p["z"],
            }
        )
        print(f"  {p['name']:<18} {w}x{h}")

    return control, _coverage(src, masks, cfg["bodyTopY"])


def _tiles(path, gw, gh):
    im = alpha_from_magenta(Image.open(path))
    tw, th = im.width // gw, im.height // gh
    out = []
    for i in range(gw * gh):
        c, r = i % gw, i // gw
        out.append(im.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th)))
    return out


def _anchor_of(t):
    """Centroide horizontal y coronilla de la figura de una casilla."""
    a = np.asarray(t)[..., 3] > 40
    ys, xs = np.where(a)
    return float(xs.mean()), float(ys.min())


def _helmet_width(t):
    """Ancho maximo del casco: el pico en el 45% superior de la figura."""
    a = np.asarray(t)[..., 3] > 40
    ys = np.where(a.any(axis=1))[0]
    y0, y1 = ys.min(), ys.max()
    top = a[y0 : y0 + max(1, int((y1 - y0) * 0.45))]
    return max(
        int(np.where(row)[0].max() - np.where(row)[0].min() + 1)
        for row in top
        if row.any()
    )


def _normalize(t, target_cx, target_ty, scale, size):
    """Lleva una casilla a la geometria de la casilla ancla de ojos.

    Las casillas de columnas distintas estan corridas hasta 14 px entre si. Sin
    esta normalizacion, el recorte fijo del ojo caeria en sitios distintos y el
    ojo saltaria al parpadear.
    """
    if abs(scale - 1.0) > 1e-4:
        t = t.resize((round(t.width * scale), round(t.height * scale)), Image.LANCZOS)
    cx, ty = _anchor_of(t)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(t, (round(target_cx - cx), round(target_ty - ty)))
    return out


def build_faces(cfg, s, pieces):
    """Cabeza + overlays de ojos y boca, registrados entre si.

    La cabeza NO sale de la A-pose: sale de la lamina de ojos, que tiene 0.0% de
    deriva entre sus casillas. Asi el registro de ojos y boca es exacto por
    construccion y el unico empalme aproximado cae en el cuello, tapado por el
    cuello alto y el barboquejo.
    """
    f = cfg["faces"]
    js = f["junctionScale"]
    gw, gh = f["grid"]
    eyes = _tiles(f["eyesSheet"], gw, gh)
    mouths = _tiles(f["mouthSheet"], gw, gh)
    size = eyes[0].size

    ancla = eyes[f["anchorTile"]]
    base_cx, base_ty = _anchor_of(ancla)
    # La lamina de boca esta a otra escala (2.0% medido): se iguala por casco.
    mouth_scale = _helmet_width(ancla) / _helmet_width(mouths[0])
    print(f"  escala lamina boca -> ojos: x{mouth_scale:.4f}")

    # --- cabeza: casilla ancla recortada bajo el cuello ---
    corte = f["neckY"] + f["cutBelowNeck"]
    head = ancla.crop((0, 0, size[0], corte))
    head = head.resize(
        (round(head.width * js * s), round(head.height * js * s)), Image.LANCZOS
    )
    bb = head.getbbox()
    head = head.crop(bb)
    save_quant(head, OUT / "cabeza.png")

    hx, hy = f["headPivotNative"]
    tpx, tpy = next(q["pivot"] for q in cfg["pieces"] if q["name"] == "torso")
    # El pivote de la cabeza es su cuello: donde la columna se estrecha.
    anchor_head = ((base_cx * js * s) - bb[0], (f["neckY"] * js * s) - bb[1])
    pieces.append(
        {
            "name": "cabeza",
            "parent": "torso",
            "asset": "cabeza.png",
            "pivot": [round((hx - tpx) * s, 2), round((hy - tpy) * s, 2)],
            "anchor": [round(anchor_head[0], 2), round(anchor_head[1], 2)],
            "size": [head.width, head.height],
            "z": 20,
        }
    )
    print(f"  {'cabeza':<18} {head.width}x{head.height}")

    def overlay(tile, rect, name, z, scale, transform=None):
        norm = _normalize(tile, base_cx, base_ty, scale, size)
        x, y, w, h = rect
        sub = norm.crop((x, y, x + w, y + h))
        if transform:
            sub = transform(sub)
        sub = sub.resize(
            (max(1, round(w * js * s)), max(1, round(h * js * s))), Image.LANCZOS
        )
        save_quant(sub, OUT / f"{name}.png")
        pieces.append(
            {
                "name": name,
                "parent": "cabeza",
                "asset": f"{name}.png",
                # relativo al pivote de la cabeza (cuello), en canonicas
                "pivot": [
                    round((x - base_cx) * js * s, 2),
                    round((y - f["neckY"]) * js * s, 2),
                ],
                "anchor": [0.0, 0.0],
                "size": [sub.width, sub.height],
                "z": z,
            }
        )

    for nom, idx in f["eyeTiles"].items():
        overlay(eyes[idx], f["eyeRect"], f"ojos_{nom}", 21, 1.0)

    # El medio parpadeo se SINTETIZA: la casilla 2 de la lamina salio duplicada
    # de la 0, asi que se fabrica aplastando el ojo abierto al 50% anclado en el
    # parpado superior. Sale mas consistente que un dibujo nuevo.
    def squash(im):
        half = im.resize((im.width, max(1, im.height // 2)), Image.LANCZOS)
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.alpha_composite(half, (0, 0))
        return out

    overlay(eyes[f["eyeTiles"]["abiertos"]], f["eyeRect"], "ojos_medio", 21, 1.0,
            transform=squash)

    for i in f["mouthTiles"]:
        overlay(mouths[i], f["mouthRect"], f"boca_{i}", 22, mouth_scale)

    print(f"  {'ojos':<18} 6 variantes")
    print(f"  {'bocas':<18} {len(f['mouthTiles'])} variantes")


def _wrist_width(t, pct_from_bottom):
    """Ancho de la muneca: fila a `pct` por encima de la base de la figura."""
    a = np.asarray(t)[..., 3] > 40
    ys = np.where(a.any(axis=1))[0]
    y0, y1 = ys.min(), ys.max()
    y = int(y1 - (y1 - y0) * pct_from_bottom / 100.0)
    cols = np.where(a[y])[0]
    return (int(cols.max() - cols.min() + 1) if len(cols) else 1), y


def build_hands(cfg, pieces):
    """Las manos de gesto: alternativas del hueso de la mano en reposo.

    Tres normalizaciones, y las tres hacen falta para que la mano caiga DONDE
    ESTA LA MUNECA en vez de suelta al lado del brazo:

    1. **Escala** por ancho de muneca contra `mano_der` (que sale de la A-pose y
       encaja exacto con su antebrazo). La lamina traia 7.1% de deriva.
    2. **Recorte en la muneca**: las casillas de la lamina 3 vienen con un trozo
       de manga. Ese trozo se pinta ENCIMA del antebrazo real (z mayor) y con
       otro camuflaje, asi que se corta.
    3. **Giro al eje del antebrazo**: la lamina dibuja las manos apuntando hacia
       ARRIBA, mientras el antebrazo de la A-pose corre a 45 grados abajo-derecha.
       Sin este giro el guante sale rotado 135 grados respecto al brazo del que
       cuelga — y como la mano propia del rig queda oculta, el antebrazo termina
       en munon.
    """
    h = cfg["hands"]
    gw, gh = h["grid"]
    tiles = _tiles(h["sheet"], gw, gh)
    base = next(p for p in pieces if p["name"] == "mano_der")
    objetivo = base["size"][0] * 0.62  # la muneca es ~62% del ancho del puno

    # Eje codo->muneca de la A-pose: la mano prolonga esa direccion.
    eje = math.degrees(math.atan2(base["pivot"][1], base["pivot"][0]))
    # Las casillas apuntan hacia arriba (-90 grados en pantalla, con y hacia
    # abajo). PIL gira en sentido antihorario, de ahi el signo.
    giro = -(eje + 90.0)

    for nombre, idx in h["tiles"].items():
        t = tiles[idx]
        t = t.crop(t.getbbox())
        w, _ = _wrist_width(t, h["wristFromBottomPct"])
        k = objetivo / max(1, w)
        t = t.resize(
            (max(1, round(t.width * k)), max(1, round(t.height * k))), Image.LANCZOS
        )
        wn, yn = _wrist_width(t, h["wristFromBottomPct"])
        cols = np.where(np.asarray(t)[..., 3][yn] > 40)[0]
        cx = float((cols.min() + cols.max()) / 2) if len(cols) else t.width / 2

        # (2) fuera la manga: todo lo que cuelga por debajo de la muneca.
        t = t.crop((0, 0, t.width, min(t.height, int(yn) + 2)))
        wy = float(yn)

        # (3) giro al eje del brazo, con la muneca reproyectada a mano.
        ancho, alto = t.width, t.height
        t = t.rotate(giro, resample=Image.BICUBIC, expand=True)
        rad = math.radians(giro)
        cxo, cyo = (ancho - 1) / 2.0, (alto - 1) / 2.0
        cxn, cyn = (t.width - 1) / 2.0, (t.height - 1) / 2.0
        dx, dy = cx - cxo, wy - cyo
        wx = cxn + dx * math.cos(rad) + dy * math.sin(rad)
        wy = cyn - dx * math.sin(rad) + dy * math.cos(rad)

        bb = t.getbbox()
        t = t.crop(bb)
        wx -= bb[0]
        wy -= bb[1]

        name = f"mano_g_{nombre}"
        save_quant(t, OUT / f"{name}.png")
        pieces.append(
            {
                "name": name,
                "parent": base["parent"],
                "asset": f"{name}.png",
                "pivot": list(base["pivot"]),
                "anchor": [round(wx, 2), round(wy, 2)],
                "size": [t.width, t.height],
                "z": base["z"],
                "wrist": wn,
            }
        )
        print(f"  {name:<18} {t.width}x{t.height}  (muneca {wn} px, k={k:.3f}, giro {giro:.0f})")


def build_profile(cfg):
    """Segundo rig, de perfil, para la entrada caminando."""
    pr = cfg["profile"]
    src = alpha_from_magenta(Image.open(pr["source"]))
    x0, y0, x1, y1 = pr["figureBBox"]
    fh = y1 - y0 + 1
    s = cfg["canonicalHeight"] / fh
    by_name = {p["name"]: p for p in pr["pieces"]}
    control = Image.new("RGBA", src.size, (0, 0, 0, 0))
    masks, out = [], []

    for p in sorted(pr["pieces"], key=lambda q: q["z"]):
        piece = cut(src, p["polygon"])
        control.alpha_composite(piece)
        masks.append(np.asarray(piece)[..., 3] > 40)
        bb = piece.getbbox()
        if bb is None:
            raise SystemExit(f"pieza de perfil vacia: {p['name']}")
        crop = piece.crop(bb)
        w = max(1, round(crop.width * s))
        h = max(1, round(crop.height * s))
        save_quant(crop.resize((w, h), Image.LANCZOS), OUT / f"{p['name']}.png")

        px, py = p["pivot"]
        parent = p["parent"]
        if parent is None:
            pivot = [(px - x0) * s, (py - y0) * s]
        else:
            ppx, ppy = by_name[parent]["pivot"]
            pivot = [(px - ppx) * s, (py - ppy) * s]
        # `shiftX` mueve donde se DIBUJA la pieza sin mover su pivote, y es lo
        # que endereza la caminata: la lamina dibuja las dos piernas separadas
        # (postura de pie con los pies abiertos), asi que cada muslo traia su
        # propia cadera, a 78 px canonicos de la otra. Rotaciones simetricas
        # sobre dos centros distintos dan zancadas de tamanos distintos: una
        # medida 2.6x la otra. Con las dos piernas colgando de la cadera real
        # (la del torso) el ciclo sale simetrico.
        #
        # Los pivotes de una cadena desplazada se declaran YA en el sistema
        # desplazado; de ahi el `- shift` al calcular el ancla, que se mide
        # contra el recorte sin desplazar.
        shift = p.get("shiftX", 0)
        out.append(
            {
                "name": p["name"],
                "parent": parent,
                "asset": f"{p['name']}.png",
                "pivot": [round(v, 2) for v in pivot],
                "anchor": [
                    round((px - shift - bb[0]) * s, 2),
                    round((py - bb[1]) * s, 2),
                ],
                "size": [w, h],
                "z": p["z"],
            }
        )
        print(f"  {p['name']:<18} {w}x{h}")

    control.crop((x0, y0, x1 + 1, y1 + 1)).save(CONTROL / "control_perfil.png")
    fig = np.asarray(src)[..., 3] > 40
    cub = np.zeros(fig.shape, bool)
    for m in masks:
        cub |= m
    return {
        "aspect": round((x1 - x0 + 1) / fh, 4),
        "cubierto": round(100.0 * int((cub & fig).sum()) / max(1, int(fig.sum())), 2),
        "pieces": out,
    }


def main():
    cfg = json.loads(CUTS.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    CONTROL.mkdir(parents=True, exist_ok=True)
    src = alpha_from_magenta(Image.open(cfg["source"]))
    x0, y0, x1, y1 = cfg["figureBBox"]
    fh = y1 - y0 + 1
    s = cfg["canonicalHeight"] / fh

    pieces = []
    control, coverage = build_body(cfg, src, s, pieces)
    build_faces(cfg, s, pieces)
    build_hands(cfg, pieces)
    profile = build_profile(cfg)
    control.crop((x0, y0, x1 + 1, y1 + 1)).save(CONTROL / "control.png")

    (OUT / "manifest.json").write_text(
        json.dumps(
            {
                "canonicalHeight": cfg["canonicalHeight"],
                "aspect": round((x1 - x0 + 1) / fh, 4),
                "coverage": coverage,
                "profile": profile,
                "pieces": pieces,
            },
            indent=2,
            ensure_ascii=False,
        ),
        encoding="utf-8",
    )

    kb = sum(
        f.stat().st_size for f in OUT.glob("*.png") if not f.name.startswith("_")
    ) / 1024
    print(f"\n{len(pieces)} piezas -> {OUT}")
    print(f"cobertura de la figura : {coverage['cubierto']:.1f}%")
    print(f"solape entre piezas    : {coverage['solapado']:.1f}%")
    print(f"peso total             : {kb:.0f} KB")


if __name__ == "__main__":
    main()
