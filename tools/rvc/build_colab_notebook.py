"""Genera tools/rvc/COSSMIL_voces_guiado.ipynb autocontenido (vof + guion embebidos).

Uso: python3 tools/rvc/build_colab_notebook.py   (editar ESTE script, no el .ipynb)
"""
import base64, glob, json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
lines = json.load(open(f'{ROOT}/tools/rvc/tutorial_lines.json', encoding='utf-8'))['lines']
vof = {}
for i, f in enumerate(sorted(glob.glob(f'{ROOT}/assets/vof/*.mp3')), 1):
    vof[f'vof_{i:02d}.mp3'] = base64.b64encode(open(f, 'rb').read()).decode()

def md(src): return {'cell_type': 'markdown', 'metadata': {}, 'source': src}
def code(src): return {'cell_type': 'code', 'metadata': {}, 'execution_count': None, 'outputs': [], 'source': src}

cells = [
md("""# COSSMIL — voces de la instructora (RVC v2 / Applio)

Entrena la voz de la instructora con las locuciones `vof` (ya vienen **dentro** de este cuaderno) y genera los clips del tutorial, incluidas las 8 voces nuevas `guiado_*`.

**Cómo usarlo:**
1. `Entorno de ejecución → Cambiar tipo de entorno → GPU T4`.
2. `Entorno de ejecución → Ejecutar todo`.
3. Al final se descarga `vof_tutorial.zip`. Extrae los `.mp3` **directo** en `assets/vof_tutorial/` (sin subcarpeta).

Tarda aprox. 30–60 min (la mayor parte es el entrenamiento). Si la sesión se corta, con `USAR_DRIVE=True` el modelo queda respaldado en Drive y la celda 5 lo reutiliza sin reentrenar."""),
code("""#@title 1 · Configuración
SOLO_GUIADO = False   #@param {type:"boolean"}
# False = regenera las 27 líneas (recomendado: toda la app queda con la MISMA voz del modelo nuevo)
# True  = solo las 8 guiado_* (más rápido, pero pueden sonar algo distintas a los clips viejos)
USAR_DRIVE = True     #@param {type:"boolean"}
# Respalda el modelo y el ZIP en MyDrive/cossmil_rvc (sobrevive a desconexiones)
SUBIR_AUDIO_EXTRA = False  #@param {type:"boolean"}
# True = te pide subir más grabaciones limpias de la MISMA locutora (mp3/wav/m4a). 3–5 min extra mejoran mucho la claridad.
VOZ_BASE = "es-BO-SofiaNeural"  #@param ["es-BO-SofiaNeural", "es-MX-DaliaNeural", "es-CO-SalomeNeural", "es-AR-ElenaNeural"]
VELOCIDAD = "-8%"     #@param {type:"string"}
EPOCHS = 300          #@param {type:"integer"}
PITCH = 0             #@param {type:"integer"}
INDEX_RATE = 0.7      #@param {type:"number"}
MODEL, SR = 'instructora', 40000

import subprocess
gpu = subprocess.run(['nvidia-smi', '-L'], capture_output=True, text=True).stdout
assert 'GPU' in gpu, 'No hay GPU: Entorno de ejecución → Cambiar tipo de entorno → T4 GPU'
print(gpu)

import os
BACKUP = None
if USAR_DRIVE:
    from google.colab import drive
    drive.mount('/content/drive')
    BACKUP = '/content/drive/MyDrive/cossmil_rvc'
    os.makedirs(BACKUP, exist_ok=True)
    print('Respaldo en', BACKUP)"""),
code("""#@title 2 · Dataset (vof embebidas → WAV mono 44.1 kHz normalizado)
import base64, glob, os, subprocess, shutil
VOF = %s
RAW, DATASET = '/content/raw_audio', '/content/rvc_dataset'
shutil.rmtree(RAW, ignore_errors=True); shutil.rmtree(DATASET, ignore_errors=True)
os.makedirs(RAW); os.makedirs(DATASET)
for name, b64 in VOF.items():
    open(f'{RAW}/{name}', 'wb').write(base64.b64decode(b64))

if SUBIR_AUDIO_EXTRA:
    from google.colab import files
    print('Sube grabaciones extra de la MISMA voz (sin música ni eco):')
    for name, data in files.upload().items():
        open(f'{RAW}/extra_{name}', 'wb').write(data)

total = 0.0
for i, f in enumerate(sorted(glob.glob(f'{RAW}/*')), 1):
    out = f'{DATASET}/clip_{i:02d}.wav'
    subprocess.run(['ffmpeg', '-y', '-i', f, '-ac', '1', '-ar', '44100',
                    '-af', 'silenceremove=start_periods=1:start_threshold=-45dB:stop_periods=-1:stop_duration=0.6:stop_threshold=-45dB,loudnorm=I=-16:TP=-1.5:LRA=11',
                    out], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    d = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                              '-of', 'default=nk=1:nw=1', out], capture_output=True, text=True).stdout)
    total += d
    print(f'  {os.path.basename(f):28s} → {os.path.basename(out)}  {d:5.1f}s')
print(f'\\nDataset: {len(glob.glob(DATASET + "/*.wav"))} clips, {total/60:.1f} min de voz')""" % json.dumps(vof)),
code("""#@title 3 · Instalar Applio (RVC v2) + modelos base
%cd /content
import os
if not os.path.isdir('/content/Applio'):
    !git clone --depth 1 https://github.com/IAHispano/Applio
%cd /content/Applio
!pip -q install -r requirements.txt
!python core.py prerequisites
!pip -q install edge-tts
# Verificación: core.py debe arrancar. Mostramos la ayuda de cada comando (sirve para diagnosticar).
import subprocess, os
ENV = {**os.environ, 'COLUMNS': '200', 'NO_COLOR': '1', 'TERM': 'dumb'}
for cmd in ('preprocess', 'extract', 'train', 'index', 'infer'):
    chk = subprocess.run(['python', 'core.py', cmd, '--help'], cwd='/content/Applio', capture_output=True, text=True, env=ENV)
    print(f'===== {cmd} =====')
    print((chk.stdout + chk.stderr)[-2500:])
    assert chk.returncode == 0, f'Applio no arranca ("{cmd} --help" falló): copia el error de arriba.'
print('Applio listo ✔')"""),
code("""#@title 4 · Narración base con edge-tts (voz femenina) → WAV
import asyncio, os, glob, subprocess, shutil, edge_tts
LINES = %s
if SOLO_GUIADO:
    LINES = {k: v for k, v in LINES.items() if k.startswith('guiado_')}

SRC_MP3, SRC_WAV = '/content/source_tts', '/content/source_wav'
for d in (SRC_MP3, SRC_WAV):
    shutil.rmtree(d, ignore_errors=True); os.makedirs(d)

async def synth_all():
    for lid, text in LINES.items():
        await edge_tts.Communicate(text, voice=VOZ_BASE, rate=VELOCIDAD).save(f'{SRC_MP3}/{lid}.mp3')
        subprocess.run(['ffmpeg', '-y', '-i', f'{SRC_MP3}/{lid}.mp3', '-ac', '1', '-ar', '44100',
                        f'{SRC_WAV}/{lid}.wav'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print('  ', lid)
await synth_all()
print(f'\\n{len(LINES)} narraciones base listas')""" % json.dumps(lines, ensure_ascii=False, indent=1)),
code("""#@title 5 · Entrenar el modelo (se salta si ya hay uno respaldado en Drive)
import glob, os, shutil, subprocess
APPLIO = '/content/Applio'; LOG = f'{APPLIO}/logs/{MODEL}'

ENV = {**os.environ, 'COLUMNS': '200', 'NO_COLOR': '1', 'TERM': 'dumb'}

def _run(cmd, show=True):
    # En Colab subprocess.run NO muestra la salida en la celda: la leemos y la imprimimos en vivo.
    p = subprocess.Popen(cmd, cwd=APPLIO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, env=ENV)
    out = []
    for line in p.stdout:
        out.append(line)
        if show: print(line, end='')
    return p.wait(), ''.join(out)

_HELP = {}
def _flags(cmd):
    import re
    if cmd not in _HELP:
        _HELP[cmd] = set(re.findall(r'--[A-Za-z0-9_-]+', _run(['python', 'core.py', cmd, '--help'], show=False)[1]))
    return _HELP[cmd]

def applio(cmd, *args):
    # Adapta los flags a la versión instalada: --model_name ↔ --model-name; omite opcionales que ya no existen.
    ok, argv, a = _flags(cmd), [], list(map(str, args))
    for i in range(0, len(a), 2):
        flag, val = a[i], a[i + 1]
        for cand in (flag, flag.replace('_', '-'), flag.replace('-', '_')):
            if cand in ok:
                argv += [cand, val]; break
        else:
            print(f'  (aviso: "{cmd}" no tiene {flag}; se omite)')
    print(f'\\n=== core.py {cmd} {" ".join(argv)} ===')
    code, _ = _run(['python', 'core.py', cmd, *argv])
    if code != 0:
        print(f'\\n--- opciones válidas de "{cmd}" ---')
        _run(['python', 'core.py', cmd, '--help'])
        raise RuntimeError(f'Falló "core.py {cmd}". Copia el error de arriba (antes de las opciones) y pásamelo.')

def modelo_en(d):
    pth = sorted(glob.glob(f'{d}/*.pth'), key=os.path.getmtime)
    idx = sorted(glob.glob(f'{d}/*.index'), key=os.path.getmtime)
    pth = [p for p in pth if not os.path.basename(p).startswith(('G_', 'D_'))]
    return (pth[-1], idx[-1]) if pth and idx else (None, None)

PTH, INDEX = modelo_en(f'{BACKUP}/modelo') if BACKUP else (None, None)
if PTH:
    print('Reutilizando modelo de Drive:', PTH)
else:
    applio('preprocess', '--model_name', MODEL, '--dataset_path', DATASET, '--sample_rate', SR)
    applio('extract', '--model_name', MODEL, '--sample_rate', SR, '--f0_method', 'rmvpe')
    applio('train', '--model_name', MODEL, '--sample_rate', SR, '--total_epoch', EPOCHS,
           '--save_every_epoch', 50, '--batch_size', 8)
    applio('index', '--model_name', MODEL)
    PTH, INDEX = modelo_en(LOG)
    if not PTH:  # algunas versiones guardan el .pth en logs/ raíz o en weights/
        PTH = sorted(glob.glob(f'{APPLIO}/**/{MODEL}*.pth', recursive=True), key=os.path.getmtime)[-1]
    if BACKUP:
        os.makedirs(f'{BACKUP}/modelo', exist_ok=True)
        for f in (PTH, INDEX): shutil.copy(f, f'{BACKUP}/modelo/')
        print('Modelo respaldado en Drive')
print('modelo:', PTH, '\\nindex :', INDEX)"""),
code("""#@title 6 · Convertir en lote a la voz de la instructora
import glob, os, shutil
OUT_WAV = '/content/rvc_out'
shutil.rmtree(OUT_WAV, ignore_errors=True); os.makedirs(OUT_WAV)
for wav in sorted(glob.glob(f'{SRC_WAV}/*.wav')):
    wid = os.path.splitext(os.path.basename(wav))[0]
    applio('infer', '--pth_path', PTH, '--index_path', INDEX,
           '--input_path', wav, '--output_path', f'{OUT_WAV}/{wid}.wav',
           '--f0_method', 'rmvpe', '--pitch', PITCH, '--index_rate', INDEX_RATE)
    print('  convertido:', wid)"""),
code("""#@title 7 · Escuchar antes de descargar
from IPython.display import Audio, display
import glob, os
for w in sorted(glob.glob(f'{OUT_WAV}/*.wav')):
    if os.path.basename(w).startswith('guiado_'):
        print(os.path.basename(w)); display(Audio(w))
print('¿Suena metálica/robótica? Sube INDEX_RATE a 0.8, o prueba otra VOZ_BASE, y re-ejecuta desde la celda 4 (el modelo no se reentrena).')"""),
code("""#@title 8 · Exportar <id>.mp3 y descargar ZIP
import glob, os, shutil, subprocess
OUT = '/content/vof_tutorial'
shutil.rmtree(OUT, ignore_errors=True); os.makedirs(OUT)
for w in glob.glob(f'{OUT_WAV}/*.wav'):
    wid = os.path.splitext(os.path.basename(w))[0]
    subprocess.run(['ffmpeg', '-y', '-i', w, '-ac', '1', '-ar', '44100', '-b:a', '128k', f'{OUT}/{wid}.mp3'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
# ZIP plano: los mp3 en la raíz, sin carpeta (evita el anidado que ya pasó una vez)
shutil.make_archive('/content/vof_tutorial', 'zip', root_dir=OUT)
if BACKUP: shutil.copy('/content/vof_tutorial.zip', f'{BACKUP}/vof_tutorial.zip')
from google.colab import files; files.download('/content/vof_tutorial.zip')
print(len(glob.glob(f'{OUT}/*.mp3')), 'clips → extrae el ZIP directo en assets/vof_tutorial/')"""),
]

nb = {'nbformat': 4, 'nbformat_minor': 0,
      'metadata': {'accelerator': 'GPU', 'colab': {'provenance': [], 'gpuType': 'T4'},
                   'kernelspec': {'name': 'python3', 'display_name': 'Python 3'}},
      'cells': cells}
for c in nb['cells']:
    c['source'] = c['source'].splitlines(keepends=True)
out = f'{ROOT}/tools/rvc/COSSMIL_voces_guiado.ipynb'
json.dump(nb, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(out, os.path.getsize(out) // 1024, 'KB')
