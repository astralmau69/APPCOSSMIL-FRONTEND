"""Valida las piezas del avatar v2. Sale != 0 si algo no cumple.

Reporta numeros, no opiniones. Es la puerta de calidad entre las laminas
generadas y el repo: nada entra a `assets/images/instructor/` sin pasar por
aqui. Ver `tools/instructor_v2_prompts.md` para los criterios y su origen.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path("assets/images/instructor")
FAILS = []


def check(cond, msg):
    if cond:
        print(f"  OK    {msg}")
    else:
        print(f"  FALLA {msg}")
        FAILS.append(msg)


def _piece_checks(m, names):
    for p in m["pieces"]:
        f = OUT / p["asset"]
        check(f.exists(), f"existe {p['asset']}")
        if not f.exists():
            continue
        a = np.asarray(Image.open(f).convert("RGBA"))
        check(
            a.shape[1] == p["size"][0] and a.shape[0] == p["size"][1],
            f"{p['name']}: size del manifest coincide con el PNG",
        )
        check(a[..., 3].max() > 0, f"{p['name']}: no esta vacia")
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        halo = int(((r > 170) & (g < 130) & (b > 170) & (al > 20)).sum())
        check(
            halo < 0.001 * al.size,
            f"{p['name']}: sin halo magenta ({halo} px de {al.size})",
        )
        ax, ay = p["anchor"]
        check(
            0 <= ax <= p["size"][0] and 0 <= ay <= p["size"][1],
            f"{p['name']}: anchor dentro del PNG",
        )
        if p["parent"] is not None:
            check(p["parent"] in names, f"{p['name']}: padre '{p['parent']}' existe")


def _no_cycles(m, names):
    parent = {p["name"]: p["parent"] for p in m["pieces"]}
    for n in names:
        seen, cur = set(), n
        while cur is not None:
            if cur in seen:
                check(False, f"ciclo en la jerarquia en '{n}'")
                break
            seen.add(cur)
            cur = parent.get(cur)


def main():
    mf = OUT / "manifest.json"
    check(mf.exists(), f"existe {mf}")
    if not mf.exists():
        return finish()

    m = json.loads(mf.read_text(encoding="utf-8"))
    check(m.get("canonicalHeight") == 800, "canonicalHeight == 800")
    check(0.5 < m.get("aspect", 0) < 0.9, "aspect entre 0.5 y 0.9")

    names = [p["name"] for p in m["pieces"]]
    check(len(names) == len(set(names)), "nombres de pieza unicos")

    _piece_checks(m, names)
    _no_cycles(m, names)

    # La cobertura la mide el cortador y la deja en el manifest: aqui solo se
    # exige el umbral. Un hueco significa que un poligono se quedo corto.
    cov = m.get("coverage", {})
    check(
        cov.get("cubierto", 0) >= 99.0,
        f"cobertura de la figura {cov.get('cubierto', 0):.1f}% (minimo 99%)",
    )
    # El solape agregado es alto por construccion: ocho articulaciones mas los
    # casquetes de hombro y cadera. Un rig SIN solape se desgarraria en cada
    # giro. Lo que hay que impedir es que una pieza se trague a otra.
    check(
        cov.get("solapado", 100) <= 20.0,
        f"solape agregado {cov.get('solapado', 100):.1f}% (maximo 20%)",
    )
    check(
        cov.get("peorPar", 100) <= 70.0,
        f"peor par de piezas {cov.get('peorPar', 100):.0f}% de la menor (maximo 70%)",
    )

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
