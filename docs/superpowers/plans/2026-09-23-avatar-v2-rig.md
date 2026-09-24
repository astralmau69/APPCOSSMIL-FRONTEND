# Avatar v2 de la instructora — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el avatar de la instructora del tutorial por el personaje nuevo (casco táctico + antiparras ámbar), animado con un rig de recortes que interpola movimiento en tiempo real en vez de fundir dibujos enteros.

**Architecture:** Un pipeline en Python corta las 6 láminas fuente en piezas con pivote y emite un `manifest.json`. En Dart, tres unidades de datos puros (`InstructorRig`, `InstructorClip`, `solveInstructorPose`) calculan la matriz de cada hueso por fotograma, y un `CustomPainter` las dibuja. `TutorialInstructor` conserva su API pública exacta: cambian sus tripas, no sus consumidores.

**Tech Stack:** Flutter 3.41.4 / Dart 3.11.1 (SDK `^3.8.1`), Cupertino, `flutter_test`. Python 3.12 con Pillow + numpy para el pipeline de arte. Sin dependencias nuevas en `pubspec.yaml`.

**Spec:** `docs/superpowers/specs/2026-09-23-avatar-v2-rig-design.md`

## Global Constraints

- **Paquete Dart:** `cossmil`. Los imports son `package:cossmil/core/...`.
- **Sin dependencias nuevas.** Nada de `rive`, `lottie` ni `spine`. El rig es Flutter puro.
- **Idioma:** UI y comentarios en español. Los identificadores en inglés salvo donde el repo ya use español (`InstructorPose.reposo`, `explica`…).
- **Tokens de diseño obligatorios:** `AppDurations` y `AppCurves` de `lib/core/theme/app_constants.dart`. Nunca `Duration(milliseconds: 300)` crudo en código nuevo de animación.
- **Figura canónica: 800 px de alto.** La A-pose nativa mide 1490 px → factor 0.5369.
- **Assets nuevos:** `assets/images/instructor/`, cuantizados a 256 colores (FASTOCTREE). **Hay que declarar esa carpeta en `pubspec.yaml`**: Flutter no incluye subcarpetas de una carpeta ya declarada.
- **No tocar la capa de comportamiento existente.** `_settle()`, `_blinkTimer`, `_syncIdle`, `_syncTalk`, `_syncSpeak` y sus constantes (`_idleCalm` 2600 ms, `_idleParty` 1500 ms, `_blinkMinGap` 2600, `_blinkJitter` 3200, `_blinkDur` 130, `_winkDur` 780, `_winkEveryN` 4, `_speakBobDefault` 650, `_walkDur` 1300) se conservan verbatim. Sólo cambia a quién alimentan.
- **Nunca apagar un bucle senoidal con `ctrl.value = 0`.** Usar el `_settle()` existente. Memoria: [[animaciones-parar-bucles-sin-saltos]].
- **`AnimatedSize` con `Duration.zero` revienta en layout.** En modo instantáneo devolver el hijo crudo.
- **reduce-motion** (`MediaQuery.disableAnimations`) se respeta en todo clip nuevo.
- **Logging:** `AppLogger`, nunca `print`.
- **Tests de widget:** `TestWidgetsFlutterBinding.ensureInitialized()` + mock de `flutter_secure_storage`; doble `pump()` antes de tapear dentro de un `ScaleTransition`. Memoria: [[tests-binding-secure-storage]].
- **El set viejo se borra en la última tarea**, nunca antes.

## Review Focus

Cinco cosas que el spec implica y que ninguna tarea testearía por su cuenta. Cada línea tiene su test asignado a la tarea dueña del código.

1. **reduce-motion activo** — con animaciones deshabilitadas la instructora debe quedar estática en su pose, sin bucle de respiración, sin parpadeo y sin caminata. Si un clip sigue corriendo, se le entrega movimiento a alguien que lo apagó por vértigo. → test en Task 8.
2. **Pieza que no carga** — si un PNG del manifest falta o está corrupto, el painter debe dibujar el resto y no lanzar. Un tutorial en blanco es peor que una instructora sin antena. → test en Task 7.
3. **Cambio de pose mientras suena la voz** — conmutar de clip a mitad de una locución no debe teletransportar la figura; es exactamente el tirón que `_settle()` existe para evitar. → test en Task 9.
4. **`height` extremo** — `charH` va de 124 px (teléfono chico) a 186 px, y en horizontal `context.height * 0.30` puede caer mucho más. Con `height` muy chico o cero el rig no debe dividir por cero ni escalar en negativo. → test en Task 7.
5. **Desmontaje a mitad de animación** — al desmontar con clips corriendo, los tickers se liberan y no queda ningún `setState` posterior al `dispose`. → test en Task 8.

---

## File Structure

**Pipeline de arte (Python, no se empaqueta en la app):**

| Archivo | Responsabilidad |
|---|---|
| `tools/instructor_v2_cuts.json` | Config de corte: polígonos, pivotes, jerarquía. Escrito a mano, versionado |
| `tools/build_instructor_v2.py` | Corta, normaliza, cuantiza y emite el manifest + la imagen de control |
| `tools/verify_instructor_v2.py` | Valida el manifest y los PNG. Sale distinto de cero si algo falla |

**Rig en Dart:**

| Archivo | Responsabilidad |
|---|---|
| `lib/core/animations/instructor/instructor_rig.dart` | `InstructorBone`, `InstructorRig`, carga del manifest. Datos puros |
| `lib/core/animations/instructor/instructor_clip.dart` | `BoneKey`, `BoneTransform`, `InstructorClip`, `ClipLayer`, `sampleTrack`. Datos puros |
| `lib/core/animations/instructor/instructor_solver.dart` | `solveInstructorPose`. Función pura |
| `lib/core/animations/instructor/instructor_clips.dart` | El catálogo de clips (idle, parpadeo, hablar, gestos, caminata) |
| `lib/core/animations/instructor/instructor_rig_view.dart` | `InstructorRigView`: `CustomPainter` + carga de `ui.Image` |
| `lib/core/widgets/tutorial_instructor.dart` | La capa pública. Misma API, tripas nuevas |

**Assets:** `assets/images/instructor/*.png` + `assets/images/instructor/manifest.json`.

---

### Task 1: Verificador y corte del cuerpo

**Files:**
- Create: `tools/verify_instructor_v2.py`
- Create: `tools/build_instructor_v2.py`
- Create: `tools/instructor_v2_cuts.json`
- Output: `assets/images/instructor/torso.png`, `brazo_sup_izq.png`, `brazo_sup_der.png`, `antebrazo_izq.png`, `antebrazo_der.png`, `muslo_izq.png`, `muslo_der.png`, `pantorrilla_izq.png`, `pantorrilla_der.png`, `antena.png`, `manifest.json`

**Interfaces:**
- Produces: `assets/images/instructor/manifest.json` con la forma
  ```json
  {
    "canonicalHeight": 800,
    "aspect": 0.6315,
    "pieces": [
      {"name":"torso","parent":null,"asset":"torso.png",
       "pivot":[0.0,0.0],"anchor":[112.0,18.0],"size":[236,298],"z":10}
    ]
  }
  ```
  `pivot` es la posición del hueso en coordenadas de la figura canónica relativa a su padre; `anchor` es dónde cae ese pivote dentro del PNG de la pieza; `z` el orden de dibujo (mayor = más adelante).

**Datos de partida medidos** (A-pose nativa 1490 px de alto, bbox `x 42..982, y 12..1501`). Los tramos por fila salieron de medir la máscara:

| % altura | y | tramos (inicio-fin) |
|---|---|---|
| 40% | 608 | `193-338 │ 346-826` |
| 42% | 637 | `176-313 │ 351-686 │ 710-848` |
| 46% | 697 | `127-264 │ 315-713 │ 760-896` |
| 50% | 757 | `92-189 │ 302-724 │ 835-932` |
| 54% | 816 | `44-149 │ 320-695 │ 875-980` |
| 58% | 876 | `87-117 │ 275-740 │ 908-936` |
| 62% | 935 | `282-506 │ 518-744` |
| 64% | 965 | `281-499 │ 526-729` |

Landmarks: cuello `y=381` (ancho 158), hombro `y=444`, rodilla `y≈1100`, suelas `y=1501`. Antena: blob suelto en `x 623-636`, `y 339..399`.

- [ ] **Step 1: Escribir el verificador (falla porque no hay manifest)**

Crear `tools/verify_instructor_v2.py`:

```python
"""Valida las piezas del avatar v2. Sale != 0 si algo no cumple."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path("assets/images/instructor")
FAILS = []


def check(cond, msg):
    if cond:
        print(f"  OK   {msg}")
    else:
        print(f"  FALLA {msg}")
        FAILS.append(msg)


def main():
    mf = OUT / "manifest.json"
    check(mf.exists(), f"existe {mf}")
    if not mf.exists():
        return finish()

    m = json.loads(mf.read_text(encoding="utf-8"))
    check(m.get("canonicalHeight") == 800, "canonicalHeight == 800")
    check(0.5 < m.get("aspect", 0) < 0.9, "aspect entre 0.5 y 0.9")

    names = [p["name"] for p in m["pieces"]]
    check(len(names) == len(set(names)), "nombres de pieza únicos")

    for p in m["pieces"]:
        f = OUT / p["asset"]
        check(f.exists(), f"existe {p['asset']}")
        if not f.exists():
            continue
        im = Image.open(f).convert("RGBA")
        a = np.asarray(im)
        check(a.shape[1] == p["size"][0] and a.shape[0] == p["size"][1],
              f"{p['name']}: size del manifest coincide con el PNG")
        check(a[..., 3].max() > 0, f"{p['name']}: no está vacía")
        # nada de magenta residual
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        halo = ((r > 170) & (g < 130) & (b > 170) & (al > 20)).sum()
        check(halo < 0.001 * al.size, f"{p['name']}: sin halo magenta ({halo} px)")
        ax, ay = p["anchor"]
        check(0 <= ax <= p["size"][0] and 0 <= ay <= p["size"][1],
              f"{p['name']}: anchor dentro del PNG")
        if p["parent"] is not None:
            check(p["parent"] in names, f"{p['name']}: padre '{p['parent']}' existe")

    # sin ciclos
    parent = {p["name"]: p["parent"] for p in m["pieces"]}
    for n in names:
        seen, cur = set(), n
        while cur is not None:
            if cur in seen:
                check(False, f"ciclo en la jerarquía en '{n}'")
                break
            seen.add(cur)
            cur = parent.get(cur)

    return finish()


def finish():
    print()
    if FAILS:
        print(f"{len(FAILS)} FALLA(S)")
        return 1
    print("todo OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Correrlo para ver que falla**

Run: `python tools/verify_instructor_v2.py`
Expected: FALLA — `existe assets/images/instructor/manifest.json`, salida 1.

- [ ] **Step 3: Escribir la config de corte**

Crear `tools/instructor_v2_cuts.json`. Los polígonos van en coordenadas nativas de `lamina0_apose_frontal.png`. Derivá cada uno de la tabla de tramos de arriba: el borde interior de un brazo es la columna de inicio del tramo del torso, el exterior es la del tramo del brazo. Los `pivot` en coordenadas nativas también; el script los convierte a canónicas.

```json
{
  "source": "tools/instructor_v2_src/lamina0_apose_frontal.png",
  "canonicalHeight": 800,
  "figureBBox": [42, 12, 982, 1501],
  "pieces": [
    {"name": "torso", "parent": null, "z": 10,
     "pivot": [512, 935],
     "polygon": [[300,370],[730,370],[744,935],[282,935]]},
    {"name": "antena", "parent": "torso", "z": 5,
     "pivot": [629, 399],
     "polygon": [[618,334],[641,334],[641,404],[618,404]]},
    {"name": "brazo_sup_der", "parent": "torso", "z": 8,
     "pivot": [700, 450],
     "polygon": [[640,420],[790,420],[896,697],[760,697]]},
    {"name": "antebrazo_der", "parent": "brazo_sup_der", "z": 8,
     "pivot": [828, 690],
     "polygon": [[760,690],[896,690],[936,880],[880,880]]},
    {"name": "brazo_sup_izq", "parent": "torso", "z": 12,
     "pivot": [324, 450],
     "polygon": [[234,420],[384,420],[264,697],[127,697]]},
    {"name": "antebrazo_izq", "parent": "brazo_sup_izq", "z": 12,
     "pivot": [196, 690],
     "polygon": [[127,690],[264,690],[117,880],[80,880]]},
    {"name": "muslo_izq", "parent": "torso", "z": 9,
     "pivot": [393, 940],
     "polygon": [[276,930],[510,930],[505,1115],[281,1115]]},
    {"name": "pantorrilla_izq", "parent": "muslo_izq", "z": 9,
     "pivot": [393, 1110],
     "polygon": [[276,1105],[510,1105],[520,1505],[266,1505]]},
    {"name": "muslo_der", "parent": "torso", "z": 9,
     "pivot": [631, 940],
     "polygon": [[514,930],[750,930],[745,1115],[520,1115]]},
    {"name": "pantorrilla_der", "parent": "muslo_der", "z": 9,
     "pivot": [631, 1110],
     "polygon": [[514,1105],[750,1105],[760,1505],[505,1505]]}
  ]
}
```

- [ ] **Step 4: Escribir el cortador**

Crear `tools/build_instructor_v2.py`:

```python
"""Corta las láminas del avatar v2 en piezas de rig + manifest + imagen de control."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CUTS = Path("tools/instructor_v2_cuts.json")
OUT = Path("assets/images/instructor")


def alpha_from_magenta(im):
    """Quita el fondo magenta y deja alfa real, sin halo."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (r > 170) & (g < 130) & (b > 170)
    out = np.dstack([a, np.where(bg, 0, 255)]).astype(np.uint8)
    # desfleca: donde el alfa es 0, el color no importa; donde es 255 pero el
    # pixel tira a magenta, se recorta el canal verde hacia el vecino opaco.
    return Image.fromarray(out, "RGBA")


def cut(src, poly):
    m = Image.new("L", src.size, 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in poly], fill=255)
    piece = Image.new("RGBA", src.size, (0, 0, 0, 0))
    piece.paste(src, (0, 0), m)
    return piece


def main():
    cfg = json.loads(CUTS.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    src = alpha_from_magenta(Image.open(cfg["source"]))
    x0, y0, x1, y1 = cfg["figureBBox"]
    fh = y1 - y0 + 1
    s = cfg["canonicalHeight"] / fh

    pieces, control = [], Image.new("RGBA", src.size, (0, 0, 0, 0))
    for p in cfg["pieces"]:
        piece = cut(src, p["polygon"])
        control.alpha_composite(piece)
        bb = piece.getbbox()
        if bb is None:
            raise SystemExit(f"pieza vacía: {p['name']} (revisá el polígono)")
        crop = piece.crop(bb)
        w = max(1, round(crop.width * s))
        h = max(1, round(crop.height * s))
        crop = crop.resize((w, h), Image.LANCZOS)
        crop.save(OUT / f"{p['name']}.png")

        px, py = p["pivot"]
        anchor = [(px - bb[0]) * s, (py - bb[1]) * s]
        parent = p["parent"]
        if parent is None:
            pivot = [(px - x0) * s, (py - y0) * s]
        else:
            ppx, ppy = next(q["pivot"] for q in cfg["pieces"] if q["name"] == parent)
            pivot = [(px - ppx) * s, (py - ppy) * s]
        pieces.append({
            "name": p["name"], "parent": parent, "asset": f"{p['name']}.png",
            "pivot": pivot, "anchor": anchor, "size": [w, h], "z": p["z"],
        })
        print(f"  {p['name']:<18} {w}x{h}")

    control.crop((x0, y0, x1, y1)).save(OUT / "_control.png")
    (OUT / "manifest.json").write_text(
        json.dumps({
            "canonicalHeight": cfg["canonicalHeight"],
            "aspect": round((x1 - x0 + 1) / fh, 4),
            "pieces": pieces,
        }, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"\n{len(pieces)} piezas -> {OUT}")
    print("Mirá _control.png: debe verse idéntica a la A-pose original.")


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Correrlo y verificar**

Run: `python tools/build_instructor_v2.py && python tools/verify_instructor_v2.py`
Expected: 10 piezas, verificador `todo OK`, salida 0.

- [ ] **Step 6: Calibrar contra la imagen de control**

Abrir `assets/images/instructor/_control.png` y compararla con `tools/instructor_v2_src/lamina0_apose_frontal.png`. Si falta un trozo de figura o se solapan dos piezas, **ajustar los polígonos en `tools/instructor_v2_cuts.json` y volver al Step 5**. No seguir hasta que la recomposición se vea igual al original.

- [ ] **Step 7: Declarar la carpeta en pubspec**

En `pubspec.yaml`, bajo `assets:`, añadir `- assets/images/instructor/` (Flutter **no** incluye subcarpetas de una carpeta ya listada). Correr `flutter pub get`.

- [ ] **Step 8: Commit**

```bash
git add tools/build_instructor_v2.py tools/verify_instructor_v2.py tools/instructor_v2_cuts.json assets/images/instructor pubspec.yaml
git commit -m "feat(avatar): pipeline de corte y piezas del cuerpo del avatar v2"
```

---

### Task 2: Cabeza, ojos y bocas

**Files:**
- Modify: `tools/build_instructor_v2.py` (añadir el paso de caras)
- Modify: `tools/instructor_v2_cuts.json` (bloque `faces`)
- Modify: `tools/verify_instructor_v2.py` (checks de registro)
- Output: `cabeza.png`, `ojos_abiertos.png`, `ojos_cerrados.png`, `ojos_medio.png`, `ojos_guino.png`, `ojos_feliz.png`, `ojos_sorpresa.png`, `boca_0..5.png`

**Interfaces:**
- Consumes: el `manifest.json` de la Task 1.
- Produces: entradas nuevas en `pieces` con `parent: "cabeza"` para los overlays de ojos y boca, y `cabeza` con `parent: "torso"`.

**Medidas ya tomadas** (no re-medir):
- Cuello A-pose: `y=381`, ancho 158 px. Cuello Lámina 1 casilla #1: `y=352` del recorte, ancho 152 px.
- **Factor del empalme: ×1.0395** (cuello contra cuello). Es el que se aplica, no el ×1.048 del casco.
- La pieza de cabeza **incluye el cuello alto** y corta entre 12 y 18 px por debajo del estrechamiento, donde el desajuste entre los dos dibujos es 1.4–2.3%.
- Lámina 1: 6 casillas de 512×512, deriva de casco 0.0%, corona dentro de 1 px. La casilla #3 (medio cerrar) **salió duplicada de la #1** → se sintetiza.
- Lámina 2: 6 casillas de 512×512, deriva 1.0%; contra la Lámina 1, ×1.020.

- [ ] **Step 1: Añadir los checks al verificador (fallan)**

En `tools/verify_instructor_v2.py`, dentro de `main()` antes de `return finish()`:

```python
    by = {p["name"]: p for p in m["pieces"]}
    check("cabeza" in by, "existe la pieza 'cabeza'")
    for n in ("ojos_abiertos", "ojos_cerrados", "ojos_medio", "ojos_guino",
              "ojos_feliz", "ojos_sorpresa"):
        check(n in by, f"existe '{n}'")
        if n in by:
            check(by[n]["parent"] == "cabeza", f"'{n}' cuelga de la cabeza")
    for i in range(6):
        n = f"boca_{i}"
        check(n in by, f"existe '{n}'")
        if n in by:
            check(by[n]["parent"] == "cabeza", f"'{n}' cuelga de la cabeza")
    # todos los ojos deben registrar en el MISMO sitio (vienen de una lámina
    # con 0.0% de deriva): sus pivotes no pueden separarse más de 2 px
    ojos = [by[n]["pivot"] for n in by if n.startswith("ojos_")]
    if len(ojos) > 1:
        dx = max(o[0] for o in ojos) - min(o[0] for o in ojos)
        dy = max(o[1] for o in ojos) - min(o[1] for o in ojos)
        check(dx <= 2 and dy <= 2, f"ojos registrados entre sí (dx={dx:.1f} dy={dy:.1f})")
```

- [ ] **Step 2: Correr para ver que falla**

Run: `python tools/verify_instructor_v2.py`
Expected: FALLA — `existe la pieza 'cabeza'` y las 12 siguientes.

- [ ] **Step 3: Extender la config**

Añadir a `tools/instructor_v2_cuts.json`, al mismo nivel que `pieces`:

```json
  "faces": {
    "eyesSheet": "tools/instructor_v2_src/lamina1_ojos.png",
    "mouthSheet": "tools/instructor_v2_src/lamina2_boca.png",
    "grid": [2, 3],
    "anchorTile": 0,
    "junctionScale": 1.0395,
    "neckY": 352,
    "cutBelowNeck": 15,
    "headPivotNative": [512, 381],
    "eyeRect": [past-calibrar],
    "mouthRect": [por-calibrar],
    "eyeTiles": {"abiertos": 0, "cerrados": 1, "guino": 3, "feliz": 4, "sorpresa": 5},
    "mouthTiles": [0, 1, 2, 3, 4, 5]
  }
```

`eyeRect` y `mouthRect` son `[x, y, w, h]` **en coordenadas de la casilla de 512×512**, y se calibran en el Step 6. Poné `[120, 180, 270, 90]` y `[190, 300, 130, 80]` como punto de partida.

- [ ] **Step 4: Implementar el paso de caras**

Añadir a `tools/build_instructor_v2.py`:

```python
def build_faces(cfg, s, pieces):
    """Cabeza + overlays de ojos y boca, registrados entre sí."""
    f = cfg["faces"]
    gw, gh = f["grid"]
    js = f["junctionScale"]

    def tile(path, idx):
        im = alpha_from_magenta(Image.open(path))
        tw, th = im.width // gw, im.height // gh
        r, c = divmod(idx, gw)
        return im.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th))

    # --- cabeza: casilla ancla, recortada 15 px bajo el cuello ---
    head = tile(f["eyesSheet"], f["anchorTile"])
    head = head.crop((0, 0, head.width, f["neckY"] + f["cutBelowNeck"]))
    head = head.resize((round(head.width * js * s), round(head.height * js * s)),
                       Image.LANCZOS)
    bb = head.getbbox()
    head = head.crop(bb)
    head.save(OUT / "cabeza.png")
    hx, hy = f["headPivotNative"]
    tpx, tpy = next(q["pivot"] for q in cfg["pieces"] if q["name"] == "torso")
    pieces.append({
        "name": "cabeza", "parent": "torso", "asset": "cabeza.png",
        "pivot": [(hx - tpx) * s, (hy - tpy) * s],
        # el pivote de la cabeza es su cuello: base del recorte, centrado
        "anchor": [head.width / 2, head.height - f["cutBelowNeck"] * js * s],
        "size": [head.width, head.height], "z": 20,
    })

    def overlay(sheet, idx, rect, name, z, transform=None):
        t = tile(sheet, idx)
        x, y, w, h = rect
        sub = t.crop((x, y, x + w, y + h))
        if transform:
            sub = transform(sub)
        sub = sub.resize((round(w * js * s), round(h * js * s)), Image.LANCZOS)
        sub.save(OUT / f"{name}.png")
        pieces.append({
            "name": name, "parent": "cabeza", "asset": f"{name}.png",
            # pivote comun: la esquina del rect, en canonicas relativas al cuello
            "pivot": [(x - 256) * js * s, (y - f["neckY"]) * js * s],
            "anchor": [0.0, 0.0],
            "size": [sub.width, sub.height], "z": z,
        })

    for nom, idx in f["eyeTiles"].items():
        overlay(f["eyesSheet"], idx, f["eyeRect"], f"ojos_{nom}", 21)

    # medio parpadeo SINTETICO: la casilla 2 de la lamina salio duplicada de la
    # 0, asi que se fabrica aplastando el ojo abierto al 50% anclado arriba.
    def squash(im):
        half = im.resize((im.width, max(1, im.height // 2)), Image.LANCZOS)
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        out.paste(half, (0, 0))
        return out

    overlay(f["eyesSheet"], f["eyeTiles"]["abiertos"], f["eyeRect"],
            "ojos_medio", 21, transform=squash)

    for i in f["mouthTiles"]:
        overlay(f["mouthSheet"], i, f["mouthRect"], f"boca_{i}", 22)
```

Y llamarla en `main()`, antes de escribir el manifest:

```python
    build_faces(cfg, s, pieces)
```

- [ ] **Step 5: Correr y verificar**

Run: `python tools/build_instructor_v2.py && python tools/verify_instructor_v2.py`
Expected: 23 piezas, `todo OK`.

- [ ] **Step 6: Calibrar los rectángulos de ojos y boca**

Abrir `assets/images/instructor/ojos_cerrados.png` y `boca_3.png`. Cada uno debe contener **sólo** la región correspondiente, con margen: los dos ojos completos con cejas, y la boca completa con el mentón. Si recortan de más o de menos, ajustar `eyeRect` / `mouthRect` en la config y repetir el Step 5.

- [ ] **Step 7: Commit**

```bash
git add tools/ assets/images/instructor
git commit -m "feat(avatar): cabeza, variantes de ojos y bocas del avatar v2"
```

---

### Task 3: Manos y piezas de perfil

**Files:**
- Modify: `tools/build_instructor_v2.py`, `tools/instructor_v2_cuts.json`, `tools/verify_instructor_v2.py`
- Output: `mano_puno.png`, `mano_senala.png`, `mano_pulgar.png`, `mano_abierta.png`, y `perfil_torso.png`, `perfil_brazo.png`, `perfil_muslo_a/b.png`, `perfil_pantorrilla_a/b.png`

**Interfaces:**
- Consumes: el manifest de las Tasks 1–2.
- Produces: 4 manos con `parent: "antebrazo_der"` y pivote en la muñeca, más un segundo rig bajo la clave `profile` del manifest.

**Medido:** Lámina 3 son 4 casillas de 627×627; ancho de muñeca 187 / 176 / 189 / 185 px → deriva 7.1%, **normalizable porque la muñeca es ancla exacta**. Lámina 5 (perfil v2): brazo separado del torso en el 59% del tronco y 95% de la banda de brazos; altura 1457 px, 2.2% por debajo de la frontal.

- [ ] **Step 1: Añadir los checks (fallan)**

En `tools/verify_instructor_v2.py`:

```python
    manos = [p for p in m["pieces"] if p["name"].startswith("mano_")]
    check(len(manos) == 4, f"4 manos (hay {len(manos)})")
    if manos:
        anchos = [p["size"][0] for p in manos]
        d = 100 * (max(anchos) - min(anchos)) / (sum(anchos) / len(anchos))
        check(d <= 3.0, f"manos normalizadas por muñeca (deriva {d:.1f}%, límite 3%)")
    check("profile" in m, "el manifest trae el rig de perfil")
    if "profile" in m:
        pn = [p["name"] for p in m["profile"]["pieces"]]
        for n in ("perfil_torso", "perfil_brazo", "perfil_muslo_a", "perfil_muslo_b"):
            check(n in pn, f"perfil: existe '{n}'")
```

- [ ] **Step 2: Correr para ver que falla**

Run: `python tools/verify_instructor_v2.py`
Expected: FALLA — `4 manos (hay 0)` y `el manifest trae el rig de perfil`.

- [ ] **Step 3: Extender la config**

Añadir a `tools/instructor_v2_cuts.json`:

```json
  "hands": {
    "sheet": "tools/instructor_v2_src/lamina3_manos.png",
    "grid": [2, 2],
    "names": ["mano_puno", "mano_senala", "mano_pulgar", "mano_abierta"],
    "wristFromBottomPct": 15,
    "targetWristWidth": 184
  },
  "profile": {
    "source": "tools/instructor_v2_src/lamina5_perfil_v2.png",
    "figureBBox": [285, 31, 779, 1487],
    "pieces": [
      {"name": "perfil_torso", "parent": null, "z": 10,
       "pivot": [530, 900], "polygon": [[380,240],[700,240],[700,900],[380,900]]},
      {"name": "perfil_brazo", "parent": "perfil_torso", "z": 12,
       "pivot": [470, 480], "polygon": [[380,450],[520,450],[560,960],[400,960]]},
      {"name": "perfil_muslo_a", "parent": "perfil_torso", "z": 9,
       "pivot": [500, 905], "polygon": [[400,895],[620,895],[620,1120],[400,1120]]},
      {"name": "perfil_pantorrilla_a", "parent": "perfil_muslo_a", "z": 9,
       "pivot": [500, 1115], "polygon": [[390,1110],[620,1110],[630,1490],[380,1490]]},
      {"name": "perfil_muslo_b", "parent": "perfil_torso", "z": 7,
       "pivot": [560, 905], "polygon": [[460,895],[700,895],[700,1120],[460,1120]]},
      {"name": "perfil_pantorrilla_b", "parent": "perfil_muslo_b", "z": 7,
       "pivot": [560, 1115], "polygon": [[450,1110],[700,1110],[710,1490],[440,1490]]}
    ]
  }
```

- [ ] **Step 4: Implementar manos y perfil**

Añadir a `tools/build_instructor_v2.py`:

```python
def build_hands(cfg, s, pieces):
    """Las 4 manos, normalizadas para que la muñeca mida lo mismo en todas."""
    h = cfg["hands"]
    sheet = alpha_from_magenta(Image.open(h["sheet"]))
    gw, gh = h["grid"]
    tw, th = sheet.width // gw, sheet.height // gh
    for i, name in enumerate(h["names"]):
        r, c = divmod(i, gw)
        t = sheet.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th))
        bb = t.getbbox()
        t = t.crop(bb)
        # ancho de muñeca: fila al 15% por encima de la base de la figura
        a = np.asarray(t)[..., 3]
        yw = int(a.shape[0] * (1 - h["wristFromBottomPct"] / 100)) - 1
        cols = np.where(a[yw] > 20)[0]
        wrist = int(cols.max() - cols.min() + 1) if len(cols) else 1
        k = h["targetWristWidth"] / wrist * s
        t = t.resize((max(1, round(t.width * k)), max(1, round(t.height * k))),
                     Image.LANCZOS)
        t.save(OUT / f"{name}.png")
        apx, apy = next(q["pivot"] for q in cfg["pieces"] if q["name"] == "antebrazo_der")
        pieces.append({
            "name": name, "parent": "antebrazo_der", "asset": f"{name}.png",
            "pivot": [0.0, 190.0 * s],       # la muñeca, bajo el codo
            "anchor": [t.width / 2, t.height * (1 - h["wristFromBottomPct"] / 100)],
            "size": [t.width, t.height], "z": 13,
        })
        print(f"  {name:<18} {t.width}x{t.height}  (muñeca {wrist} -> k={k:.3f})")


def build_profile(cfg):
    """Segundo rig, para la entrada caminando."""
    p = cfg["profile"]
    src = alpha_from_magenta(Image.open(p["source"]))
    x0, y0, x1, y1 = p["figureBBox"]
    fh = y1 - y0 + 1
    s = cfg["canonicalHeight"] / fh
    out = []
    for q in p["pieces"]:
        piece = cut(src, q["polygon"])
        bb = piece.getbbox()
        if bb is None:
            raise SystemExit(f"pieza de perfil vacía: {q['name']}")
        crop = piece.crop(bb)
        w, h = max(1, round(crop.width * s)), max(1, round(crop.height * s))
        crop.resize((w, h), Image.LANCZOS).save(OUT / f"{q['name']}.png")
        qx, qy = q["pivot"]
        if q["parent"] is None:
            pivot = [(qx - x0) * s, (qy - y0) * s]
        else:
            px, py = next(r["pivot"] for r in p["pieces"] if r["name"] == q["parent"])
            pivot = [(qx - px) * s, (qy - py) * s]
        out.append({
            "name": q["name"], "parent": q["parent"], "asset": f"{q['name']}.png",
            "pivot": pivot, "anchor": [(qx - bb[0]) * s, (qy - bb[1]) * s],
            "size": [w, h], "z": q["z"],
        })
    return {"aspect": round((x1 - x0 + 1) / fh, 4), "pieces": out}
```

En `main()`, tras `build_faces(...)`:

```python
    build_hands(cfg, s, pieces)
    profile = build_profile(cfg)
```

y añadir `"profile": profile` al dict del manifest.

- [ ] **Step 5: Correr y verificar**

Run: `python tools/build_instructor_v2.py && python tools/verify_instructor_v2.py`
Expected: 27 piezas frontales + 6 de perfil, `todo OK`, y la deriva de manos ≤3%.

- [ ] **Step 6: Commit**

```bash
git add tools/ assets/images/instructor
git commit -m "feat(avatar): manos normalizadas y rig de perfil del avatar v2"
```

---

### Task 4: Cuantización y cierre del pipeline

**Files:**
- Modify: `tools/build_instructor_v2.py` (cuantizar + reporte de peso)
- Modify: `tools/verify_instructor_v2.py` (presupuesto de peso)

**Interfaces:**
- Produces: las mismas piezas, cuantizadas a 256 colores, con el peso total bajo presupuesto.

- [ ] **Step 1: Añadir el check de peso (falla)**

En `tools/verify_instructor_v2.py`, antes de `return finish()`:

```python
    total = sum(f.stat().st_size for f in OUT.glob("*.png") if not f.name.startswith("_"))
    kb = total / 1024
    check(kb <= 450, f"peso total {kb:.0f} KB (presupuesto 450 KB)")
```

- [ ] **Step 2: Correr para ver que falla**

Run: `python tools/verify_instructor_v2.py`
Expected: FALLA — el peso supera 450 KB sin cuantizar (los PNG salen en RGBA de 32 bits).

- [ ] **Step 3: Cuantizar**

En `tools/build_instructor_v2.py`, añadir y usar en cada `.save(...)`:

```python
def save_quant(im, path):
    """PNG de 256 colores conservando el alfa (FASTOCTREE), como el resto del repo."""
    q = im.quantize(colors=256, method=Image.FASTOCTREE)
    q.save(path, optimize=True)
```

Reemplazar todas las llamadas `X.save(OUT / "...")` de piezas por `save_quant(X, OUT / "...")`. La imagen de control `_control.png` se deja sin cuantizar.

Y al final de `main()`:

```python
    kb = sum(f.stat().st_size for f in OUT.glob("*.png")
             if not f.name.startswith("_")) / 1024
    print(f"peso total: {kb:.0f} KB")
```

- [ ] **Step 4: Correr y verificar**

Run: `python tools/build_instructor_v2.py && python tools/verify_instructor_v2.py`
Expected: `todo OK`, peso total ≤ 450 KB.

- [ ] **Step 5: Commit**

```bash
git add tools/ assets/images/instructor
git commit -m "feat(avatar): cuantización y presupuesto de peso del set v2"
```

---

### Task 5: Datos del rig en Dart

**Files:**
- Create: `lib/core/animations/instructor/instructor_rig.dart`
- Test: `test/core/animations/instructor_rig_test.dart`

**Interfaces:**
- Consumes: `assets/images/instructor/manifest.json`.
- Produces:
  - `class InstructorBone { final String name; final String? parent; final Offset pivot; final Offset anchor; final Size size; final String asset; final int z; }`
  - `class InstructorRig { final List<InstructorBone> bones; final double canonicalHeight; final double aspect; InstructorBone? byName(String n); List<InstructorBone> get drawOrder; factory InstructorRig.fromJson(Map<String, dynamic> json); }`
  - `Future<InstructorRig> loadInstructorRig({String asset = 'assets/images/instructor/manifest.json', AssetBundle? bundle})`

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/animations/instructor_rig_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig.dart';

void main() {
  const json = {
    'canonicalHeight': 800.0,
    'aspect': 0.63,
    'pieces': [
      {
        'name': 'torso', 'parent': null, 'asset': 'torso.png',
        'pivot': [0.0, 0.0], 'anchor': [10.0, 20.0], 'size': [30, 40], 'z': 10,
      },
      {
        'name': 'cabeza', 'parent': 'torso', 'asset': 'cabeza.png',
        'pivot': [0.0, -50.0], 'anchor': [5.0, 8.0], 'size': [12, 16], 'z': 20,
      },
    ],
  };

  test('parsea el manifest', () {
    final rig = InstructorRig.fromJson(json);
    expect(rig.canonicalHeight, 800.0);
    expect(rig.bones.length, 2);
    expect(rig.byName('cabeza')!.parent, 'torso');
    expect(rig.byName('cabeza')!.pivot, const Offset(0, -50));
    expect(rig.byName('torso')!.size, const Size(30, 40));
    expect(rig.byName('no_existe'), isNull);
  });

  test('drawOrder ordena por z ascendente', () {
    final rig = InstructorRig.fromJson(json);
    expect(rig.drawOrder.map((b) => b.name).toList(), ['torso', 'cabeza']);
  });

  test('rechaza un padre inexistente', () {
    expect(
      () => InstructorRig.fromJson({
        'canonicalHeight': 800.0,
        'aspect': 0.63,
        'pieces': [
          {
            'name': 'mano', 'parent': 'fantasma', 'asset': 'm.png',
            'pivot': [0.0, 0.0], 'anchor': [0.0, 0.0], 'size': [1, 1], 'z': 1,
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/animations/instructor_rig_test.dart`
Expected: FAIL — `Target of URI doesn't exist: instructor_rig.dart`.

- [ ] **Step 3: Implementar**

Crear `lib/core/animations/instructor/instructor_rig.dart`:

```dart
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Una pieza del rig de la instructora: su PNG, dónde gira y de quién cuelga.
///
/// Datos puros generados por `tools/build_instructor_v2.py`. Las coordenadas
/// están en la figura canónica (800 px de alto); [pivot] es relativo al pivote
/// del padre, [anchor] es dónde cae ese pivote DENTRO del PNG.
class InstructorBone {
  final String name;
  final String? parent;
  final Offset pivot;
  final Offset anchor;
  final Size size;
  final String asset;
  final int z;

  const InstructorBone({
    required this.name,
    required this.parent,
    required this.pivot,
    required this.anchor,
    required this.size,
    required this.asset,
    required this.z,
  });

  factory InstructorBone.fromJson(Map<String, dynamic> j) {
    Offset off(String k) {
      final v = (j[k] as List).cast<num>();
      return Offset(v[0].toDouble(), v[1].toDouble());
    }

    final s = (j['size'] as List).cast<num>();
    return InstructorBone(
      name: j['name'] as String,
      parent: j['parent'] as String?,
      pivot: off('pivot'),
      anchor: off('anchor'),
      size: Size(s[0].toDouble(), s[1].toDouble()),
      asset: j['asset'] as String,
      z: (j['z'] as num).toInt(),
    );
  }
}

/// El esqueleto completo. Sin estado ni tiempo: sólo la jerarquía en reposo.
class InstructorRig {
  final List<InstructorBone> bones;
  final double canonicalHeight;

  /// Ancho/alto de la figura. El coach lo usa en vez de tener el número escrito
  /// a mano, para que no se desincronice del arte.
  final double aspect;

  final Map<String, InstructorBone> _byName;
  final List<InstructorBone> _drawOrder;

  InstructorRig._(this.bones, this.canonicalHeight, this.aspect)
      : _byName = {for (final b in bones) b.name: b},
        _drawOrder = [...bones]..sort((a, b) => a.z.compareTo(b.z));

  factory InstructorRig.fromJson(Map<String, dynamic> json) {
    final bones = (json['pieces'] as List)
        .cast<Map<String, dynamic>>()
        .map(InstructorBone.fromJson)
        .toList();
    final names = {for (final b in bones) b.name};
    for (final b in bones) {
      if (b.parent != null && !names.contains(b.parent)) {
        throw FormatException('El hueso "${b.name}" cuelga de "${b.parent}", '
            'que no existe en el manifest.');
      }
    }
    return InstructorRig._(
      bones,
      (json['canonicalHeight'] as num).toDouble(),
      (json['aspect'] as num).toDouble(),
    );
  }

  InstructorBone? byName(String n) => _byName[n];

  /// De atrás hacia adelante.
  List<InstructorBone> get drawOrder => List.unmodifiable(_drawOrder);
}

Future<InstructorRig> loadInstructorRig({
  String asset = 'assets/images/instructor/manifest.json',
  AssetBundle? bundle,
}) async {
  final raw = await (bundle ?? rootBundle).loadString(asset);
  return InstructorRig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
```

- [ ] **Step 4: Correr para ver que pasa**

Run: `flutter test test/core/animations/instructor_rig_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/instructor/instructor_rig.dart test/core/animations/instructor_rig_test.dart
git commit -m "feat(avatar): modelo de datos del rig y carga del manifest"
```

---

### Task 6: Clips y solver

**Files:**
- Create: `lib/core/animations/instructor/instructor_clip.dart`
- Create: `lib/core/animations/instructor/instructor_solver.dart`
- Test: `test/core/animations/instructor_solver_test.dart`

**Interfaces:**
- Consumes: `InstructorRig`, `InstructorBone` (Task 5).
- Produces:
  - `class BoneTransform { final double rot; final Offset translate; final double scale; const BoneTransform({this.rot = 0, this.translate = Offset.zero, this.scale = 1}); static const identity = BoneTransform(); }`
  - `class BoneKey { final double t; final double rot; final Offset translate; final double scale; final Curve curve; }`
  - `class InstructorClip { final String name; final Duration duration; final bool loop; final Map<String, List<BoneKey>> tracks; }`
  - `class ClipLayer { final InstructorClip clip; final double t; final double weight; }`
  - `BoneTransform sampleTrack(List<BoneKey> keys, double t)`
  - `Map<String, Matrix4> solveInstructorPose(InstructorRig rig, List<ClipLayer> layers)`

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/animations/instructor_solver_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';

InstructorRig _rig() => InstructorRig.fromJson({
      'canonicalHeight': 800.0,
      'aspect': 0.63,
      'pieces': [
        {
          'name': 'torso', 'parent': null, 'asset': 't.png',
          'pivot': [100.0, 400.0], 'anchor': [50.0, 100.0],
          'size': [100, 200], 'z': 10,
        },
        {
          'name': 'brazo', 'parent': 'torso', 'asset': 'b.png',
          'pivot': [40.0, -60.0], 'anchor': [10.0, 10.0],
          'size': [30, 120], 'z': 12,
        },
      ],
    });

void main() {
  test('sampleTrack interpola entre keyframes', () {
    final keys = [
      const BoneKey(t: 0, rot: 0),
      const BoneKey(t: 1, rot: math.pi / 2, curve: Curves.linear),
    ];
    expect(sampleTrack(keys, 0).rot, 0);
    expect(sampleTrack(keys, 0.5).rot, closeTo(math.pi / 4, 1e-9));
    expect(sampleTrack(keys, 1).rot, closeTo(math.pi / 2, 1e-9));
  });

  test('sampleTrack fuera de rango devuelve los extremos', () {
    final keys = [const BoneKey(t: 0.2, rot: 1), const BoneKey(t: 0.8, rot: 3)];
    expect(sampleTrack(keys, 0).rot, 1);
    expect(sampleTrack(keys, 1).rot, 3);
  });

  test('una lista vacía de capas da la pose de reposo', () {
    final pose = solveInstructorPose(_rig(), const []);
    final t = pose['torso']!.getTranslation();
    expect(t.x, closeTo(100, 1e-9));
    expect(t.y, closeTo(400, 1e-9));
    // el brazo hereda el pivote del torso
    final b = pose['brazo']!.getTranslation();
    expect(b.x, closeTo(140, 1e-9));
    expect(b.y, closeTo(340, 1e-9));
  });

  test('las capas son aditivas y se ponderan', () {
    final rig = _rig();
    final c1 = InstructorClip(
      name: 'a',
      duration: const Duration(seconds: 1),
      tracks: {
        'brazo': [const BoneKey(t: 0, rot: 1.0), const BoneKey(t: 1, rot: 1.0)],
      },
    );
    final c2 = InstructorClip(
      name: 'b',
      duration: const Duration(seconds: 1),
      tracks: {
        'brazo': [const BoneKey(t: 0, rot: 2.0), const BoneKey(t: 1, rot: 2.0)],
      },
    );
    final full = solveInstructorPose(rig, [
      ClipLayer(clip: c1, t: 0.5),
      ClipLayer(clip: c2, t: 0.5, weight: 0.5),
    ]);
    // 1.0 + 2.0*0.5 = 2.0 radianes en el brazo
    final m = full['brazo']!;
    expect(math.atan2(m.row1.x, m.row0.x), closeTo(2.0, 1e-6));
  });

  test('un hueso que ninguna capa toca no se mueve', () {
    final rig = _rig();
    final clip = InstructorClip(
      name: 'solo_brazo',
      duration: const Duration(seconds: 1),
      tracks: {
        'brazo': [const BoneKey(t: 0, rot: 0.9), const BoneKey(t: 1, rot: 0.9)],
      },
    );
    final pose = solveInstructorPose(rig, [ClipLayer(clip: clip, t: 0.3)]);
    final m = pose['torso']!;
    expect(math.atan2(m.row1.x, m.row0.x), closeTo(0, 1e-9));
  });

  test('ninguna matriz trae NaN', () {
    final rig = _rig();
    final clip = InstructorClip(
      name: 'x',
      duration: const Duration(seconds: 1),
      tracks: {
        'torso': [const BoneKey(t: 0, scale: 1.0), const BoneKey(t: 1, scale: 1.2)],
      },
    );
    for (var i = 0; i <= 10; i++) {
      final pose = solveInstructorPose(rig, [ClipLayer(clip: clip, t: i / 10)]);
      for (final m in pose.values) {
        for (final v in m.storage) {
          expect(v.isNaN, isFalse);
        }
      }
    }
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/animations/instructor_solver_test.dart`
Expected: FAIL — no existen `instructor_clip.dart` ni `instructor_solver.dart`.

- [ ] **Step 3: Implementar clips**

Crear `lib/core/animations/instructor/instructor_clip.dart`:

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Lo que una capa le hace a un hueso en un instante: girarlo, correrlo y
/// escalarlo. Se suman entre capas.
class BoneTransform {
  final double rot;
  final Offset translate;
  final double scale;

  const BoneTransform({
    this.rot = 0,
    this.translate = Offset.zero,
    this.scale = 1,
  });

  static const identity = BoneTransform();

  BoneTransform addWeighted(BoneTransform o, double w) => BoneTransform(
        rot: rot + o.rot * w,
        translate: translate + o.translate * w,
        scale: scale + (o.scale - 1) * w,
      );
}

/// Un keyframe. [t] va de 0 a 1 sobre la duración del clip; [curve] es la
/// interpolación HACIA este keyframe desde el anterior.
class BoneKey {
  final double t;
  final double rot;
  final Offset translate;
  final double scale;
  final Curve curve;

  const BoneKey({
    required this.t,
    this.rot = 0,
    this.translate = Offset.zero,
    this.scale = 1,
    this.curve = Curves.linear,
  });
}

/// Una animación: qué le pasa a cada hueso a lo largo del tiempo.
class InstructorClip {
  final String name;
  final Duration duration;
  final bool loop;
  final Map<String, List<BoneKey>> tracks;

  const InstructorClip({
    required this.name,
    required this.duration,
    required this.tracks,
    this.loop = false,
  });
}

/// Un clip aplicándose ahora mismo, en el instante [t] (0..1) y con [weight].
class ClipLayer {
  final InstructorClip clip;
  final double t;
  final double weight;

  const ClipLayer({required this.clip, required this.t, this.weight = 1.0});
}

/// Muestrea una pista en [t]. Fuera de rango devuelve el keyframe extremo.
BoneTransform sampleTrack(List<BoneKey> keys, double t) {
  if (keys.isEmpty) return BoneTransform.identity;
  if (t <= keys.first.t) {
    return BoneTransform(
      rot: keys.first.rot,
      translate: keys.first.translate,
      scale: keys.first.scale,
    );
  }
  if (t >= keys.last.t) {
    return BoneTransform(
      rot: keys.last.rot,
      translate: keys.last.translate,
      scale: keys.last.scale,
    );
  }
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i];
    final b = keys[i + 1];
    if (t >= a.t && t <= b.t) {
      final span = b.t - a.t;
      final raw = span <= 0 ? 1.0 : (t - a.t) / span;
      final k = b.curve.transform(raw.clamp(0.0, 1.0));
      return BoneTransform(
        rot: a.rot + (b.rot - a.rot) * k,
        translate: Offset.lerp(a.translate, b.translate, k)!,
        scale: a.scale + (b.scale - a.scale) * k,
      );
    }
  }
  return BoneTransform.identity;
}
```

- [ ] **Step 4: Implementar el solver**

Crear `lib/core/animations/instructor/instructor_solver.dart`:

```dart
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'instructor_clip.dart';
import 'instructor_rig.dart';

/// Resuelve la pose del rig: para cada hueso, la matriz que lleva del origen
/// del lienzo canónico a su pivote ya rotado y escalado.
///
/// Función PURA: sin estado, sin tiempo propio, sin widgets. Las capas se
/// suman en el orden dado, cada una ponderada por su `weight`; un hueso que
/// ninguna capa declara se queda en reposo. Eso es lo que permite que un gesto
/// mueva el brazo mientras el torso sigue respirando.
Map<String, Matrix4> solveInstructorPose(
  InstructorRig rig,
  List<ClipLayer> layers,
) {
  final local = <String, BoneTransform>{};
  for (final bone in rig.bones) {
    var acc = BoneTransform.identity;
    for (final layer in layers) {
      final track = layer.clip.tracks[bone.name];
      if (track == null) continue;
      acc = acc.addWeighted(sampleTrack(track, layer.t), layer.weight);
    }
    local[bone.name] = acc;
  }

  final world = <String, Matrix4>{};

  Matrix4 resolve(InstructorBone bone) {
    final cached = world[bone.name];
    if (cached != null) return cached;

    final parentBone = bone.parent == null ? null : rig.byName(bone.parent!);
    final base = parentBone == null ? Matrix4.identity() : resolve(parentBone);

    final t = local[bone.name] ?? BoneTransform.identity;
    final m = base.clone()
      ..translate(bone.pivot.dx + t.translate.dx, bone.pivot.dy + t.translate.dy)
      ..rotateZ(t.rot)
      ..scale(t.scale, t.scale);
    world[bone.name] = m;
    return m;
  }

  for (final bone in rig.bones) {
    resolve(bone);
  }
  return world;
}
```

- [ ] **Step 5: Correr para ver que pasa**

Run: `flutter test test/core/animations/instructor_solver_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/animations/instructor/instructor_clip.dart lib/core/animations/instructor/instructor_solver.dart test/core/animations/instructor_solver_test.dart
git commit -m "feat(avatar): clips con capas aditivas y solver puro del rig"
```

---

### Task 7: Renderizador

**Files:**
- Create: `lib/core/animations/instructor/instructor_rig_view.dart`
- Test: `test/core/animations/instructor_rig_view_test.dart`

**Interfaces:**
- Consumes: `InstructorRig`, `solveInstructorPose`.
- Produces:
  - `class InstructorImages { final Map<String, ui.Image> byAsset; static Future<InstructorImages> load(InstructorRig rig, {AssetBundle? bundle}); void dispose(); }` — las piezas que no carguen simplemente **no entran al mapa**.
  - `class InstructorRigView extends StatelessWidget { const InstructorRigView({required this.rig, required this.images, required this.pose, required this.height}); }`
  - `class InstructorRigPainter extends CustomPainter` (expuesto para poder testearlo).

**Cubre Review Focus #2 (pieza que no carga) y #4 (`height` extremo).**

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/animations/instructor_rig_view_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';

Future<ui.Image> _dot() {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList([255, 0, 0, 255]), 1, 1, ui.PixelFormat.rgba8888,
    c.complete,
  );
  return c.future;
}

InstructorRig _rig() => InstructorRig.fromJson({
      'canonicalHeight': 800.0,
      'aspect': 0.63,
      'pieces': [
        {
          'name': 'torso', 'parent': null, 'asset': 'torso.png',
          'pivot': [100.0, 400.0], 'anchor': [50.0, 100.0],
          'size': [100, 200], 'z': 10,
        },
        {
          'name': 'antena', 'parent': 'torso', 'asset': 'antena.png',
          'pivot': [10.0, -40.0], 'anchor': [2.0, 30.0],
          'size': [6, 60], 'z': 5,
        },
      ],
    });

void main() {
  testWidgets('dibuja aunque falte una pieza', (tester) async {
    final rig = _rig();
    // SOLO el torso: 'antena.png' no cargó (archivo corrupto o ausente).
    final images = InstructorImages.forTest({'torso.png': await _dot()});
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: InstructorRigView(
          rig: rig,
          images: images,
          pose: solveInstructorPose(rig, const []),
          height: 150,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(InstructorRigView), findsOneWidget);
  });

  testWidgets('no revienta con height 0', (tester) async {
    final rig = _rig();
    final images = InstructorImages.forTest({'torso.png': await _dot()});
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: InstructorRigView(
          rig: rig,
          images: images,
          pose: solveInstructorPose(rig, const []),
          height: 0,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no revienta con height negativo', (tester) async {
    final rig = _rig();
    final images = InstructorImages.forTest({'torso.png': await _dot()});
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: InstructorRigView(
          rig: rig, images: images,
          pose: solveInstructorPose(rig, const []), height: -20,
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('shouldRepaint sólo cuando cambia la pose', () {
    final rig = _rig();
    final a = solveInstructorPose(rig, const []);
    final p1 = InstructorRigPainter(rig: rig, images: const {}, pose: a, scale: 1);
    final p2 = InstructorRigPainter(rig: rig, images: const {}, pose: a, scale: 1);
    expect(p1.shouldRepaint(p2), isFalse);
    final p3 = InstructorRigPainter(
      rig: rig, images: const {}, pose: Map.of(a), scale: 2,
    );
    expect(p1.shouldRepaint(p3), isTrue);
  });
}
```

Añadir `import 'dart:async';` arriba del archivo de test.

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/animations/instructor_rig_view_test.dart`
Expected: FAIL — no existe `instructor_rig_view.dart`.

- [ ] **Step 3: Implementar**

Crear `lib/core/animations/instructor/instructor_rig_view.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../utils/app_logger.dart';
import 'instructor_rig.dart';

/// Las piezas decodificadas. Una pieza que no carga NO entra al mapa: el
/// painter la salta y dibuja el resto. Mejor una instructora sin antena que un
/// tutorial en blanco.
class InstructorImages {
  final Map<String, ui.Image> byAsset;

  const InstructorImages._(this.byAsset);

  @visibleForTesting
  factory InstructorImages.forTest(Map<String, ui.Image> m) =>
      InstructorImages._(m);

  static Future<InstructorImages> load(
    InstructorRig rig, {
    AssetBundle? bundle,
    String dir = 'assets/images/instructor/',
  }) async {
    final b = bundle ?? rootBundle;
    final out = <String, ui.Image>{};
    for (final bone in rig.bones) {
      if (out.containsKey(bone.asset)) continue;
      try {
        final data = await b.load('$dir${bone.asset}');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        out[bone.asset] = (await codec.getNextFrame()).image;
      } catch (e) {
        AppLogger.warn('InstructorImages', 'No se pudo cargar ${bone.asset}: $e');
      }
    }
    return InstructorImages._(out);
  }

  void dispose() {
    for (final img in byAsset.values) {
      img.dispose();
    }
  }
}

/// Dibuja el rig con la pose dada. Widget tonto: no anima, sólo pinta.
class InstructorRigView extends StatelessWidget {
  final InstructorRig rig;
  final InstructorImages images;
  final Map<String, Matrix4> pose;
  final double height;

  const InstructorRigView({
    super.key,
    required this.rig,
    required this.images,
    required this.pose,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final h = height.isFinite && height > 0 ? height : 0.0;
    final scale = h / rig.canonicalHeight;
    return RepaintBoundary(
      child: SizedBox(
        height: h,
        width: h * rig.aspect,
        child: CustomPaint(
          painter: InstructorRigPainter(
            rig: rig,
            images: images.byAsset,
            pose: pose,
            scale: scale,
          ),
        ),
      ),
    );
  }
}

class InstructorRigPainter extends CustomPainter {
  final InstructorRig rig;
  final Map<String, ui.Image> images;
  final Map<String, Matrix4> pose;
  final double scale;

  const InstructorRigPainter({
    required this.rig,
    required this.images,
    required this.pose,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scale <= 0) return;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.save();
    canvas.scale(scale);
    for (final bone in rig.drawOrder) {
      final img = images[bone.asset];
      final m = pose[bone.name];
      if (img == null || m == null) continue;
      canvas.save();
      canvas.transform(m.storage);
      canvas.translate(-bone.anchor.dx, -bone.anchor.dy);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(0, 0, bone.size.width, bone.size.height),
        paint,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(InstructorRigPainter old) =>
      old.pose != pose || old.scale != scale || old.images != images;
}
```

- [ ] **Step 4: Correr para ver que pasa**

Run: `flutter test test/core/animations/instructor_rig_view_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/instructor/instructor_rig_view.dart test/core/animations/instructor_rig_view_test.dart
git commit -m "feat(avatar): renderizador CustomPainter del rig, tolerante a piezas faltantes"
```

---

### Task 8: `TutorialInstructor` sobre el rig (idle + parpadeo)

**Files:**
- Create: `lib/core/animations/instructor/instructor_clips.dart`
- Modify: `lib/core/widgets/tutorial_instructor.dart` (tripas; la API pública **no cambia**)
- Test: `test/core/tutorial_instructor_rig_test.dart`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: `InstructorClips.idle`, `InstructorClips.idleParty`, `InstructorClips.blink`, `InstructorClips.wink`, y `TutorialInstructor` renderizando `InstructorRigView` en vez de `Image`.

**Cubre Review Focus #1 (reduce-motion) y #5 (desmontaje a mitad de animación).**

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/tutorial_instructor_rig_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child, {bool reduceMotion = false}) => CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Center(child: child),
        ),
      );

  testWidgets('renderiza el rig, no un Image de cuerpo entero', (tester) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(InstructorRigView), findsOneWidget);
  });

  testWidgets('con reduce-motion queda estática', (tester) async {
    await tester.pumpWidget(
      host(const TutorialInstructor(height: 150), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final a = tester.widget<InstructorRigView>(find.byType(InstructorRigView)).pose;
    await tester.pump(const Duration(milliseconds: 900));
    final b = tester.widget<InstructorRigView>(find.byType(InstructorRigView)).pose;
    for (final k in a.keys) {
      expect(a[k]!.storage, b[k]!.storage,
          reason: 'el hueso "$k" se movió con reduce-motion activo');
    }
  });

  testWidgets('sin reduce-motion el idle sí mueve el torso', (tester) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await tester.pump(const Duration(milliseconds: 50));
    final a = tester.widget<InstructorRigView>(find.byType(InstructorRigView)).pose;
    final antes = List<double>.from(a['torso']!.storage);
    await tester.pump(const Duration(milliseconds: 650));
    final b = tester.widget<InstructorRigView>(find.byType(InstructorRigView)).pose;
    expect(b['torso']!.storage, isNot(antes));
  });

  testWidgets('desmontar a mitad de animación no deja excepciones',
      (tester) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/tutorial_instructor_rig_test.dart`
Expected: FAIL — `InstructorRigView` no aparece; `TutorialInstructor` todavía dibuja `Image`.

- [ ] **Step 3: Escribir los clips base**

Crear `lib/core/animations/instructor/instructor_clips.dart`:

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../theme/app_constants.dart';
import 'instructor_clip.dart';

/// El catálogo de animaciones de la instructora.
///
/// Las cinco reglas de timing (spec §4): anticipación antes de cada gesto,
/// overshoot con asentamiento, follow-through escalonado hombro→codo→muñeca,
/// movimiento secundario en la antena, y NUNCA los dos brazos idénticos.
class InstructorClips {
  const InstructorClips._();

  /// Respiración en reposo. El torso se estira un 1.2%, la cabeza acompaña dos
  /// píxeles, la antena llega tarde: eso último es lo que lo hace parecer vivo.
  static const idle = InstructorClip(
    name: 'idle',
    duration: Duration(milliseconds: 2600),
    loop: true,
    tracks: {
      'torso': [
        BoneKey(t: 0.0, scale: 1.0),
        BoneKey(t: 0.5, scale: 1.012, curve: AppCurves.smooth),
        BoneKey(t: 1.0, scale: 1.0, curve: AppCurves.smooth),
      ],
      'cabeza': [
        BoneKey(t: 0.0, translate: Offset.zero),
        BoneKey(t: 0.5, translate: Offset(0, -2), curve: AppCurves.smooth),
        BoneKey(t: 1.0, translate: Offset.zero, curve: AppCurves.smooth),
      ],
      'antena': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.62, rot: 0.045, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );

  /// Igual pero saltarina, para la celebración.
  static const idleParty = InstructorClip(
    name: 'idle_party',
    duration: Duration(milliseconds: 1500),
    loop: true,
    tracks: {
      'torso': [
        BoneKey(t: 0.0, translate: Offset.zero, scale: 1.0),
        BoneKey(t: 0.45, translate: Offset(0, -6), scale: 1.02,
            curve: AppCurves.bounce),
        BoneKey(t: 1.0, translate: Offset.zero, scale: 1.0,
            curve: AppCurves.smooth),
      ],
      'antena': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.55, rot: 0.12, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );

  /// El parpadeo no mueve huesos: conmuta el sprite de ojos. Se modela como
  /// clip vacío para que la capa exista y el widget sepa su duración.
  static const blink = InstructorClip(
    name: 'blink',
    duration: Duration(milliseconds: 130),
    tracks: {},
  );

  static const wink = InstructorClip(
    name: 'wink',
    duration: Duration(milliseconds: 780),
    tracks: {},
  );
}
```

> Si `AppCurves` no expone `smooth` / `bounce` con esos nombres exactos, abrí `lib/core/theme/app_constants.dart` y usá los que haya. **No** metas `Curves.easeInOut` crudo.

- [ ] **Step 4: Reescribir las tripas del widget**

En `lib/core/widgets/tutorial_instructor.dart`:

1. **Conservar sin tocar**: el `enum InstructorPose` (se le añaden valores en la Task 10), todos los `AnimationController` y sus constantes, `_settle()`, `_syncIdle()`, `_syncBlinking()`, `_scheduleBlink()`, `_syncTalk()`, `_syncSpeak()`, y la lista de parámetros del constructor.
2. **Borrar**: `_kReposo`…`_kSaludo`, `kInstructorWalkFrames`, `kInstructorAssets`, `_kPoseScale`, el `AnimatedSwitcher` y todo `Image.asset` del `build`.
3. **Añadir** al `State`:

```dart
  InstructorRig? _rig;
  InstructorImages? _images;

  @override
  void initState() {
    super.initState();
    // …controladores existentes, sin cambios…
    _cargarRig();
  }

  Future<void> _cargarRig() async {
    final rig = await loadInstructorRig();
    final imgs = await InstructorImages.load(rig);
    if (!mounted) {
      imgs.dispose();
      return;
    }
    setState(() {
      _rig = rig;
      _images = imgs;
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    // …dispose de los controladores existentes…
    _images?.dispose();
    super.dispose();
  }

  /// Las capas activas en este instante. El orden importa: la base primero.
  List<ClipLayer> _capas() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return const [];
    final base = _celebrating ? InstructorClips.idleParty : InstructorClips.idle;
    return [
      if (widget.idle) ClipLayer(clip: base, t: _idle.value),
    ];
  }
```

4. **`build`** pasa a:

```dart
  @override
  Widget build(BuildContext context) {
    final rig = _rig;
    final images = _images;
    if (rig == null || images == null) {
      return SizedBox(height: widget.height, width: widget.height * 0.63);
    }
    return AnimatedBuilder(
      animation: _loop,
      builder: (_, __) => InstructorRigView(
        rig: rig,
        images: images,
        pose: solveInstructorPose(rig, _capas()),
        height: widget.height,
      ),
    );
  }
```

5. Para que el test de reduce-motion pase, `_syncIdle()` debe **no arrancar** el bucle cuando `MediaQuery.disableAnimations` es true. Ya hay un chequeo de reduce-motion en el widget: reusalo, no dupliques la lectura.

- [ ] **Step 5: Correr para ver que pasa**

Run: `flutter test test/core/tutorial_instructor_rig_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Comprobar que no rompiste el resto**

Run: `flutter test && flutter analyze`
Expected: los tests que dependían de `Image`/`AssetImage` en `test/core/tutorial_instructor_test.dart` **van a fallar**: ese archivo prueba el sistema viejo. Reescribí sus aserciones contra el rig (`InstructorRigView` y `pose`), conservando el test *"la cabeza mide lo mismo en todas las poses"* como guardia de regresión — ahora es cierto por construcción, porque hay una sola pieza de cabeza. `flutter analyze` sin errores ni warnings nuevos.

- [ ] **Step 7: Commit**

```bash
git add lib/core/animations/instructor/instructor_clips.dart lib/core/widgets/tutorial_instructor.dart test/core/
git commit -m "feat(avatar): TutorialInstructor dibuja el rig; idle y parpadeo"
```

---

### Task 9: Hablar y lip-sync

**Files:**
- Modify: `lib/core/animations/instructor/instructor_clips.dart`
- Modify: `lib/core/widgets/tutorial_instructor.dart`
- Test: `test/core/instructor_lipsync_test.dart`

**Interfaces:**
- Consumes: `InstructorClips`, `TutorialVoice` (`VoiceClip` con `duration`).
- Produces: `InstructorClips.speak`, y `List<int> mouthSequence({required String voiceId, required Duration duration})` — la secuencia determinista de índices de boca (0..5) para una locución.

**Cubre Review Focus #3 (cambio de pose mientras suena la voz).**

**Límite declarado:** no hay datos de fonemas. Esto es movimiento de boca verosímil, no lip-sync real. La secuencia es determinista (semilla derivada de `voiceId`) para que sea testeable y para que no quede con cadencia de metrónomo.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/instructor_lipsync_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la secuencia de boca es determinista por voiceId', () {
    final a = mouthSequence(
        voiceId: 'ficha_01', duration: const Duration(seconds: 4));
    final b = mouthSequence(
        voiceId: 'ficha_01', duration: const Duration(seconds: 4));
    expect(a, b);
  });

  test('voiceId distinto da secuencia distinta', () {
    final a = mouthSequence(
        voiceId: 'ficha_01', duration: const Duration(seconds: 4));
    final b = mouthSequence(
        voiceId: 'ficha_02', duration: const Duration(seconds: 4));
    expect(a, isNot(b));
  });

  test('siempre cierra la boca al final', () {
    for (final id in ['ficha_01', 'ficha_07', 'calendario_00']) {
      final s = mouthSequence(voiceId: id, duration: const Duration(seconds: 3));
      expect(s.last, 0, reason: '$id no cierra la boca');
    }
  });

  test('la longitud escala con la duración y está acotada', () {
    expect(mouthSequence(voiceId: 'x', duration: const Duration(milliseconds: 200)).length,
        greaterThanOrEqualTo(2));
    expect(mouthSequence(voiceId: 'x', duration: const Duration(seconds: 60)).length,
        lessThanOrEqualTo(40));
  });

  test('nunca repite la misma abertura dos veces seguidas', () {
    final s = mouthSequence(voiceId: 'ficha_03', duration: const Duration(seconds: 8));
    for (var i = 1; i < s.length - 1; i++) {
      expect(s[i], isNot(s[i - 1]));
    }
  });

  testWidgets('cambiar de pose mientras habla no teletransporta la figura',
      (tester) async {
    Widget host(InstructorPose p, bool speaking) => CupertinoApp(
          home: Center(
            child: TutorialInstructor(
              height: 150, pose: p, speaking: speaking,
              speakDuration: const Duration(seconds: 3),
            ),
          ),
        );

    await tester.pumpWidget(host(InstructorPose.explica, true));
    await tester.pump(const Duration(milliseconds: 500));
    final antes = tester
        .widget<InstructorRigView>(find.byType(InstructorRigView))
        .pose['torso']!
        .getTranslation();

    await tester.pumpWidget(host(InstructorPose.celebra, true));
    await tester.pump(const Duration(milliseconds: 16));
    final despues = tester
        .widget<InstructorRigView>(find.byType(InstructorRigView))
        .pose['torso']!
        .getTranslation();

    // Un fotograma después el torso no puede haber saltado: el _settle()
    // deja terminar el ciclo en curso en vez de cortar la fase.
    expect((despues.x - antes.x).abs(), lessThan(4.0));
    expect((despues.y - antes.y).abs(), lessThan(4.0));
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/instructor_lipsync_test.dart`
Expected: FAIL — `mouthSequence` no está definida.

- [ ] **Step 3: Implementar**

En `lib/core/animations/instructor/instructor_clips.dart`, añadir a `InstructorClips`:

```dart
  /// Cabeceo mientras habla. No mueve la boca: eso lo hace [mouthSequence]
  /// conmutando sprites.
  static const speak = InstructorClip(
    name: 'speak',
    duration: Duration(milliseconds: 650),
    loop: true,
    tracks: {
      'cabeza': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.5, rot: 0.022, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
    },
  );
```

Y como función de librería en el mismo archivo:

```dart
/// Secuencia de aberturas de boca para una locución.
///
/// No hay datos de fonemas, así que esto es movimiento VEROSÍMIL, no lip-sync
/// real. La semilla sale del [voiceId] para que sea determinista (testeable) y
/// para que dos pasos distintos no muevan la boca igual. Nunca repite la misma
/// abertura seguida —eso es lo que delataría un ciclo fijo— y siempre cierra.
List<int> mouthSequence({
  required String voiceId,
  required Duration duration,
}) {
  // ~4.5 aberturas por segundo, acotado para clips muy cortos o muy largos.
  final n = (duration.inMilliseconds / 222).round().clamp(2, 40);
  var seed = 0;
  for (final u in voiceId.codeUnits) {
    seed = (seed * 31 + u) & 0x7fffffff;
  }
  const abiertas = [1, 2, 3, 4];
  final out = <int>[];
  var prev = -1;
  for (var i = 0; i < n - 1; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    var v = abiertas[(seed >> 8) % abiertas.length];
    if (v == prev) v = abiertas[(abiertas.indexOf(v) + 1) % abiertas.length];
    out.add(v);
    prev = v;
  }
  out.add(0); // cierra
  return out;
}
```

En `tutorial_instructor.dart`, añadir la capa de habla a `_capas()`:

```dart
      if (widget.speaking) ClipLayer(clip: InstructorClips.speak, t: _speak.value),
```

y elegir el sprite de boca a partir de `mouthSequence` y del avance de `_talk` (el mismo controlador que hoy cuenta los cambios de pose).

- [ ] **Step 4: Correr para ver que pasa**

Run: `flutter test test/core/instructor_lipsync_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/instructor/instructor_clips.dart lib/core/widgets/tutorial_instructor.dart test/core/instructor_lipsync_test.dart
git commit -m "feat(avatar): cabeceo al hablar y secuencia de boca determinista"
```

---

### Task 10: Gestos del repertorio ampliado

**Files:**
- Modify: `lib/core/animations/instructor/instructor_clips.dart`
- Modify: `lib/core/widgets/tutorial_instructor.dart` (valores nuevos del enum)
- Test: `test/core/instructor_gestos_test.dart`

**Interfaces:**
- Produces: `InstructorPose` gana `senala`, `pulgarArriba`, `alto`, `sorpresa`. `InstructorClips` gana `senala`, `pulgarArriba`, `alto`, `sorpresa`, `piensa`, `celebra`. `InstructorClip? clipForPose(InstructorPose p)`.

> El enum usa `senala` sin eñe: Dart admite la eñe en identificadores pero el repo no la usa en ninguno, y mezclarlo complica los `switch` exhaustivos al buscar.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/instructor_gestos_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

InstructorRig _rig() => InstructorRig.fromJson({
      'canonicalHeight': 800.0,
      'aspect': 0.63,
      'pieces': [
        {'name': 'torso', 'parent': null, 'asset': 't.png', 'pivot': [100.0, 400.0],
         'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 10},
        {'name': 'brazo_sup_der', 'parent': 'torso', 'asset': 'a.png',
         'pivot': [40.0, -60.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 12},
        {'name': 'antebrazo_der', 'parent': 'brazo_sup_der', 'asset': 'b.png',
         'pivot': [0.0, 90.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 12},
      ],
    });

void main() {
  test('cada pose nueva tiene su clip', () {
    for (final p in [
      InstructorPose.senala,
      InstructorPose.pulgarArriba,
      InstructorPose.alto,
      InstructorPose.sorpresa,
      InstructorPose.piensa,
      InstructorPose.celebra,
    ]) {
      expect(clipForPose(p), isNotNull, reason: 'falta el clip de $p');
    }
  });

  test('señalar tiene anticipación: el brazo baja antes de subir', () {
    final keys = InstructorClips.senala.tracks['brazo_sup_der']!;
    expect(keys.length, greaterThanOrEqualTo(4));
    // el primer tramo va en sentido contrario al destino
    final destino = keys.last.rot;
    final anticipa = keys[1].rot;
    expect(anticipa.sign, isNot(destino.sign),
        reason: 'sin anticipación el gesto arranca de la nada');
  });

  test('señalar hace overshoot y vuelve', () {
    final keys = InstructorClips.senala.tracks['brazo_sup_der']!;
    final maxAbs = keys.map((k) => k.rot.abs()).reduce((a, b) => a > b ? a : b);
    expect(maxAbs, greaterThan(keys.last.rot.abs()),
        reason: 'el brazo debe pasarse del objetivo y asentarse');
  });

  test('follow-through: el codo arranca después que el hombro', () {
    final hombro = InstructorClips.senala.tracks['brazo_sup_der']!;
    final codo = InstructorClips.senala.tracks['antebrazo_der']!;
    expect(codo.first.t, greaterThan(hombro.first.t),
        reason: 'el codo tiene que llegar tarde');
  });

  test('un gesto no congela el torso: no declara ese hueso', () {
    expect(InstructorClips.senala.tracks.containsKey('torso'), isFalse);
  });

  test('el gesto sólo mueve los huesos que declara', () {
    final rig = _rig();
    final pose = solveInstructorPose(
      rig,
      [ClipLayer(clip: InstructorClips.senala, t: 0.5)],
    );
    final t = pose['torso']!.getTranslation();
    expect(t.x, closeTo(100, 1e-9));
    expect(t.y, closeTo(400, 1e-9));
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/instructor_gestos_test.dart`
Expected: FAIL — `InstructorPose.senala` no existe.

- [ ] **Step 3: Implementar**

En `tutorial_instructor.dart`, añadir al enum (conservando los valores actuales y sus doc-comments):

```dart
  /// Señala hacia adelante con el índice. Gesto por paso del flujo.
  senala,

  /// Pulgar arriba: confirmación de que el usuario hizo lo correcto.
  pulgarArriba,

  /// Palma al frente: "espere un momento".
  alto,

  /// Ojos muy abiertos: reacción a algo inesperado.
  sorpresa,
```

En `instructor_clips.dart`, añadir los clips. `senala` como patrón de los demás:

```dart
  /// Señalar. Las tres primeras reglas de timing en un solo clip: anticipa
  /// bajando, se pasa del objetivo y se asienta, y el codo llega 60 ms
  /// después que el hombro (620 ms de clip -> 0.10 de fase).
  static const senala = InstructorClip(
    name: 'senala',
    duration: Duration(milliseconds: 620),
    tracks: {
      'brazo_sup_der': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.15, rot: 0.08, curve: AppCurves.smooth),   // anticipa
        BoneKey(t: 0.62, rot: -0.86, curve: AppCurves.snappy),  // overshoot
        BoneKey(t: 1.00, rot: -0.75, curve: AppCurves.bounce),  // asienta
      ],
      'antebrazo_der': [
        BoneKey(t: 0.10, rot: 0.0),
        BoneKey(t: 0.70, rot: -0.44, curve: AppCurves.snappy),
        BoneKey(t: 1.00, rot: -0.36, curve: AppCurves.bounce),
      ],
      'antena': [
        BoneKey(t: 0.00, rot: 0.0),
        BoneKey(t: 0.75, rot: -0.09, curve: AppCurves.smooth),
        BoneKey(t: 1.00, rot: 0.0, curve: AppCurves.bounce),
      ],
    },
  );
```

Escribí `pulgarArriba` (700 ms), `alto` (540 ms), `piensa` (800 ms, mueve `antebrazo_der` hacia el mentón y `cabeza` ladeada), `celebra` (900 ms, **los dos brazos desfasados 55 ms** — nunca simétricos) y `sorpresa` (400 ms, sólo `cabeza`) con la misma estructura de cuatro keyframes.

Y el mapeo:

```dart
InstructorClip? clipForPose(InstructorPose p) => switch (p) {
      InstructorPose.senala => InstructorClips.senala,
      InstructorPose.pulgarArriba => InstructorClips.pulgarArriba,
      InstructorPose.alto => InstructorClips.alto,
      InstructorPose.sorpresa => InstructorClips.sorpresa,
      InstructorPose.piensa => InstructorClips.piensa,
      InstructorPose.celebra => InstructorClips.celebra,
      InstructorPose.reposo || InstructorPose.explica ||
      InstructorPose.festeja || InstructorPose.saludo => null,
    };
```

Añadir la capa del gesto en `_capas()`, después de la base y antes de la de habla.

- [ ] **Step 4: Correr para ver que pasa**

Run: `flutter test test/core/instructor_gestos_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/instructor/instructor_clips.dart lib/core/widgets/tutorial_instructor.dart test/core/instructor_gestos_test.dart
git commit -m "feat(avatar): gestos del repertorio ampliado con anticipación y follow-through"
```

---

### Task 11: Caminata con el rig de perfil

**Files:**
- Modify: `lib/core/animations/instructor/instructor_rig.dart` (`profileRig`)
- Modify: `lib/core/animations/instructor/instructor_clips.dart` (`walkCycle`)
- Modify: `lib/core/widgets/tutorial_instructor.dart` (`walkIn` usa el rig de perfil)
- Test: `test/core/instructor_walk_test.dart`

**Interfaces:**
- Consumes: la clave `profile` del manifest (Task 3).
- Produces: `InstructorRig? get profileRig` en `InstructorRig` (o un segundo `loadInstructorRig` que devuelva ambos), e `InstructorClips.walkCycle` (1300 ms, bucle).

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/instructor_walk_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';

InstructorRig _perfil() => InstructorRig.fromJson({
      'canonicalHeight': 800.0,
      'aspect': 0.34,
      'pieces': [
        {'name': 'perfil_torso', 'parent': null, 'asset': 'pt.png',
         'pivot': [100.0, 500.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 10},
        {'name': 'perfil_muslo_a', 'parent': 'perfil_torso', 'asset': 'pa.png',
         'pivot': [0.0, 5.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 9},
        {'name': 'perfil_muslo_b', 'parent': 'perfil_torso', 'asset': 'pb.png',
         'pivot': [6.0, 5.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 7},
        {'name': 'perfil_brazo', 'parent': 'perfil_torso', 'asset': 'pbr.png',
         'pivot': [2.0, -20.0], 'anchor': [0.0, 0.0], 'size': [10, 10], 'z': 12},
      ],
    });

void main() {
  test('el ciclo de caminata cierra: el primer y el último keyframe coinciden', () {
    for (final entry in InstructorClips.walkCycle.tracks.entries) {
      final k = entry.value;
      expect(k.first.rot, closeTo(k.last.rot, 1e-9),
          reason: '${entry.key} no cierra el ciclo y daría un salto');
    }
  });

  test('las dos piernas van en contrafase', () {
    final a = InstructorClips.walkCycle.tracks['perfil_muslo_a']!;
    final b = InstructorClips.walkCycle.tracks['perfil_muslo_b']!;
    final ta = sampleTrack(a, 0.25).rot;
    final tb = sampleTrack(b, 0.25).rot;
    expect(ta.sign, isNot(tb.sign), reason: 'las piernas se mueven juntas');
  });

  test('el brazo balancea contra la pierna del mismo lado', () {
    final pierna = sampleTrack(
        InstructorClips.walkCycle.tracks['perfil_muslo_a']!, 0.25).rot;
    final brazo = sampleTrack(
        InstructorClips.walkCycle.tracks['perfil_brazo']!, 0.25).rot;
    expect(pierna.sign, isNot(brazo.sign));
  });

  test('la cabeza no sube ni baja durante el ciclo', () {
    expect(InstructorClips.walkCycle.tracks.containsKey('cabeza'), isFalse);
  });

  test('resuelve sobre el rig de perfil sin NaN', () {
    final rig = _perfil();
    for (var i = 0; i <= 12; i++) {
      final pose = solveInstructorPose(
          rig, [ClipLayer(clip: InstructorClips.walkCycle, t: i / 12)]);
      expect(pose.length, 4);
      for (final m in pose.values) {
        for (final v in m.storage) {
          expect(v.isNaN, isFalse);
        }
      }
    }
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/instructor_walk_test.dart`
Expected: FAIL — `InstructorClips.walkCycle` no existe.

- [ ] **Step 3: Implementar**

En `instructor_clips.dart`:

```dart
  /// Ciclo de caminata de perfil. 1300 ms como el `_walkDur` de siempre.
  ///
  /// La cabeza NO figura a propósito: en un ciclo de caminata el cráneo se
  /// queda quieto y sólo se mueven las extremidades. Si la cabeza cabecea, la
  /// entrada parece un salto de canguro.
  static const walkCycle = InstructorClip(
    name: 'walk',
    duration: Duration(milliseconds: 1300),
    loop: true,
    tracks: {
      'perfil_muslo_a': [
        BoneKey(t: 0.0, rot: 0.34),
        BoneKey(t: 0.5, rot: -0.34, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.34, curve: AppCurves.smooth),
      ],
      'perfil_muslo_b': [
        BoneKey(t: 0.0, rot: -0.34),
        BoneKey(t: 0.5, rot: 0.34, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: -0.34, curve: AppCurves.smooth),
      ],
      'perfil_pantorrilla_a': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.3, rot: 0.46, curve: AppCurves.smooth),
        BoneKey(t: 0.6, rot: 0.0, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0),
      ],
      'perfil_pantorrilla_b': [
        BoneKey(t: 0.0, rot: 0.0),
        BoneKey(t: 0.1, rot: 0.0),
        BoneKey(t: 0.8, rot: 0.46, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: 0.0, curve: AppCurves.smooth),
      ],
      'perfil_brazo': [
        BoneKey(t: 0.0, rot: -0.26),
        BoneKey(t: 0.5, rot: 0.26, curve: AppCurves.smooth),
        BoneKey(t: 1.0, rot: -0.26, curve: AppCurves.smooth),
      ],
    },
  );
```

En `instructor_rig.dart`, parsear la clave `profile` del manifest como un `InstructorRig` aparte y exponerlo (`InstructorRig? profile`). En `tutorial_instructor.dart`, cuando `_walking` sea true, renderizar con el rig de perfil y la capa `walkCycle`, con la traslación horizontal que ya calcula el `_walk` existente.

- [ ] **Step 4: Correr para ver que pasa**

Run: `flutter test test/core/instructor_walk_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/animations/instructor/ lib/core/widgets/tutorial_instructor.dart test/core/instructor_walk_test.dart
git commit -m "feat(avatar): caminata de entrada con el rig de perfil articulado"
```

---

### Task 12: Integración, verificación en dispositivo y retiro del set viejo

**Files:**
- Modify: `lib/core/widgets/tutorial_coach_overlay.dart:249`
- Modify: `lib/core/widgets/tutorial_invite_dialog.dart`
- Delete: `assets/images/instructora_*.png` (17 archivos)
- Delete: `tools/extract_instructor_frames.py`, `tools/build_instructor_poses.py`, `tools/build_instructor_walk.py`
- Modify: `docs/setup/claude-config/memory/instructora-tutorial-asset.md`
- Test: `test/core/instructor_integracion_test.dart`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: el coach y el diálogo leyendo el aspecto del manifest en vez de tenerlo escrito a mano.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/instructor_integracion_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el manifest está empaquetado y es coherente', () async {
    final raw = await rootBundle.loadString(
        'assets/images/instructor/manifest.json');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    expect(m['canonicalHeight'], 800);
    final piezas = (m['pieces'] as List).cast<Map<String, dynamic>>();
    final nombres = piezas.map((p) => p['name'] as String).toSet();
    for (final n in ['torso', 'cabeza', 'antena', 'brazo_sup_der',
                     'antebrazo_der', 'muslo_izq', 'pantorrilla_der']) {
      expect(nombres, contains(n));
    }
    expect(m.containsKey('profile'), isTrue);
  });

  test('cada asset del manifest existe en el bundle', () async {
    final raw = await rootBundle.loadString(
        'assets/images/instructor/manifest.json');
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final todas = [
      ...(m['pieces'] as List).cast<Map<String, dynamic>>(),
      ...((m['profile']?['pieces'] ?? []) as List).cast<Map<String, dynamic>>(),
    ];
    for (final p in todas) {
      final path = 'assets/images/instructor/${p['asset']}';
      expect(() async => rootBundle.load(path), returnsNormally,
          reason: 'falta $path');
    }
  });

  test('no quedan assets del avatar viejo referenciados', () async {
    // Si esto falla, alguien dejó una referencia al set retirado.
    expect(
      () async => rootBundle.load('assets/images/instructora_explica.png'),
      throwsA(anything),
    );
  });
}
```

- [ ] **Step 2: Correr para ver que falla**

Run: `flutter test test/core/instructor_integracion_test.dart`
Expected: FAIL en el tercer test — `instructora_explica.png` todavía está empaquetada.

- [ ] **Step 3: Cablear el aspecto en el coach**

En `lib/core/widgets/tutorial_coach_overlay.dart:249`, reemplazar:

```dart
    final charW = charH * 0.58; // proporción del asset (405×700)
```

por el aspecto que expone el rig ya cargado. Si el coach no tiene el rig a mano, expone `TutorialInstructor` una constante estática `kInstructorAspectFallback = 0.63` y el widget ajusta su ancho por sí mismo — pero el número **no** vuelve a escribirse a mano en dos sitios. Hacer lo mismo en `tutorial_invite_dialog.dart` si tiene un cálculo equivalente.

- [ ] **Step 4: Retirar el set viejo**

```bash
git rm assets/images/instructora_*.png
git rm tools/extract_instructor_frames.py tools/build_instructor_poses.py tools/build_instructor_walk.py
```

Quitar de `tutorial_instructor.dart` cualquier resto de `kInstructorAssets`, `kTutorialInstructorAsset` y `_kWalkSettleFrame`, y arreglar los imports que rompan.

- [ ] **Step 5: Correr todo**

Run: `flutter analyze && flutter test`
Expected: 0 errores, 0 warnings, **todos** los tests en verde (los 147 previos más los nuevos). Si algún test viejo referencia assets retirados, actualizarlo — no borrarlo.

- [ ] **Step 6: Verificación en dispositivo (obligatoria)**

No se da por terminado sin esto:

```bash
flutter run --release -d <dispositivo>
```

1. Recorrer el tutorial completo de punta a punta.
2. Activar el overlay de rendimiento y mirarlo durante un gesto y durante la caminata de entrada.
3. Comprobar la legibilidad de la cara en el peor caso: teléfono chico, `charH` = 124 px lógicos.
4. Activar reduce-motion en Ajustes del sistema y confirmar que la instructora queda estática.

Anotar el resultado de los cuatro puntos en el commit. Si el overlay muestra fotogramas perdidos durante un gesto, **no** subir el número de piezas: revisar primero que `RepaintBoundary` esté envolviendo y que `shouldRepaint` no devuelva siempre `true`.

- [ ] **Step 7: Actualizar la memoria del proyecto**

Reescribir `docs/setup/claude-config/memory/instructora-tutorial-asset.md`: hoy describe el pipeline de poses recortadas de láminas de Gemini, que deja de existir. Debe pasar a describir el rig, el pipeline de `tools/build_instructor_v2.py`, y conservar la lección del límite estructural del fundido cruzado como el **motivo** del cambio.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(avatar): integra el rig v2 y retira el set de poses anterior"
```

---

## Self-Review

**Cobertura del spec:**

| Sección del spec | Tarea |
|---|---|
| §1 costura y API conservada | Task 8 (Step 4 punto 1), Task 12 |
| §1 cinco unidades | Tasks 5, 6, 7, 8 |
| §2 anatomía y polígonos | Task 1 |
| §2 cabeza de la Lámina 1, ×1.0395, corte 12–18 px | Task 2 |
| §2 síntesis del medio parpadeo | Task 2 Step 4 (`squash`) |
| §2 manos normalizadas por muñeca | Task 3 |
| §2 figura canónica 800 px, peso ≤450 KB | Tasks 1 y 4 |
| §2 manifest + imagen de control | Tasks 1 y 4 |
| §3 datos puros, solver, capas aditivas | Tasks 5 y 6 |
| §3 CustomPainter sobre RepaintBoundary | Task 7 |
| §3 invariantes (sin NaN, padre existente, sin ciclos) | Tasks 1, 5, 6 |
| §4 catálogo de clips | Tasks 8, 9, 10, 11 |
| §4 cinco reglas de timing | Task 10 (tests de anticipación, overshoot, follow-through, asimetría) |
| §4 lip-sync y su límite declarado | Task 9 |
| §4 reduce-motion | Task 8 |
| §5 `charW` desde el manifest | Task 12 Step 3 |
| §5 tests y verificación en dispositivo | Task 12 Steps 5 y 6 |
| §5 orden de retiro | Task 12 Steps 4 y 7 |

**Placeholders:** el único "por calibrar" intencional son `eyeRect` y `mouthRect` en la Task 2 Step 3 — llevan valores de partida concretos y un paso de calibración con criterio de aceptación explícito (Step 6). No es un hueco de diseño: es que el rectángulo exacto se ve mirando el recorte, no calculándolo.

**Consistencia de tipos:** `InstructorBone`, `InstructorRig`, `BoneKey`, `BoneTransform`, `InstructorClip`, `ClipLayer`, `sampleTrack`, `solveInstructorPose`, `InstructorImages`, `InstructorRigView`, `InstructorRigPainter`, `clipForPose`, `mouthSequence` — usados con la misma firma en todas las tareas. Los nombres de hueso (`torso`, `cabeza`, `antena`, `brazo_sup_der`, `antebrazo_der`, `muslo_izq`, `pantorrilla_der`, `perfil_*`) coinciden entre el JSON de la Task 1/3 y los clips de las Tasks 8–11.

**Review Focus:** las cinco líneas tienen test asignado — reduce-motion y desmontaje en Task 8, pieza faltante y `height` extremo en Task 7, cambio de pose durante la voz en Task 9.
