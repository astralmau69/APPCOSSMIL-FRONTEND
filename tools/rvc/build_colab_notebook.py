"""Genera tools/rvc/COSSMIL_estudio_voz.ipynb autocontenido.

Embebe las locuciones de assets/vof/ (dataset de la voz), el guion de la app
(tutorial_lines.json) y el motor estudio_voz_lib.py. Editar ESTE script o el
motor, nunca el .ipynb, y regenerar:

    python3 tools/rvc/build_colab_notebook.py
"""
import base64, glob, json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RVC = f'{ROOT}/tools/rvc'
lines = json.load(open(f'{RVC}/tutorial_lines.json', encoding='utf-8'))['lines']
motor = open(f'{RVC}/estudio_voz_lib.py', encoding='utf-8').read()
vof = {}
for i, f in enumerate(sorted(glob.glob(f'{ROOT}/assets/vof/*.mp3')), 1):
    vof[f'vof_{i:02d}.mp3'] = base64.b64encode(open(f, 'rb').read()).decode()

# Versión de Applio con la que se escribieron los flags de la CLI (Click, 23 sep 2026).
APPLIO_COMMIT = '939d9ede94d563eb5b96a55dc3922e03f93d4064'

VOCES = ['es-BO-SofiaNeural', 'es-MX-DaliaNeural', 'es-CO-SalomeNeural', 'es-AR-ElenaNeural',
         'es-PE-CamilaNeural', 'es-CL-CatalinaNeural', 'es-EC-AndreaNeural', 'es-ES-ElviraNeural',
         'es-ES-XimenaNeural', 'es-US-PalomaNeural', 'es-VE-PaolaNeural', 'es-UY-ValentinaNeural',
         'es-PY-TaniaNeural', 'es-CR-MariaNeural']


def md(src): return {'cell_type': 'markdown', 'metadata': {}, 'source': src}
def code(src): return {'cell_type': 'code', 'metadata': {}, 'execution_count': None, 'outputs': [], 'source': src}


cells = [
md("""# 🎙️ COSSMIL — Estudio de voz

Escribe **cualquier texto** y obtén el audio con la **voz femenina de la locutora de COSSMIL** (la de `assets/vof/`, que ya viene dentro de este cuaderno).

**Cómo funciona:** una voz neural femenina (edge-tts, gratis) lee tu texto y un modelo **RVC** entrenado con las locuciones `vof` le cambia el timbre para que suene como la locutora.

### Primera vez (≈ 30–45 min, una sola vez)
1. `Entorno de ejecución → Cambiar tipo de entorno → GPU T4`.
2. `Entorno de ejecución → Ejecutar todo` y acepta el permiso de Google Drive.
3. El modelo queda guardado en `MyDrive/cossmil_rvc/modelo/`. **No se vuelve a entrenar.**

### Después (≈ 3–5 min para dejarlo listo)
`Ejecutar todo` otra vez (instala y carga el modelo de Drive, sin reentrenar). Luego escribe tus textos en la celda **6 · Estudio** y ejecútala las veces que quieras.

> ¿Más parecido a la locutora? Pon más grabaciones **limpias** de ella (mp3/wav, sin música ni eco) en `MyDrive/cossmil_rvc/audio_extra/`. El cuaderno detecta el cambio y reentrena solo. Con 3–5 minutos de voz mejora mucho; hoy hay ~1 minuto."""),

code("""#@title 1 · Configuración general
USAR_DRIVE = True        #@param {type:"boolean"}
#@markdown Guarda el modelo, los audios extra y tus resultados en `MyDrive/cossmil_rvc` (sobrevive a desconexiones).
SUBIR_AUDIO_EXTRA = False  #@param {type:"boolean"}
#@markdown Pide subir ahora grabaciones extra de la MISMA locutora (también puedes dejarlas en `MyDrive/cossmil_rvc/audio_extra/`).
REENTRENAR = False       #@param {type:"boolean"}
#@markdown Fuerza un entrenamiento nuevo aunque ya exista un modelo en Drive.
EPOCHS = 300             #@param {type:"slider", min:100, max:800, step:50}
MODEL, SR = 'instructora', 40000

import os, subprocess
GPU = 'GPU' in subprocess.run(['nvidia-smi', '-L'], capture_output=True, text=True).stdout
print('GPU:', 'sí ✔' if GPU else 'NO — entrenar exige GPU (Entorno de ejecución → Cambiar tipo → T4). '
      'Si el modelo ya está en Drive, el estudio funciona igual en CPU, solo más lento.')

BACKUP = None
if USAR_DRIVE:
    from google.colab import drive
    drive.mount('/content/drive')
    BACKUP = '/content/drive/MyDrive/cossmil_rvc'
    for d in ('modelo', 'audio_extra', 'salidas'):
        os.makedirs(f'{BACKUP}/{d}', exist_ok=True)
    print('Drive:', BACKUP)"""),

code("""#@title 2 · Dataset de la voz (vof embebidas + audio extra)
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

# Sin duplicados (el mismo audio subido dos veces) y huella del contenido: si agregas audio, la celda 4 reentrena sola.
digests = {}
for f in sorted(glob.glob(f'{RAW}/*')):
    d = hashlib.sha256(open(f, 'rb').read()).digest()
    if d in digests: os.remove(f)
    else: digests[d] = f
HUELLA = hashlib.sha256(b''.join(sorted(digests))).hexdigest()[:16]

total = 0.0
for i, f in enumerate(sorted(glob.glob(f'{RAW}/*')), 1):
    out = f'{DATASET}/clip_{i:03d}.wav'
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
    print('Consejo: con más voz limpia de la locutora (3–5 min) el parecido y la claridad mejoran mucho.')"""),

code("""#@title 3 · Instalar Applio (RVC v2) — ~5 min
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
print('Applio listo ✔  (los avisos rojos de pip sobre "dependency conflicts" son inofensivos)')"""),

code("""#@title 4 · Modelo de la voz (reutiliza el de Drive o entrena)
import glob, os, shutil, subprocess, time
LOG = f'{APPLIO}/logs/{MODEL}'
ENV = {**os.environ, 'COLUMNS': '200', 'NO_COLOR': '1', 'TERM': 'dumb', 'PYTHONUNBUFFERED': '1'}

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
print('modelo:', PTH, '\\nindex :', INDEX)"""),

code("""#@title 5 · Motor del estudio (no hace falta tocar nada aquí)
@@MOTOR@@

# ── Enlace con Applio y entrega de resultados ──
import datetime, glob, os, shutil
from IPython.display import Audio, HTML, display

AJUSTES = dict(voz='es-BO-SofiaNeural', velocidad=-8, tono_hz=0, pitch=0, index_rate=0.7,
               protect=0.33, envolvente=1.0, limpiar=False, formato='mp3', normalizar=True)
PRONUNCIACION = dict(PRONUNCIACION_DEFECTO)

def convertir_rvc(entrada, salida):
    args = ['--input-folder', entrada, '--output-folder', salida, '--pth-path', PTH, '--index-path', INDEX,
            '--pitch', AJUSTES['pitch'], '--index-rate', AJUSTES['index_rate'], '--protect', AJUSTES['protect'],
            '--volume-envelope', AJUSTES['envolvente'], '--f0-method', 'rmvpe', '--export-format', 'WAV']
    if AJUSTES['limpiar']:
        args += ['--clean-audio', '--clean-strength', 0.5]
    t = applio('batch-infer', *args, mostrar=False)
    for f in glob.glob(f'{salida}/*_output.wav'):  # Applio agrega "_output" al nombre
        os.replace(f, f[:-len('_output.wav')] + '.wav')
    if len(glob.glob(f'{salida}/*.wav')) < len(glob.glob(f'{entrada}/*.wav')):
        fallo('batch-infer', t, mostrado=False)

def producir(pares, lote='estudio', mostrar=12, descargar=True, textos=True):
    if not pares:
        print('No hay textos para generar.'); return {}
    print(f'Generando {len(pares)} audio(s) con {AJUSTES["voz"]}…')
    salidas = generar(pares, AJUSTES['voz'], f'/content/trabajo_{lote}', convertir_rvc,
                      velocidad=AJUSTES['velocidad'], tono_hz=AJUSTES['tono_hz'],
                      pronunciacion=PRONUNCIACION, formato=AJUSTES['formato'],
                      normalizar=AJUSTES['normalizar'])
    texto_de = dict(pares)
    for i, (nombre, ruta) in enumerate(salidas.items()):
        if i == mostrar:
            print(f'… y {len(salidas) - mostrar} más en el ZIP.'); break
        detalle = f' — {texto_de[nombre][:90]}' if textos else ''
        display(HTML(f'<b>{nombre}</b> ({duracion(ruta):.1f} s){detalle}'))
        display(Audio(ruta))
    sello = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    if len(salidas) == 1:
        entrega = next(iter(salidas.values()))
    else:
        entrega = shutil.make_archive(f'/content/{lote}_{sello}', 'zip',
                                      root_dir=os.path.dirname(next(iter(salidas.values()))))
    if BACKUP:
        destino = f'{BACKUP}/salidas/{lote}_{sello}{os.path.splitext(entrega)[1]}'
        shutil.copy(entrega, destino); print('Copia en Drive:', destino)
    if descargar:
        from google.colab import files; files.download(entrega)
    return salidas

print('Motor listo ✔ — ve a la celda 6.')"""),

md("""## ✍️ Estudio

Escribe en `TEXTOS` (celda 6) **una línea por audio**:

```
bienvenida | Bienvenido al sistema de citas de COSSMIL.
aviso_horario | Recuerde presentarse quince minutos antes. [pausa] Gracias por su preferencia.
Una línea sin nombre también sirve: se llamará clip_01_una-linea-sin-nombre.
# Las líneas con # se ignoran.
```

- `nombre | texto` → el archivo se llama `nombre.mp3` (útil para la app: `guiado_intro | …`).
- `[pausa]` = silencio de 0,6 s · `[pausa 1.5]` = 1,5 s · `[pausa 300ms]`.
- Textos largos (párrafos) se parten solos en frases; no hay límite práctico.
- Si una palabra suena mal, agrégala a `PRONUNCIACION` (p. ej. `'COSSMIL': 'Cossmil'`, `'La Paz': 'la paz'`).

Ajustes de sonido: **VOZ_BASE** cambia la entonación de partida (la celda 9 las compara todas); **VELOCIDAD** negativa = más pausado; **INDEX_RATE** más alto = más parecido a la locutora (si suena metálico, bájalo a 0.5); **PROTECCION** más alta = consonantes y respiraciones más limpias."""),

code('''#@title 6 · Estudio — escribe tus textos y ejecuta esta celda
TEXTOS = """
bienvenida | Bienvenido a COSSMIL. [pausa] Le acompañaré paso a paso para reservar su cita médica.
Este es un texto de prueba: puede escribir aquí cualquier cosa que necesite, y se generará con la voz de la locutora.
"""
VOZ_BASE = "es-BO-SofiaNeural"  #@param @@VOCES@@
VELOCIDAD = -8     #@param {type:"slider", min:-40, max:30, step:1}
TONO_BASE_HZ = 0   #@param {type:"slider", min:-30, max:30, step:1}
PITCH_RVC = 0      #@param {type:"slider", min:-6, max:6, step:1}
INDEX_RATE = 0.7   #@param {type:"slider", min:0, max:1, step:0.05}
PROTECCION = 0.33  #@param {type:"slider", min:0, max:0.5, step:0.01}
LIMPIAR_RUIDO = False  #@param {type:"boolean"}
FORMATO = "mp3"    #@param ["mp3", "wav"]
NORMALIZAR_VOLUMEN = True  #@param {type:"boolean"}
DESCARGAR = True   #@param {type:"boolean"}
NOMBRE_LOTE = "estudio"  #@param {type:"string"}
PRONUNCIACION.update({
    # 'palabra como se escribe': 'como debe sonar',
})

AJUSTES.update(voz=VOZ_BASE, velocidad=VELOCIDAD, tono_hz=TONO_BASE_HZ, pitch=PITCH_RVC,
               index_rate=INDEX_RATE, protect=PROTECCION, limpiar=LIMPIAR_RUIDO,
               formato=FORMATO, normalizar=NORMALIZAR_VOLUMEN)
producir(parse_textos(TEXTOS), lote=nombre_seguro(NOMBRE_LOTE), descargar=DESCARGAR)'''),

code("""#@title 7 · (Opcional) Generar desde un archivo .txt / .json / .csv
USAR_ARCHIVO = False  #@param {type:"boolean"}
#@markdown `.txt`: mismo formato que la celda 6 · `.json`: `{"id": "texto"}` o `[{"id":…, "texto":…}]` · `.csv`: columnas `id,texto`.
#@markdown Usa los ajustes de sonido de la celda 6.
if USAR_ARCHIVO:
    from google.colab import files
    pares = []
    for nombre, datos in files.upload().items():
        pares += parse_archivo(nombre, datos)
    producir(pares, lote='archivo', mostrar=6)
else:
    print('Omitido (marca USAR_ARCHIVO para subir un archivo de textos).')"""),

code("""#@title 8 · (Opcional) Voces de la app COSSMIL (guion del tutorial y Modo Guiado)
GENERAR_GUION_APP = False  #@param {type:"boolean"}
SOLO_GUIADO = False        #@param {type:"boolean"}
#@markdown Descarga `vof_tutorial.zip`: extrae los mp3 **directo** en `assets/vof_tutorial/` (sin subcarpeta).
GUION = @@GUION@@
if GENERAR_GUION_APP:
    pares = [(k, v) for k, v in GUION.items() if not SOLO_GUIADO or k.startswith('guiado_')]
    formato_previo, AJUSTES['formato'] = AJUSTES['formato'], 'mp3'  # la app usa <id>.mp3
    try:
        producir(pares, lote='vof_tutorial', mostrar=8)
    finally:
        AJUSTES['formato'] = formato_previo
else:
    print('Omitido (marca GENERAR_GUION_APP para regenerar los clips de la app).')"""),

code("""#@title 9 · (Opcional) Comparar voces base con la misma frase
COMPARAR = False  #@param {type:"boolean"}
FRASE = "Bienvenido a COSSMIL. Su cita médica fue registrada correctamente."  #@param {type:"string"}
#@markdown Escucha todas y copia la que más te guste en `VOZ_BASE` (celda 6). Todas pasan por el modelo de la locutora.
VOCES_A_PROBAR = @@VOCES@@
if COMPARAR:
    voz_previa = AJUSTES['voz']
    try:
        for voz in VOCES_A_PROBAR:
            AJUSTES['voz'] = voz
            producir([(voz, FRASE)], lote=f'comparar_{voz}', descargar=False, textos=False)
    finally:
        AJUSTES['voz'] = voz_previa
else:
    print('Omitido (marca COMPARAR para escuchar todas las voces base).')"""),
]

reemplazos = {
    '@@VOF@@': json.dumps(vof),
    '@@COMMIT@@': APPLIO_COMMIT,
    '@@MOTOR@@': motor,
    '@@GUION@@': json.dumps(lines, ensure_ascii=False, indent=1),
    '@@VOCES@@': json.dumps(VOCES),
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
