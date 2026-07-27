#!/usr/bin/env python3
"""Genera la NARRACIÓN FUENTE del tutorial con edge-tts (TTS neuronal gratis).

RVC convierte el TIMBRE de una grabación, pero conserva su prosodia y su
tiempo. O sea: necesitas una narración base leyendo cada línea. En vez de
grabarla a mano, este script la sintetiza con edge-tts (voces neuronales de
Microsoft en español, sin API key). Luego RVC la transforma a la voz vof.

Uso (en Colab o local, con internet):

    pip install edge-tts
    python3 tools/rvc/gen_source_tts.py --out source_tts --voice es-BO-SofiaNeural

Elige la voz que MÁS se parezca a la vof, sobre todo del MISMO GÉNERO: si la
voz objetivo es femenina, usa una base femenina o el f0 no calzará y RVC saldrá
metálico (con base masculina + pitch 0 se distorsiona). La instructora es una
mujer amigable → usa una voz femenina. Voces femeninas útiles en español:
    es-BO-SofiaNeural (boliviana), es-MX-DaliaNeural (latina neutra),
    es-CO-SalomeNeural, es-AR-ElenaNeural, es-ES-ElviraNeural
Lista completa:  edge-tts --list-voices | grep es-

Salida: source_tts/<id>.wav  (uno por línea de tutorial_lines.json).
Después conviértelos en lote con RVC → assets/vof_tutorial/<id>.mp3
"""

import argparse
import asyncio
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


async def _synth(text, voice, rate, out_path):
    import edge_tts  # import tardío: solo hace falta al generar

    communicate = edge_tts.Communicate(text, voice=voice, rate=rate)
    await communicate.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lines", default=os.path.join(HERE, "tutorial_lines.json"))
    ap.add_argument("--out", default="source_tts")
    ap.add_argument("--voice", default="es-BO-SofiaNeural")
    ap.add_argument("--rate", default="-8%", help="velocidad, p.ej. -8% más lento")
    a = ap.parse_args()

    with open(a.lines, encoding="utf-8") as fh:
        lines = json.load(fh)["lines"]
    os.makedirs(a.out, exist_ok=True)

    for lid, text in lines.items():
        # edge-tts entrega mp3; guardamos como .mp3 y RVC lo acepta. (Para WAV,
        # reconviértelo con ffmpeg si tu build de RVC lo prefiere.)
        out = os.path.join(a.out, f"{lid}.mp3")
        try:
            asyncio.run(_synth(text, a.voice, a.rate, out))
            print(f"  {lid}  ->  {out}")
        except Exception as e:  # noqa: BLE001
            sys.exit(f"Error con edge-tts en '{lid}': {e}\n¿Instalaste edge-tts y hay internet?")

    print(f"\nNarración fuente lista en '{a.out}' ({len(lines)} clips).")
    print("Siguiente: conviértelos con tu modelo RVC → assets/vof_tutorial/<id>.mp3")


if __name__ == "__main__":
    main()
