# COSSMIL — generación de clips con XTTS v2

El paquete usa la referencia `voice_reference_full.wav` y los textos exactos del guion para generar todos los IDs encontrados.

> Nota: el encabezado del guion dice **18 clips**, pero el contenido enumera **19**: `invite` + 8 `ficha_*` + 5 `calendario_*` + 5 `tramites_*`. Por seguridad se conservaron los 19.

## Archivos

- `voice_reference_full.wav` — referencia de voz.
- `tutorial_lines.json` — textos por ID.
- `generate_xtts.py` — generador.
- `assets/vof_tutorial/` — salida final para Flutter.

## Instalación recomendada en Debian

Con `uv`:

```bash
sudo apt update
sudo apt install -y ffmpeg
uv venv .venv
source .venv/bin/activate
uv pip install torch torchaudio torchcodec --torch-backend=auto
uv pip install coqui-tts
python generate_xtts.py
```

Con `pip`, instala primero PyTorch/torchaudio apropiados para tu CPU o GPU y después:

```bash
pip install coqui-tts
python generate_xtts.py
```

La primera ejecución descargará XTTS v2. XTTS acepta uno o varios archivos de referencia para clonación de voz; este paquete utiliza la referencia combinada.

## Salida

Los archivos terminan en:

```text
assets/vof_tutorial/invite.mp3
assets/vof_tutorial/ficha_00.mp3
...
assets/vof_tutorial/tramites_04.mp3
```

El script convierte cada clip a MP3 mono, 44.1 kHz, elimina silencio inicial/final, añade ~250 ms de cola y ralentiza levemente el habla (`atempo=0.95`) para acercarse al ritmo pausado solicitado.
