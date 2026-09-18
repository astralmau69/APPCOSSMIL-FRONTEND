#!/usr/bin/env python3
from pathlib import Path
import json, subprocess, shutil
import torch
from TTS.api import TTS

ROOT = Path(__file__).resolve().parent
REF = ROOT / "voice_reference_full.wav"
LINES = ROOT / "tutorial_lines.json"
OUT = ROOT / "assets" / "vof_tutorial"
TMP = ROOT / ".wav_tmp"
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)

if not REF.exists():
    raise SystemExit(f"Falta la referencia de voz: {REF}")
if shutil.which("ffmpeg") is None:
    raise SystemExit("Falta ffmpeg. Instálalo con: sudo apt install ffmpeg")

items = json.loads(LINES.read_text(encoding="utf-8"))
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Cargando XTTS v2 en {device}...")
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)

for i, item in enumerate(items, 1):
    clip_id = item["id"]
    text = item["text"]
    wav = TMP / f"{clip_id}.wav"
    mp3 = OUT / f"{clip_id}.mp3"
    print(f"[{i:02d}/{len(items)}] {clip_id}")
    tts.tts_to_file(
        text=text,
        speaker_wav=str(REF),
        language="es",
        file_path=str(wav),
    )
    # Quita silencio inicial/final, ralentiza levemente y deja ~250 ms al final.
    af = (
        "silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB:"
        "stop_periods=-1:stop_duration=0.15:stop_threshold=-45dB,"
        "atempo=0.95,apad=pad_dur=0.25"
    )
    subprocess.run([
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(wav),
        "-af", af,
        "-ac", "1", "-ar", "44100", "-b:a", "128k",
        str(mp3),
    ], check=True)

print(f"\nListo. Audios generados en: {OUT}")
