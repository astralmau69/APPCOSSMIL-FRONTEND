# Colab RVC v2 — voz de la instructora (headless, Applio)

Cuaderno headless (solo celdas) para entrenar la voz con tu dataset y clonar en
lote las 19 líneas del tutorial. Usa **Applio** (fork de RVC v2 con CLI `core.py`:
`preprocess / extract / train / index / infer` — pensado para correr sin GUI).

**Antes:** Runtime → Change runtime type → **GPU (T4)**. Sube tu carpeta
`tools/rvc/` a Drive (con `tutorial_lines.json`, `gen_source_tts.py` y tu dataset
de WAV limpios en `tools/rvc/rvc_dataset/`).

> **Reglas de oro del dataset (antes de subirlo a Drive):** la calidad del modelo
> depende MÁS del dataset que de los epochs. Con 300 epochs sobre datos sucios
> solo memorizas el ruido. Asegura:
> - **Una sola voz**, sin música ni otra persona de fondo.
> - **Sin ruido de fondo** ni reverb (nada de eco de sala); voz "seca" y limpia.
> - **Fragmentos cortos de 10–15 s**, cortados en límites de frase.
> - **Sin silencios largos** al inicio/fin ni entre frases (recórtalos).
> - **Normalizado** a un volumen parejo (mono, 44.1 kHz — lo hace `prep_dataset.sh`).
> - **Cuanta más voz limpia, mejor:** 1 min funciona, 5–10 min saca mucho más.
> - Timbre **coherente** (misma cercanía al micro, mismo tono emocional).
>
> Nota honesta: el tooling RVC cambia seguido. Si un flag no existe, corre
> `!python core.py <comando> -h` y ajusta el nombre. El resto del flujo es estable.

---

### Celda 1 — Drive + GPU + ruta

```python
from google.colab import drive
drive.mount('/content/drive')
!nvidia-smi -L
import os
RVC_DIR = '/content/drive/MyDrive/tools/rvc'   # ajusta si la subiste a otra ruta
assert os.path.isdir(RVC_DIR), f'No existe {RVC_DIR}'
```

### Celda 2 — Instalar Applio + modelos base (hubert, rmvpe, pretrained v2)

```python
%cd /content
!git clone https://github.com/IAHispano/Applio
%cd /content/Applio
!pip -q install -r requirements.txt
!python core.py prerequisites          # descarga pesos base (unos minutos)
# Si pip rompe torch: Runtime > Restart runtime y re-ejecuta desde aquí.
```

### Celda 3 — Narración base con tu `gen_source_tts.py` (edge-tts) → WAV

```python
import os, glob, subprocess
!pip -q install edge-tts
# Voz base FEMENINA para que calce con la voz objetivo (mujer amigable): así el
# f0 ya está en el registro correcto y en la Celda 5 --pitch 0 es válido. Con
# una base masculina saldría metálica. Alternativa latina neutra: es-MX-DaliaNeural.
!python "{RVC_DIR}/gen_source_tts.py" \
    --lines "{RVC_DIR}/tutorial_lines.json" \
    --out /content/source_tts --voice es-BO-SofiaNeural --rate -8%
# edge-tts entrega mp3; RVC va más fino con WAV mono 44.1k:
os.makedirs('/content/source_wav', exist_ok=True)
for f in glob.glob('/content/source_tts/*.mp3'):
    wid = os.path.splitext(os.path.basename(f))[0]
    subprocess.run(['ffmpeg','-y','-i',f,'-ac','1','-ar','44100',
                    f'/content/source_wav/{wid}.wav'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print('WAVs base:', len(glob.glob('/content/source_wav/*.wav')))
```

### Celda 4 — Entrenar el modelo con tu dataset (~1 min de voz)

```python
MODEL, SR = 'instructora', 40000
DATASET = f'{RVC_DIR}/rvc_dataset'     # tus WAV limpios de la voz vof
assert os.path.isdir(DATASET), f'Sube tu dataset a {DATASET}'

%cd /content/Applio
!python core.py preprocess --model_name {MODEL} --dataset_path "{DATASET}" --sample_rate {SR}
!python core.py extract    --model_name {MODEL} --sample_rate {SR} --f0_method rmvpe
# Dataset chico → epochs moderados para NO sobreajustar (parte de un pretrained).
!python core.py train      --model_name {MODEL} --sample_rate {SR} \
    --total_epoch 300 --save_every_epoch 50 --batch_size 8
!python core.py index      --model_name {MODEL}
```

### Celda 5 — Clonación en lote (edge-tts → voz vof)

```python
import glob, os, subprocess
APPLIO = '/content/Applio'; LOG = f'{APPLIO}/logs/{MODEL}'
PTH   = sorted(glob.glob(f'{LOG}/*.pth'),   key=os.path.getmtime)[-1]
INDEX = sorted(glob.glob(f'{LOG}/*.index'), key=os.path.getmtime)[-1]
print('modelo:', PTH, '\nindex :', INDEX)

os.makedirs('/content/rvc_out', exist_ok=True)
for wav in sorted(glob.glob('/content/source_wav/*.wav')):
    wid = os.path.splitext(os.path.basename(wav))[0]
    subprocess.run(['python','core.py','infer',
        '--pth_path', PTH, '--index_path', INDEX,
        '--input_path', wav, '--output_path', f'/content/rvc_out/{wid}.wav',
        '--f0_method','rmvpe','--pitch','0','--index_rate','0.7'],
        check=True, cwd=APPLIO)
    print('convertido:', wid)
```

### Celda 6 — Exportar `<id>.mp3` + ZIP descargable

```python
import glob, os, subprocess, shutil
OUT = '/content/vof_tutorial'; os.makedirs(OUT, exist_ok=True)
for w in glob.glob('/content/rvc_out/*.wav'):
    wid = os.path.splitext(os.path.basename(w))[0]
    subprocess.run(['ffmpeg','-y','-i',w,'-ac','1','-ar','44100','-b:a','128k',
                    f'{OUT}/{wid}.mp3'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
shutil.make_archive('/content/vof_tutorial', 'zip', OUT)
shutil.copy('/content/vof_tutorial.zip', f'{RVC_DIR}/vof_tutorial.zip')   # respaldo en Drive
from google.colab import files; files.download('/content/vof_tutorial.zip')
print('Listo:', len(glob.glob(f'{OUT}/*.mp3')), 'clips → extrae el ZIP en assets/vof_tutorial/')
```

---

**Ajustes rápidos si la voz no calza:** en la Celda 5 sube `--index_rate` a 0.8
(más timbre del modelo). Mantén la base FEMENINA de la Celda 3 y `--pitch 0`;
solo toca `--pitch` en pasos de ±1/±2 semitonos para afinar el registro. Prueba
otras voces femeninas de edge-tts (`!edge-tts --list-voices | grep es-`), p. ej.
`es-MX-DaliaNeural`, `es-CO-SalomeNeural`, `es-AR-ElenaNeural`.
