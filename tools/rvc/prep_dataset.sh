#!/usr/bin/env bash
# Prepara el DATASET de entrenamiento para RVC v2 a partir de las locuciones vof.
#
# RVC entrena con muestras limpias de UNA sola voz. Las vof (assets/vof/*.mp3)
# son justo eso: la voz de la instructora. Este script las convierte a WAV mono
# 44.1 kHz normalizado (RVC hace su propio "slicing" en trozos cortos, así que
# no hace falta cortarlas a mano).
#
#   bash tools/rvc/prep_dataset.sh [SRC=assets/vof] [OUT=rvc_dataset]
#
# Sube la carpeta OUT (comprimida) a RVC como carpeta de entrenamiento.
# Sugerencia: cuanta más voz limpia, mejor. Si tienes más grabaciones de la
# misma voz, ponlas también en OUT antes de entrenar (2–10 min es un buen rango).
set -euo pipefail

SRC="${1:-assets/vof}"
OUT="${2:-rvc_dataset}"

command -v ffmpeg >/dev/null || { echo "Falta ffmpeg"; exit 1; }
mkdir -p "$OUT"

i=0
for f in "$SRC"/*.mp3; do
  [ -e "$f" ] || continue
  i=$((i + 1))
  base=$(printf 'vof_%02d' "$i")
  ffmpeg -y -i "$f" -ac 1 -ar 44100 \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
    "$OUT/$base.wav" >/dev/null 2>&1
  dur=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$OUT/$base.wav" 2>/dev/null || echo "?")
  echo "  $f  ->  $OUT/$base.wav  (${dur}s)"
done

echo ""
echo "Dataset listo en '$OUT' ($i clips). Comprímelo y súbelo a RVC:"
echo "  zip -r rvc_dataset.zip '$OUT'"
