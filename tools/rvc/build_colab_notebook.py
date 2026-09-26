"""Genera tools/rvc/COSSMIL_estudio_voz.ipynb autocontenido.

Embebe las locuciones de assets/vof/ (la voz a clonar), el guion de la app
(tutorial_lines.json) y el motor estudio_voz_lib.py. Editar ESTE script o el
motor, nunca el .ipynb, y regenerar:

    python3 tools/rvc/build_colab_notebook.py
"""
import base64, glob, json, os, textwrap

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RVC = f'{ROOT}/tools/rvc'
lines = json.load(open(f'{RVC}/tutorial_lines.json', encoding='utf-8'))['lines']
motor = open(f'{RVC}/estudio_voz_lib.py', encoding='utf-8').read()
vof = {}
for i, f in enumerate(sorted(glob.glob(f'{ROOT}/assets/vof/*.mp3')), 1):
    vof[f'vof_{i:02d}.mp3'] = base64.b64encode(open(f, 'rb').read()).decode()
NOMBRES_VOF = {f'vof_{i:02d}': os.path.splitext(os.path.basename(f))[0]
               for i, f in enumerate(sorted(glob.glob(f'{ROOT}/assets/vof/*.mp3')), 1)}

# Motor de voz natural: Chatterbox Multilingual (Resemble AI, licencia MIT), en un entorno aislado.
CHATTERBOX = 'chatterbox-tts==0.1.7'
# Versión de Applio con la que se escribieron los flags de la CLI (Click, 23 sep 2026).
APPLIO_COMMIT = '939d9ede94d563eb5b96a55dc3922e03f93d4064'

# Refuerzo opcional con RVC (Applio): celdas de la versión anterior, ahora detrás de
# REFORZAR_CON_RVC. Se componen en una sola celda más abajo (componer_celda_rvc).
RVC_INSTALAR = """#@title 3 · Instalar Applio (RVC v2) — ~5 min
VERSION_APPLIO = "probada (recomendada)"  #@param ["probada (recomendada)", "última (main)"]
import os
APPLIO = '/content/Applio'
if not os.path.exists(f'{APPLIO}/.cossmil_ok'):
    COMMIT = '@@COMMIT@@' if VERSION_APPLIO.startswith('probada') else 'main'
    !rm -rf /content/Applio && git init -q /content/Applio
    %cd /content/Applio
    !git remote add origin https://github.com/IAHispano/Applio && git fetch -q --depth 1 origin {COMMIT} && git -c advice.detachedHead=false checkout -q FETCH_HEAD
    !apt-get -qq update > /dev/null && apt-get -qq install -y portaudio19-dev > /dev/null
    !command -v uv > /dev/null || pip -q install uv
    !uv pip install --system -q -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu128 --index-strategy unsafe-best-match
    !python core.py prerequisites --models --pretraineds-hifigan --exe
    !cp assets/config_template.json assets/config.json
    !touch .cossmil_ok
%cd /content/Applio
print('Applio listo ✔  (los avisos rojos de pip sobre "dependency conflicts" son inofensivos)')"""

RVC_MODELO = """#@title 4 · Modelo de la voz (reutiliza el de Drive o entrena)
import glob, os, shutil, subprocess, time
LOG = f'{APPLIO}/logs/{MODEL}'
# PYTORCH_JIT=0: el torch de Colab (CUDA 13) no trae libnvrtc-builtins para compilar los kernels
# TorchScript de RVC ("nvrtc: failed to open libnvrtc-builtins.so.13.0"); sin JIT corre igual.
import site
_libs = sorted({os.path.dirname(f) for d in site.getsitepackages()
                for f in glob.glob(f'{d}/nvidia/**/libnvrtc*.so*', recursive=True)})
ENV = {**os.environ, 'COLUMNS': '200', 'NO_COLOR': '1', 'TERM': 'dumb', 'PYTHONUNBUFFERED': '1',
       'PYTORCH_JIT': '0',
       'LD_LIBRARY_PATH': ':'.join(_libs + [os.environ.get('LD_LIBRARY_PATH', '')]).strip(':')}

def applio(cmd, *args, mostrar=True):
    # Ejecuta `python core.py <cmd> ...` mostrando la salida en vivo (subprocess.run no la muestra en Colab).
    p = subprocess.Popen(['python', 'core.py', cmd, *map(str, args)], cwd=APPLIO, env=ENV, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=1)
    salida = []
    for linea in p.stdout:
        salida.append(linea)
        if mostrar: print(linea, end='')
    texto = ''.join(salida)
    if p.wait() != 0:
        fallo(cmd, texto, mostrar)
    return texto

def fallo(cmd, texto, mostrado=True):
    if not mostrado: print(texto[-3000:])
    raise RuntimeError(f'Falló "core.py {cmd}". Copia el error de arriba y pásamelo.')

def exigir(cmd, texto, patron):
    # Applio suele terminar con código 0 aunque falle por dentro: se valida lo que dejó en disco.
    if not glob.glob(patron):
        fallo(cmd, texto)

def modelo_en(d):
    pth = [p for p in glob.glob(f'{d}/*.pth') if not os.path.basename(p).startswith(('G_', 'D_'))]
    idx = glob.glob(f'{d}/*.index')
    pth.sort(key=os.path.getmtime); idx.sort(key=os.path.getmtime)
    return (pth[-1], idx[-1]) if pth and idx else (None, None)

PTH, INDEX = modelo_en(f'{BACKUP}/modelo') if BACKUP else (None, None)
huella_guardada = open(f'{BACKUP}/modelo/huella.txt').read().strip() if BACKUP and os.path.exists(f'{BACKUP}/modelo/huella.txt') else None
entrenar = REENTRENAR or not PTH
if PTH and not REENTRENAR:
    if huella_guardada == HUELLA:
        print('Modelo de Drive al día con el dataset → no se reentrena ✔')
    elif huella_guardada is None:
        print('Modelo de Drive de una versión anterior (sin huella): se reutiliza.\\n'
              'Si le agregaste audio desde entonces, marca REENTRENAR en la celda 1.')
    elif huella_guardada != HUELLA:
        print('El dataset cambió desde el último entrenamiento (¿audio extra nuevo?) → se reentrena.')
        entrenar = True

if entrenar:
    assert GPU, 'Entrenar necesita GPU: Entorno de ejecución → Cambiar tipo de entorno → T4 GPU, y Ejecutar todo.'
    t0 = time.time()
    shutil.rmtree(LOG, ignore_errors=True)
    ncpu = os.cpu_count() or 2
    t = applio('preprocess', '--model-name', MODEL, '--dataset-path', DATASET, '--sample-rate', SR,
               '--cpu-cores', ncpu, '--cut-preprocess', 'Automatic', '--chunk-len', '3.0', '--overlap-len', '0.3')
    exigir('preprocess', t, f'{LOG}/sliced_audios/*.wav')
    t = applio('extract', '--model-name', MODEL, '--sample-rate', SR, '--f0-method', 'rmvpe',
               '--cpu-cores', ncpu, '--gpu', '0', '--embedder-model', 'contentvec', '--include-mutes', 2)
    exigir('extract', t, f'{LOG}/extracted/*')
    t = applio('index', '--model-name', MODEL, '--index-algorithm', 'Auto')
    exigir('index', t, f'{LOG}/*.index')
    # Con poca voz, el lote por defecto (8) deja <3 lotes y Applio aborta "Not enough data": se ajusta solo.
    trozos = len(glob.glob(f'{LOG}/sliced_audios/*.wav'))
    lote = max(2, min(8, trozos // 6))
    print(f'\\n{trozos} trozos de audio → batch_size {lote}, {EPOCHS} epochs')
    t = applio('train', '--model-name', MODEL, '--sample-rate', SR, '--total-epoch', EPOCHS,
           '--save-every-epoch', 50, '--save-only-latest', '--batch-size', lote, '--gpu', '0',
           '--vocoder', 'HiFi-GAN', '--pretrained')
    pths = sorted(glob.glob(f'{LOG}/{MODEL}_*e_*s.pth'), key=os.path.getmtime)
    idxs = sorted(glob.glob(f'{LOG}/*.index'), key=os.path.getmtime)
    if not pths or not idxs:
        fallo('train', t)
    PTH, INDEX = pths[-1], idxs[-1]
    if BACKUP:
        viejo = f'{BACKUP}/modelo_anterior'
        shutil.rmtree(viejo, ignore_errors=True); os.makedirs(viejo)
        for f in glob.glob(f'{BACKUP}/modelo/*'):
            shutil.move(f, viejo)
        for f in (PTH, INDEX):
            shutil.copy(f, f'{BACKUP}/modelo/')
        open(f'{BACKUP}/modelo/huella.txt', 'w').write(HUELLA)
        PTH, INDEX = modelo_en(f'{BACKUP}/modelo')
        print('Modelo respaldado en Drive (el anterior quedó en modelo_anterior/)')
    print(f'Entrenado en {(time.time() - t0) / 60:.0f} min')
print('modelo:', PTH, '\\nindex :', INDEX)"""

def componer_celda_rvc():
    """Une instalación + modelo RVC en una celda que solo actúa con REFORZAR_CON_RVC."""
    instalar = RVC_INSTALAR.split('\n', 1)[1]
    modelo = RVC_MODELO.split('\n', 1)[1]
    param = [l for l in instalar.split('\n') if l.startswith('VERSION_APPLIO')][0]
    instalar = '\n'.join(l for l in instalar.split('\n') if not l.startswith('VERSION_APPLIO'))
    return ('#@title 4 · (Opcional) Refuerzo de timbre con RVC — solo si marcaste REFORZAR_CON_RVC\n'
            + param + '\nPTH = INDEX = None\nif REFORZAR_CON_RVC:\n'
            + textwrap.indent(instalar.strip('\n') + '\n' + modelo.strip('\n'), '    ')
            + "\nelse:\n    print('Omitido ✔ — se usa la voz clonada tal cual (lo más natural).')")


def md(src): return {'cell_type': 'markdown', 'metadata': {}, 'source': src}
def code(src): return {'cell_type': 'code', 'metadata': {}, 'execution_count': None, 'outputs': [], 'source': src}


cells = [
md("""# 🎙️ COSSMIL — Estudio de voz (voz natural clonada de las `vof`)

Genera audios con **la voz real de la locutora de COSSMIL** — la de `assets/vof/`, que ya viene dentro de este cuaderno —: las **voces del Modo Guiado** y **cualquier texto** que escribas.

**Cómo suena natural:** en vez de una voz sintética "maquillada", un modelo de **clonación de voz** (Chatterbox Multilingual, código abierto, licencia MIT) escucha a la locutora y **habla como ella**: su timbre, su entonación y su ritmo. El cuaderno elige solo el fragmento de las `vof` que mejor se clona (celda 6), revisa cada frase y regenera las que salgan cortadas, pasa los números a palabras e iguala el volumen al de las `vof`.

### Uso
1. `Entorno de ejecución → Cambiar tipo de entorno → GPU T4`.
2. `Entorno de ejecución → Ejecutar todo` y acepta el permiso de Google Drive.
3. La 1ª vez tarda ≈ 15 min (instala y elige la referencia); luego ≈ 5 min.
4. Al final queda **`vof_tutorial_….zip`** con todas las voces: se guarda en **Google Drive** (`Mi unidad/cossmil_rvc/salidas/`, también con los mp3 sueltos en la carpeta `vof_tutorial/`), se descarga sola y además aparece un enlace **⬇️ Descargar** por si el navegador bloqueó la descarga. Extrae los mp3 **directo** en `assets/vof_tutorial/`. Si algo falló, la celda **7b** vuelve a entregar lo último sin regenerar.
5. Para cualquier otro texto: celda **8 · Estudio**.

> **Calidad por frase:** se generan varias tomas; **Whisper** comprueba que se entienda completa (sin cortes ni balbuceos), **UTMOS** elige la más natural (la menos robótica) y **se recortan los sonidos extraños después de la última palabra** (solo si Whisper confirma que no son parte del texto); **DeepFilterNet** quita el ruido sin inventar sonidos y **DNSMOS** (medidor de Microsoft) exige que el fondo quede tan limpio como en las vof, o se genera otra toma; el realce de nitidez (Resemble Enhance) solo se conserva si el medidor confirma que no ensució; además se silencian los huecos entre palabras, se limpia la referencia antes de clonar y el volumen se iguala con ganancia fija (sin subir el ruido de las pausas). Al final se listan las frases a revisar; rehazlas con otra **SEMILLA** (celda 7 → `SOLO_ESTOS`; celda 8 para textos libres). Más grabaciones limpias de la locutora en `MyDrive/cossmil_rvc/audio_extra/` también ayudan."""),

code("""#@title 1 · Configuración general
USAR_DRIVE = True        #@param {type:"boolean"}
#@markdown Guarda la referencia elegida, los audios extra y tus resultados en `MyDrive/cossmil_rvc`.
SUBIR_AUDIO_EXTRA = False  #@param {type:"boolean"}
#@markdown Pide subir grabaciones extra de la MISMA locutora (también puedes dejarlas en `MyDrive/cossmil_rvc/audio_extra/`).
REFORZAR_CON_RVC = False #@param {type:"boolean"}
#@markdown Opcional: además pasa la voz clonada por un modelo RVC entrenado con las vof (≈ +25 min la 1ª vez). Suele sonar **menos** natural; déjalo apagado salvo que quieras probarlo.
REENTRENAR = False       #@param {type:"boolean"}
EPOCHS = 300             #@param {type:"slider", min:100, max:800, step:50}
MODEL, SR = 'instructora', 40000

import os, subprocess
GPU = 'GPU' in subprocess.run(['nvidia-smi', '-L'], capture_output=True, text=True).stdout
print('GPU:', 'sí ✔' if GPU else 'NO — la voz clonada funciona en CPU pero MUY lento '
      '(Entorno de ejecución → Cambiar tipo → T4).')

BACKUP = None
if USAR_DRIVE:
    from google.colab import drive
    drive.mount('/content/drive')
    BACKUP = '/content/drive/MyDrive/cossmil_rvc'
    for d in ('modelo', 'audio_extra', 'salidas'):
        os.makedirs(f'{BACKUP}/{d}', exist_ok=True)
    print('Drive:', BACKUP)"""),

code("""#@title 2 · Voz de la locutora (vof embebidas + audio extra)
import base64, glob, hashlib, os, shutil, subprocess
VOF = @@VOF@@
RAW, DATASET = '/content/raw_audio', '/content/rvc_dataset'
shutil.rmtree(RAW, ignore_errors=True); shutil.rmtree(DATASET, ignore_errors=True)
os.makedirs(RAW); os.makedirs(DATASET)
for name, b64 in VOF.items():
    open(f'{RAW}/{name}', 'wb').write(base64.b64decode(b64))

AUDIO_EXT = ('.mp3', '.wav', '.m4a', '.ogg', '.flac', '.aac', '.opus')
if BACKUP:
    for f in sorted(glob.glob(f'{BACKUP}/audio_extra/*')):
        if f.lower().endswith(AUDIO_EXT):
            shutil.copy(f, f'{RAW}/drive_{os.path.basename(f)}')
if SUBIR_AUDIO_EXTRA:
    from google.colab import files
    print('Sube grabaciones de la MISMA voz (sin música, sin eco, sin otras personas):')
    for name, data in files.upload().items():
        open(f'{RAW}/extra_{name}', 'wb').write(data)
        if BACKUP:  # para que la próxima vez no haya que subirlas de nuevo
            open(f'{BACKUP}/audio_extra/{name}', 'wb').write(data)

# Sin duplicados (el mismo audio subido dos veces) y huella del contenido: si agregas audio, se vuelve a elegir la referencia.
digests = {}
for f in sorted(glob.glob(f'{RAW}/*')):
    d = hashlib.sha256(open(f, 'rb').read()).digest()
    if d in digests: os.remove(f)
    else: digests[d] = f
HUELLA = hashlib.sha256(b''.join(sorted(digests))).hexdigest()[:16]

total = 0.0
for i, f in enumerate(sorted(glob.glob(f'{RAW}/*')), 1):
    out = f'{DATASET}/{os.path.splitext(os.path.basename(f))[0]}.wav'  # vof_03.wav, drive_x.wav…
    r = subprocess.run(['ffmpeg', '-y', '-i', f, '-ac', '1', '-ar', '44100', '-af',
                        'highpass=f=60,silenceremove=start_periods=1:start_threshold=-45dB:stop_periods=-1:stop_duration=0.6:stop_threshold=-45dB,loudnorm=I=-16:TP=-1.5:LRA=11',
                        out], capture_output=True, text=True)
    if r.returncode:
        print(f'  ⚠ se omite {os.path.basename(f)} (no es audio legible)'); continue
    d = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                              '-of', 'default=nk=1:nw=1', out], capture_output=True, text=True).stdout or 0)
    total += d
    print(f'  {os.path.basename(f)[:40]:40s} {d:6.1f}s')
print(f'\\nDataset: {len(glob.glob(DATASET + "/*.wav"))} clips, {total/60:.1f} min de voz · huella {HUELLA}')
if total < 90:
    print('Consejo: más grabaciones limpias de la locutora dan más referencias entre las que elegir.')"""),

code("""#@title 3 · Instalar el motor de voz natural (Chatterbox, entorno aislado) — ~4 min la 1ª vez
import os
VENV = '/content/voz_env'
PY = f'{VENV}/bin/python'
if not os.path.exists(f'{VENV}/.ok'):
    !command -v uv > /dev/null || pip -q install uv
    !uv venv -q --python 3.11 {VENV}
    !uv pip install -q --python {PY} "@@CHATTERBOX@@" soundfile scipy
    !touch {VENV}/.ok
# perth (componente de chatterbox) importa pkg_resources: uv no trae setuptools en el entorno.
!uv pip install -q --python {PY} "setuptools<81" pyyaml noisereduce
!{PY} -c "import torch, chatterbox; from perth.perth_net.perth_net_implicit.perth_watermarker import PerthImplicitWatermarker; print('torch', torch.__version__, '· GPU' if torch.cuda.is_available() else '· CPU')"

# Nitidez de estudio: Resemble Enhance (MIT) limpia con red neuronal y reconstruye la voz a 44,1 kHz.
# Sus dependencias fijadas (torch 2.1, deepspeed) solo hacen falta para ENTRENARLO: se instala sin
# ellas y con un sustituto mínimo de deepspeed (que en inferencia nunca se llama).
if not os.path.exists(f'{VENV}/.ok_realce'):
    !command -v git-lfs > /dev/null || (apt-get -qq update > /dev/null && apt-get -qq install -y git-lfs > /dev/null)
    !git lfs install --skip-repo > /dev/null
    !uv pip install -q --python {PY} --no-deps resemble-enhance==0.0.1
    !uv pip install -q --python {PY} omegaconf rich resampy matplotlib pandas tqdm
    SITIO = !{PY} -c "import site; print(site.getsitepackages()[0])"
    DS = f'{SITIO[-1]}/deepspeed'
    if not os.path.exists(f'{DS}/runtime/engine.py'):
        for d in ('', '/accelerator', '/runtime'):
            os.makedirs(DS + d, exist_ok=True)
        _no = "raise RuntimeError('deepspeed no instalado: solo hace falta para entrenar Resemble Enhance')"
        open(f'{DS}/__init__.py', 'w').write(f"class DeepSpeedConfig:\\n    def __init__(self, *a, **k): {_no}\\n"
                                              f"def init_distributed(*a, **k): {_no}\\n")
        open(f'{DS}/accelerator/__init__.py', 'w').write(f"def get_accelerator(*a, **k): {_no}\\n")
        open(f'{DS}/runtime/__init__.py', 'w').write('')
        open(f'{DS}/runtime/engine.py', 'w').write('class DeepSpeedEngine:\\n    pass\\n')
        open(f'{DS}/runtime/utils.py', 'w').write(f"def clip_grad_norm_(*a, **k): {_no}\\n")
    # descarga el modelo de realce ahora (git lfs, ~1 GB) para no hacerlo a mitad de una generación
    r = !{PY} -c "from resemble_enhance.enhancer.download import download; print('realce OK', download())" 2>&1
    print(r[-1])
    if 'realce OK' in r[-1]:
        !touch {VENV}/.ok_realce
    else:
        print('⚠ Nitidez no disponible (se generará igual, a 24 kHz). Detalle:', *r[-6:], sep='\\n')
# Audio limpio: DeepFilterNet 3 (quita ruido sin inventar sonidos) + medidor DNSMOS de Microsoft
# (califica la limpieza del fondo de cada toma). Se descargan ahora para fallar temprano.
if not os.path.exists(f'{VENV}/.ok_limpio'):
    !uv pip install -q --python {PY} --no-deps deepfilternet==0.5.6 deepfilterlib==0.5.6
    !uv pip install -q --python {PY} loguru appdirs onnxruntime
    !mkdir -p ~/.cache/cossmil_dnsmos && curl -sL -o ~/.cache/cossmil_dnsmos/sig_bak_ovr.onnx https://raw.githubusercontent.com/microsoft/DNS-Challenge/master/DNSMOS/DNSMOS/sig_bak_ovr.onnx
    r = !{PY} -c "from df.enhance import init_df; init_df(log_level='ERROR', log_file=None); import onnxruntime; print('limpieza OK')" 2>&1
    print(r[-1])
    if 'limpieza OK' in r[-1]:
        !touch {VENV}/.ok_limpio
    else:
        print('⚠ Limpieza neuronal no disponible (se usará el realce como respaldo). Detalle:', *r[-6:], sep='\\n')
print('Motor de voz listo ✔ (entorno aparte: no toca el numpy/torch de Colab)')"""),

code(None),  # celda 4: RVC opcional (componer_celda_rvc)

code("""%%writefile /content/estudio_voz_lib.py
#@title 5 · Motor del estudio (no hace falta tocar nada aquí)
@@MOTOR@@"""),

code("""#@title 5b · Enlace del motor (no hace falta tocar nada aquí)
# Todo lo que usa numpy/librosa/torch corre en un proceso aparte con el Python del entorno de voz.
import datetime, glob, importlib, json, os, shutil, subprocess, sys
sys.path.insert(0, '/content')
import estudio_voz_lib as L
importlib.reload(L)
from estudio_voz_lib import (PRONUNCIACION_DEFECTO, parse_textos, parse_archivo, nombre_seguro,
                             duracion, distancia_rasgos, medir_lufs)
from IPython.display import Audio, HTML, display

def remoto(funcion, *args, mostrar=False):
    p = subprocess.Popen([PY, '/content/estudio_voz_lib.py', funcion, json.dumps(args)], cwd='/content',
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
                         env={**os.environ, 'PYTORCH_JIT': '0', 'TOKENIZERS_PARALLELISM': 'false',
                              # checkpoint oficial de Resemble Enhance (formato deepspeed): torch 2.6 lo
                              # rechazaría con su carga "solo pesos" por defecto
                              'TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD': '1'})
    salida, resultado, listo = [], None, False
    for linea in p.stdout:
        if linea.startswith('@@RESULTADO@@'):
            resultado, listo = json.loads(linea[len('@@RESULTADO@@'):]), True
        else:
            salida.append(linea)
            if mostrar and linea.startswith('  ['): print(linea, end='')
    if p.wait() != 0 or not listo:
        raise RuntimeError(f'"{funcion}" falló:\\n' + ''.join(salida)[-2500:])
    return resultado

L.ensamblar = lambda partes, ruta: remoto('ensamblar', partes, ruta)
analizar_varias = lambda entradas: remoto('analizar_varias', entradas)
similitudes = lambda refs, cands: remoto('similitudes', refs, cands)

GUION = @@GUION@@
NOMBRES_VOF = @@NOMBRES_VOF@@
AJUSTES = dict(exageracion=0.5, cfg=0.4, temperatura=0.7, semilla=1234, intentos=6, tomas_min=3, silabas_s=5.5,
               limpieza_neuronal=True, medir_fondo=True, fondo_min=4.0,
               verificar=True, asr='openai/whisper-large-v3-turbo', naturalidad=True,
               nitidez=True, fuerza_realce=0.9, limpiar_ruido=False, silenciar_pausas=True,
               limpiar_referencia=True,
               pitch=0, index_rate=0.6, protect=0.33, envolvente=1.0, limpiar=False,
               formato='mp3', normalizar=True, lufs=-16.0)
REFERENCIA = None   # la fija la celda 6
PRONUNCIACION = dict(PRONUNCIACION_DEFECTO)

def convertir_rvc(entrada, salida):
    args = ['--input-folder', entrada, '--output-folder', salida, '--pth-path', PTH, '--index-path', INDEX,
            '--pitch', AJUSTES['pitch'], '--index-rate', AJUSTES['index_rate'], '--protect', AJUSTES['protect'],
            '--volume-envelope', AJUSTES['envolvente'], '--f0-method', 'rmvpe', '--export-format', 'WAV']
    if AJUSTES['limpiar']:
        args += ['--clean-audio', '--clean-strength', 0.5]
    os.makedirs(salida, exist_ok=True)
    t = applio('batch-infer', *args, mostrar=False)
    for f in glob.glob(f'{salida}/*_output.wav'):  # Applio agrega "_output" al nombre
        os.replace(f, f[:-len('_output.wav')] + '.wav')
    if len(glob.glob(f'{salida}/*.wav')) < len(glob.glob(f'{entrada}/*.wav')):
        fallo('batch-infer', t, mostrado=False)

CLAVES_CLON = ('exageracion', 'cfg', 'temperatura', 'semilla', 'intentos', 'tomas_min', 'silabas_s',
               'verificar', 'asr', 'naturalidad', 'nitidez', 'fuerza_realce', 'limpiar_ruido',
               'silenciar_pausas', 'limpiar_referencia', 'limpieza_neuronal', 'medir_fondo', 'fondo_min')
ULTIMO_INFORME = []

def clonar(trabajos):
    global ULTIMO_INFORME
    if AJUSTES['verificar']:
        print(f"  (por frase: {AJUSTES['tomas_min']}+ tomas → Whisper verifica que se entienda completa, "
              f"DeepFilterNet la limpia, DNSMOS exige fondo ≥ {AJUSTES['fondo_min']}/5 (como las vof), "
              "UTMOS elige la más natural y el realce se conserva solo si no ensucia)")
    ULTIMO_INFORME = remoto('clonar_lote', trabajos, REFERENCIA, {k: AJUSTES[k] for k in CLAVES_CLON}, mostrar=True)
    return ULTIMO_INFORME

def producir(pares, lote='estudio', mostrar=12, descargar=True, textos=True):
    if not pares:
        print('No hay textos para generar.'); return {}
    assert REFERENCIA, 'Falta la referencia de la voz: ejecuta la celda 6.'
    print(f'Generando {len(pares)} audio(s) con la voz clonada de la locutora '
          f'(expresividad {AJUSTES["exageracion"]}, ritmo {AJUSTES["cfg"]}, semilla {AJUSTES["semilla"]})…')
    salidas = L.generar(pares, None, f'/content/trabajo_{lote}',
                        convertir_rvc if (REFORZAR_CON_RVC and PTH) else None,
                        sintetizar_lote=clonar, max_car=250, pronunciacion=PRONUNCIACION,
                        formato=AJUSTES['formato'], normalizar=AJUSTES['normalizar'], lufs=AJUSTES['lufs'])
    texto_de = dict(pares)
    dudosos = sorted({pares[int(r['ruta'][:3]) - 1][0] for r in ULTIMO_INFORME if not r['ok']})
    if dudosos:
        print(f"\\n⚠ {len(dudosos)} audio(s) para escuchar con atención: {', '.join(dudosos)}\\n"
              f"  Si alguno no te convence: cambia la SEMILLA y regenera solo esos (celda 7: SOLO_ESTOS).")
    elif any(r['parecido'] is not None for r in ULTIMO_INFORME):
        fondos = [r['fondo']['bak'] for r in ULTIMO_INFORME if r.get('fondo')]
        extra = f" y con el fondo limpio (DNSMOS {min(fondos):.2f}–{max(fondos):.2f}/5)" if fondos else ''
        print(f'\\n✔ Todas las frases se entendieron completas (Whisper){extra}.')
    else:
        print('\\n(sin verificación Whisper: solo se revisó la duración de cada frase)')
    for i, (nombre, ruta) in enumerate(salidas.items()):
        if i == mostrar:
            print(f'… y {len(salidas) - mostrar} más en el ZIP.'); break
        detalle = f' — {texto_de[nombre][:90]}' if textos else ''
        display(HTML(f'<b>{nombre}</b> ({duracion(ruta):.1f} s){detalle}'))
        display(Audio(ruta))
    entregar(list(salidas.values()), lote, descargar=descargar)
    return salidas

ULTIMA_ENTREGA = None

def entregar(archivos, lote, descargar=True):
    # Guarda SIEMPRE en Drive (ZIP + mp3 sueltos) y ofrece la descarga de dos formas:
    # la automática de Colab (el navegador a veces la bloquea tras celdas largas) y un enlace.
    global ULTIMA_ENTREGA
    import base64
    sello = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    if len(archivos) == 1:
        entrega = archivos[0]
    else:
        entrega = shutil.make_archive(f'/content/{lote}_{sello}', 'zip', root_dir=os.path.dirname(archivos[0]))
    ULTIMA_ENTREGA = dict(archivos=list(archivos), lote=lote, entrega=entrega)
    if BACKUP:
        try:
            carpeta = f'{BACKUP}/salidas/{lote}'            # siempre la última versión, suelta
            os.makedirs(carpeta, exist_ok=True)
            for a in archivos:
                shutil.copy(a, carpeta)
            destino = f'{BACKUP}/salidas/{lote}_{sello}{os.path.splitext(entrega)[1]}'
            shutil.copy(entrega, destino)
            os.sync()
            ok = os.path.getsize(destino) == os.path.getsize(entrega)
            print(f"{'✔' if ok else '⚠'} Guardado en Google Drive → Mi unidad/cossmil_rvc/salidas/")
            print(f'   · {os.path.basename(destino)} (ZIP)')
            print(f'   · carpeta {lote}/ con los {len(archivos)} audio(s) sueltos')
        except Exception as e:  # noqa: BLE001
            print(f'⚠ No se pudo guardar en Drive ({type(e).__name__}: {e}). Re-ejecuta la celda 1 para montarlo.')
    else:
        print('(Drive desactivado: marca USAR_DRIVE en la celda 1 para guardar una copia)')
    if descargar:
        tam = os.path.getsize(entrega)
        if tam < 40 * 1024 * 1024:
            datos = base64.b64encode(open(entrega, 'rb').read()).decode()
            tipo = 'application/zip' if entrega.endswith('.zip') else 'audio/mpeg'
            display(HTML(f'<p style="font-size:15px">⬇️ <a download="{os.path.basename(entrega)}" '
                         f'href="data:{tipo};base64,{datos}"><b>Descargar {os.path.basename(entrega)}</b></a>'
                         f' ({tam / 1e6:.1f} MB) — si no bajó solo, haz clic aquí.</p>'))
        try:
            from google.colab import files; files.download(entrega)
        except Exception as e:  # noqa: BLE001
            print(f'(descarga automática no disponible: {type(e).__name__}; usa el enlace o Drive)')
        print(f'También puedes bajarlo desde el panel de archivos de la izquierda: {entrega}')

print('Motor listo ✔')"""),

code("""#@title 6 · Elegir la mejor referencia de la locutora (automático; ~5 min la 1ª vez, se guarda en Drive)
RECALIBRAR = False  #@param {type:"boolean"}
#@markdown Prepara una referencia por cada `vof`, clona con cada una la misma frase del Modo Guiado y se queda con la que
#@markdown suena **más a la locutora** (verificador de hablante WavLM + tono, ritmo y entonación).
import glob, json, os, shutil, statistics

CLAVE = f'{HUELLA}:chatterbox'
CAL_PATH = f'{BACKUP}/modelo/voz_clonada.json' if BACKUP else '/content/voz_clonada.json'
REF_GUARDADA = f'{BACKUP}/modelo/referencia.wav' if BACKUP else '/content/referencia.wav'
CAL = None
if os.path.exists(CAL_PATH) and os.path.exists(REF_GUARDADA) and not RECALIBRAR:
    previo = json.load(open(CAL_PATH))
    CAL = previo if previo.get('clave') == CLAVE else None

if CAL is None:
    DATA_WAVS = sorted(glob.glob(f'{DATASET}/*.wav'))
    print('Analizando la voz de la locutora…')
    REF_RASGOS = analizar_varias([DATA_WAVS])[0]
    lufs_ref = statistics.median(medir_lufs(f) for f in sorted(glob.glob(f'{RAW}/*')))
    print(f"  tono {REF_RASGOS['f0']:.0f} Hz · ritmo {REF_RASGOS['silabas_s']:.1f} sílabas/s · "
          f"entonación {REF_RASGOS['rango_st']:.1f} st · volumen {lufs_ref:.1f} LUFS")
    CDIR = '/content/calibracion'
    shutil.rmtree(CDIR, ignore_errors=True)
    refs = remoto('preparar_referencias', DATA_WAVS, f'{CDIR}/refs')
    FRASE_CAL = GUION['guiado_regional'] + ' ' + GUION['guiado_dia']
    ajustes = {k: AJUSTES[k] for k in ('exageracion', 'cfg', 'temperatura', 'semilla', 'intentos')}
    ajustes['silabas_s'] = REF_RASGOS['silabas_s']
    print(f'Clonando la voz con {len(refs)} referencias (la 1ª vez descarga el modelo, ~2 GB)…')
    cands = remoto('clonar_candidatas', FRASE_CAL, [r['ruta'] for r in refs], f'{CDIR}/cand', ajustes)
    rasgos = analizar_varias(cands)
    print('Midiendo el parecido con el verificador de hablante (WavLM)…')
    sim = similitudes(DATA_WAVS, cands)
    if sim['sims'] is None:
        print(f"  (verificador no disponible: {sim['aviso']} → se decide por tono, ritmo y entonación)")
    filas = []
    for n, (ref, cand, ras) in enumerate(zip(refs, cands, rasgos)):
        dist = distancia_rasgos(REF_RASGOS, ras)
        s_ = sim['sims'][n] if sim['sims'] else None
        stem = os.path.splitext(os.path.basename(DATA_WAVS[n]))[0]
        clip = f'{stem} · {NOMBRES_VOF[stem]}' if stem in NOMBRES_VOF else stem
        filas.append(dict(referencia=ref['ruta'], clip=clip, segundos=ref['seg_propios'], candidato=cand,
                          similitud=s_, distancia=round(dist, 3),
                          puntaje=(s_ - 0.02 * dist) if s_ is not None else -dist))
    filas.sort(key=lambda f: -f['puntaje'])
    shutil.copy(filas[0]['referencia'], REF_GUARDADA)
    CAL = dict(clave=CLAVE, clip=filas[0]['clip'], lufs=lufs_ref, locutora=REF_RASGOS,
               ranking=[{k: v for k, v in f.items() if k not in ('referencia', 'candidato')} for f in filas])
    json.dump(CAL, open(CAL_PATH, 'w'), ensure_ascii=False, indent=1)
    print('\\nRanking de referencias (mayor similitud y menor distancia = más parecida):')
    for n, f in enumerate(filas, 1):
        s_ = f"{f['similitud']:.3f}" if f['similitud'] is not None else '  —  '
        print(f"  {n}. {f['clip']} ({f['segundos']:.0f} s propios) · similitud {s_} · distancia {f['distancia']:.2f}")
    display(HTML('<b>Locutora original (vof):</b>')); display(Audio(max(DATA_WAVS, key=os.path.getsize)))
    for f in filas[:3]:
        display(HTML(f"<b>Voz clonada con referencia {f['clip']}</b>")); display(Audio(f['candidato']))

REFERENCIA = REF_GUARDADA
AJUSTES.update(silabas_s=CAL['locutora']['silabas_s'], lufs=CAL['lufs'])
print(f"\\nReferencia elegida ✔ {CAL['clip']} (guardada en {REF_GUARDADA})")"""),

code("""#@title 7 · Todas las voces de la app (Modo Guiado + tutoriales) → ZIP para `assets/vof_tutorial/`
GENERAR_VOCES_APP = True  #@param {type:"boolean"}
INCLUIR_TUTORIAL = True   #@param {type:"boolean"}
SOLO_ESTOS = ""           #@param {type:"string"}
#@markdown Para rehacer solo algunos: sus nombres separados por coma (p. ej. `guiado_hora, ficha_03`). Vacío = todos.
SEMILLA_APP = 1234        #@param {type:"integer"}
#@markdown Otra semilla = otra toma de la misma voz (úsala junto con `SOLO_ESTOS`).
#@markdown Genera **todas las voces de la app**: las 8 del Modo Guiado y, con `INCLUIR_TUTORIAL`, las 19 de los tutoriales (invitación, ficha, calendario y trámites).
#@markdown Extrae los mp3 del ZIP **directo** en `assets/vof_tutorial/` (sin subcarpeta).
if GENERAR_VOCES_APP:
    elegidos = {x.strip() for x in SOLO_ESTOS.split(',') if x.strip()}
    faltan = elegidos - set(GUION)
    assert not faltan, f'No existen en el guion: {sorted(faltan)}. Nombres válidos: {sorted(GUION)}'
    if elegidos:
        pares = [(k, v) for k, v in GUION.items() if k in elegidos]
    else:
        pares = [(k, v) for k, v in GUION.items() if INCLUIR_TUTORIAL or k.startswith('guiado_')]
    pares.sort(key=lambda p: not p[0].startswith('guiado_'))  # las del Modo Guiado primero (se escuchan arriba)
    previo = dict(AJUSTES)
    AJUSTES.update(formato='mp3', semilla=SEMILLA_APP)  # la app usa <id>.mp3
    try:
        producir(pares, lote='vof_tutorial', mostrar=8 if not elegidos else len(pares))
    finally:
        AJUSTES.update(formato=previo['formato'], semilla=previo['semilla'])
else:
    print('Omitido (marca GENERAR_VOCES_APP).')"""),

code("""#@title 7b · Volver a descargar / guardar en Drive lo último generado (sin regenerar)
VOLVER_A_ENTREGAR = False  #@param {type:"boolean"}
#@markdown Márcalo y ejecuta SOLO esta celda si la descarga no bajó o Drive no guardó.
if not VOLVER_A_ENTREGAR:
    print('Omitido (marca VOLVER_A_ENTREGAR si necesitas bajar o guardar de nuevo lo último).')
elif ULTIMA_ENTREGA:
    entregar(ULTIMA_ENTREGA['archivos'], ULTIMA_ENTREGA['lote'])
else:
    print('Aún no hay nada generado en esta sesión. Si ya generaste antes, búscalo en Mi unidad/cossmil_rvc/salidas/.')"""),

md("""## ✍️ Estudio — cualquier texto

Escribe en `TEXTOS` (celda 8) **una línea por audio**:

```
bienvenida | Bienvenido al sistema de citas de COSSMIL.
aviso_horario | Recuerde presentarse quince minutos antes. [pausa] Gracias por su preferencia.
Una línea sin nombre también sirve: se llamará clip_01_una-linea-sin-nombre.
# Las líneas con # se ignoran.
```

- `nombre | texto` → el archivo se llama `nombre.mp3` (útil para la app: `guiado_intro | …`).
- `[pausa]` = silencio de 0,6 s · `[pausa 1.5]` = 1,5 s · `[pausa 300ms]`.
- Los números se leen solos (`8:30` → "ocho y treinta", `21 fichas` → "veintiún fichas").
- Textos largos se parten solos en frases.
- Si una palabra suena mal, agrégala a `PRONUNCIACION` (p. ej. `'COSSMIL': 'Cossmil'`).

**Calidad:** por frase se generan al menos `TOMAS_MIN` tomas; Whisper descarta las cortadas o con balbuceo, **DeepFilterNet** limpia el fondo, **DNSMOS** exige que quede tan limpio como las vof (si no, se genera otra toma), UTMOS elige la más natural y el realce de nitidez solo se conserva si no ensucia. Al final verás la limpieza de cada frase y cuáles conviene revisar.

**Ajustes:** `EXPRESIVIDAD` más alta = más emoción (0.5 es natural y sereno); `RITMO` más bajo = más pausado y articulado; `VARIACION` más baja = más estable; **`SEMILLA`**: otra toma distinta de la misma voz (si una frase no te gusta, cámbiala)."""),

code('''#@title 8 · Estudio — escribe tus textos y ejecuta esta celda
TEXTOS = """
prueba_bienvenida | Bienvenido a COSSMIL. [pausa] Le acompañaré paso a paso para reservar su cita médica.
Este es un texto de prueba: puede escribir aquí cualquier cosa que necesite, y se generará con la voz de la locutora.
"""
REFERENCIA_VOZ = "automática (la mejor)"  #@param @@REFS_OPCIONES@@
EXPRESIVIDAD = 0.5   #@param {type:"slider", min:0.25, max:1.0, step:0.05}
RITMO = 0.4          #@param {type:"slider", min:0.2, max:0.8, step:0.05}
VARIACION = 0.7      #@param {type:"slider", min:0.4, max:1.2, step:0.05}
SEMILLA = 1234       #@param {type:"integer"}
NITIDEZ_ESTUDIO = True  #@param {type:"boolean"}
#@markdown Limpia con red neuronal y deja la voz a 44,1 kHz (Resemble Enhance). `FUERZA_LIMPIEZA` 0.9 = limpieza máxima (configuración oficial); bájala solo si notas la voz apagada.
FUERZA_LIMPIEZA = 0.9   #@param {type:"slider", min:0, max:1, step:0.05}
SILENCIAR_PAUSAS = True #@param {type:"boolean"}
LIMPIEZA_NEURONAL = True #@param {type:"boolean"}
#@markdown DeepFilterNet quita el ruido de fondo sin inventar sonidos.
FONDO_MINIMO = 4.0      #@param {type:"slider", min:3.0, max:4.5, step:0.1}
#@markdown Limpieza mínima del fondo (DNSMOS 1–5; las vof originales dan 4,1–4,2). Si una toma no llega, se genera otra.
#@markdown Baja el soplido de fondo en los huecos entre palabras (la voz no se toca).
ELEGIR_LA_MAS_NATURAL = True  #@param {type:"boolean"}
#@markdown Genera al menos `TOMAS_MIN` tomas por frase y se queda con la más humana (medidor UTMOS).
TOMAS_MIN = 3        #@param {type:"slider", min:1, max:6, step:1}
VERIFICAR_CON_WHISPER = True  #@param {type:"boolean"}
#@markdown Escucha cada frase y la rehace (hasta `TOMAS_MAX` veces) si sale cortada, con balbuceo o ruido.
TOMAS_MAX = 6        #@param {type:"slider", min:1, max:10, step:1}
FORMATO = "mp3"      #@param ["mp3", "wav"]
NORMALIZAR_VOLUMEN = True  #@param {type:"boolean"}
DESCARGAR = True     #@param {type:"boolean"}
NOMBRE_LOTE = "estudio"  #@param {type:"string"}
PRONUNCIACION.update({
    # 'palabra como se escribe': 'como debe sonar',
})

if REFERENCIA_VOZ.startswith('automática'):
    REFERENCIA = REF_GUARDADA
else:  # una vof concreta como referencia (preparada en la celda 6)
    REFERENCIA = f'/content/calibracion/refs/ref_{REFERENCIA_VOZ.split()[0]}.wav'
    if not os.path.exists(REFERENCIA):
        remoto('preparar_referencias', sorted(glob.glob(f'{DATASET}/*.wav')), '/content/calibracion/refs')
AJUSTES.update(exageracion=EXPRESIVIDAD, cfg=RITMO, temperatura=VARIACION, semilla=SEMILLA,
               nitidez=NITIDEZ_ESTUDIO, fuerza_realce=FUERZA_LIMPIEZA, naturalidad=ELEGIR_LA_MAS_NATURAL,
               silenciar_pausas=SILENCIAR_PAUSAS, limpieza_neuronal=LIMPIEZA_NEURONAL, fondo_min=FONDO_MINIMO,
               tomas_min=TOMAS_MIN, verificar=VERIFICAR_CON_WHISPER, intentos=max(TOMAS_MAX, TOMAS_MIN),
               formato=FORMATO, normalizar=NORMALIZAR_VOLUMEN)
producir(parse_textos(TEXTOS), lote=nombre_seguro(NOMBRE_LOTE), descargar=DESCARGAR)'''),

code("""#@title 9 · (Opcional) Generar desde un archivo .txt / .json / .csv
USAR_ARCHIVO = False  #@param {type:"boolean"}
#@markdown `.txt`: mismo formato que la celda 8 · `.json`: `{"id": "texto"}` o `[{"id":…, "texto":…}]` · `.csv`: columnas `id,texto`.
#@markdown Usa los ajustes de la celda 8.
if USAR_ARCHIVO:
    from google.colab import files
    pares = []
    for nombre, datos in files.upload().items():
        pares += parse_archivo(nombre, datos)
    producir(pares, lote='archivo', mostrar=6)
else:
    print('Omitido (marca USAR_ARCHIVO para subir un archivo de textos).')"""),
]

cells[cells.index(next(c for c in cells if c['source'] is None))]['source'] = componer_celda_rvc()

reemplazos = {
    '@@VOF@@': json.dumps(vof),
    '@@COMMIT@@': APPLIO_COMMIT,
    '@@CHATTERBOX@@': CHATTERBOX,
    '@@MOTOR@@': motor,
    '@@GUION@@': json.dumps(lines, ensure_ascii=False, indent=1),
    '@@NOMBRES_VOF@@': json.dumps(NOMBRES_VOF, ensure_ascii=False),
    '@@REFS_OPCIONES@@': json.dumps(['automática (la mejor)'] + [f'{k} · {v}' for k, v in NOMBRES_VOF.items()],
                                    ensure_ascii=False),
}
nb = {'nbformat': 4, 'nbformat_minor': 0,
      'metadata': {'accelerator': 'GPU', 'colab': {'provenance': [], 'gpuType': 'T4', 'name': 'COSSMIL_estudio_voz.ipynb'},
                   'kernelspec': {'name': 'python3', 'display_name': 'Python 3'}},
      'cells': cells}
for c in nb['cells']:
    src = c['source']
    for k, v in reemplazos.items():
        src = src.replace(k, v)
    c['source'] = src.splitlines(keepends=True)
out = f'{RVC}/COSSMIL_estudio_voz.ipynb'
json.dump(nb, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(out, os.path.getsize(out) // 1024, 'KB')
