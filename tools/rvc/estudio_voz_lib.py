"""Motor del Estudio de voz COSSMIL (texto libre → voz de la locutora vof).

Este archivo se EMBEBE en la celda "Motor" del notebook de Colab al correr
`build_colab_notebook.py`. La parte de texto (parse_textos, segmentar, …) es
Python puro y se prueba localmente con `test_estudio_voz_lib.py`; la parte de
audio (edge-tts → RVC/Applio → ffmpeg) solo corre en Colab.

Formato del texto (una línea = un audio):

    # comentario (se ignora)
    bienvenida | Bienvenido a COSSMIL. [pausa] Le ayudaré con su cita.
    Esta línea no tiene nombre: se llamará clip_02_esta-linea-no-tiene.

Marcas dentro del texto: [pausa] (0,6 s), [pausa 1.5] o [pausa 800ms].
"""
import csv
import io
import json
import re
import unicodedata

PAUSA_DEFECTO = 0.6      # segundos de [pausa]
PAUSA_ENTRE_TROZOS = 0.25  # silencio al unir frases de un texto largo
MAX_CARACTERES = 400     # trozo máximo que se sintetiza de una vez

# Palabras que el TTS lee mal. Se aplican con límite de palabra y respetando mayúsculas.
PRONUNCIACION_DEFECTO = {
    'COSSMIL': 'Cossmil',
    'Dra.': 'doctora',
    'Dr.': 'doctor',
    'Nro.': 'número',
    'N°': 'número',
    'Sr.': 'señor',
    'Sra.': 'señora',
    'Cap.': 'capitán',
    'Tte.': 'teniente',
    'Cnl.': 'coronel',
}

_ID_VALIDO = re.compile(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,59}$')
_PAUSA = re.compile(r'\[\s*pausa(?:\s*[=:]?\s*(\d+(?:[.,]\d+)?)\s*(ms|s)?)?\s*\]', re.IGNORECASE)
_FIN_FRASE = re.compile(r'(?<=[.!?…;])\s+')


def slug(texto, palabras=4, largo=32):
    """'¡Hola, señor Pérez!' → 'hola-senor-perez' (seguro para nombre de archivo)."""
    t = unicodedata.normalize('NFKD', texto).encode('ascii', 'ignore').decode().lower()
    t = re.sub(r'\[[^\]]*\]', ' ', t)
    partes = re.findall(r'[a-z0-9]+', t)[:palabras]
    return '-'.join(partes)[:largo].strip('-') or 'audio'


def nombre_seguro(nombre):
    """Limpia un id escrito por el usuario para usarlo como nombre de archivo."""
    base = unicodedata.normalize('NFKD', nombre).encode('ascii', 'ignore').decode()
    base = re.sub(r'\.(mp3|wav|ogg|m4a)$', '', base.strip(), flags=re.IGNORECASE)
    base = re.sub(r'[^A-Za-z0-9_.-]+', '_', base).strip('._-')
    return base[:60] or 'audio'


def _auto(contador, texto):
    contador[0] += 1
    return f'clip_{contador[0]:02d}_{slug(texto)}'


def _unicos(pares):
    vistos, salida = {}, []
    for nombre, texto in pares:
        n = nombre
        if n in vistos:
            vistos[n] += 1
            n = f'{nombre}_{vistos[nombre]}'
        else:
            vistos[n] = 1
        salida.append((n, texto))
    return salida


def parse_textos(crudo):
    """Texto del formulario → [(nombre, texto)]. Ver formato en el docstring del módulo."""
    pares, auto = [], [0]
    for linea in crudo.splitlines():
        linea = linea.strip()
        if not linea or linea.startswith('#'):
            continue
        nombre, texto = None, linea
        if '|' in linea:
            izq, der = linea.split('|', 1)
            if _ID_VALIDO.match(izq.strip()) and der.strip():
                nombre, texto = nombre_seguro(izq), der.strip()
        if not re.sub(_PAUSA, '', texto).strip():
            continue
        if nombre is None:
            nombre = _auto(auto, texto)
        pares.append((nombre, texto))
    return _unicos(pares)


def parse_archivo(nombre_archivo, datos):
    """Archivo subido (.txt / .json / .csv) → [(nombre, texto)]."""
    texto = datos.decode('utf-8-sig') if isinstance(datos, bytes) else datos
    ext = nombre_archivo.lower().rsplit('.', 1)[-1]
    auto = [0]
    if ext == 'json':
        obj = json.loads(texto)
        if isinstance(obj, dict) and isinstance(obj.get('lines'), (dict, list)):
            obj = obj['lines']
        if isinstance(obj, dict):
            pares = [(nombre_seguro(k), str(v).strip()) for k, v in obj.items()]
        else:
            pares = []
            for it in obj:
                if isinstance(it, str):
                    pares.append((_auto(auto, it), it.strip()))
                else:
                    t = str(it.get('text') or it.get('texto') or '').strip()
                    n = it.get('id') or it.get('nombre')
                    pares.append((nombre_seguro(str(n)) if n else _auto(auto, t), t))
        return _unicos([(n, t) for n, t in pares if t])
    if ext == 'csv':
        filas = [f for f in csv.reader(io.StringIO(texto)) if any(c.strip() for c in f)]
        if filas and [c.strip().lower() for c in filas[0][:2]] in (['id', 'text'], ['id', 'texto'], ['nombre', 'texto']):
            filas = filas[1:]
        pares = []
        for f in filas:
            if len(f) >= 2 and f[1].strip():
                pares.append((nombre_seguro(f[0]) if f[0].strip() else _auto(auto, f[1]), f[1].strip()))
            elif f[0].strip():
                pares.append((_auto(auto, f[0]), f[0].strip()))
        return _unicos(pares)
    return parse_textos(texto)


def aplicar_pronunciacion(texto, diccionario):
    """Reemplaza palabras mal leídas por el TTS (claves más largas primero)."""
    for clave in sorted(diccionario, key=len, reverse=True):
        izq = r'(?<!\w)' if clave[0].isalnum() else ''
        der = r'(?!\w)' if clave[-1].isalnum() else ''
        texto = re.sub(izq + re.escape(clave) + der, diccionario[clave], texto)
    return texto


def _segundos(num, unidad):
    if num is None:
        return PAUSA_DEFECTO
    v = float(num.replace(',', '.'))
    return v / 1000 if (unidad or '').lower() == 'ms' else v


def _trocear(frase, max_car):
    """Parte un texto largo en trozos ≤ max_car cortando en fin de frase (o en comas)."""
    if len(frase) <= max_car:
        return [frase]
    trozos, actual = [], ''
    for oracion in _FIN_FRASE.split(frase):
        piezas = [oracion] if len(oracion) <= max_car else re.split(r'(?<=,)\s+', oracion)
        for p in piezas:
            while len(p) > max_car:  # sin puntuación: corte duro en el último espacio
                corte = p.rfind(' ', 0, max_car)
                corte = corte if corte > 0 else max_car
                if actual:
                    trozos.append(actual); actual = ''
                trozos.append(p[:corte].strip()); p = p[corte:].strip()
            if actual and len(actual) + 1 + len(p) > max_car:
                trozos.append(actual); actual = p
            else:
                actual = f'{actual} {p}'.strip()
    if actual:
        trozos.append(actual)
    return [t for t in trozos if t]


def segmentar(texto, max_car=MAX_CARACTERES, pausa_trozos=PAUSA_ENTRE_TROZOS):
    """Texto → [('habla', str) | ('silencio', segundos)] listo para sintetizar."""
    salida, pos = [], 0

    def agregar_habla(fragmento):
        fragmento = re.sub(r'\s+', ' ', fragmento).strip()
        if not fragmento:
            return
        for i, t in enumerate(_trocear(fragmento, max_car)):
            if i:
                salida.append(('silencio', pausa_trozos))
            salida.append(('habla', t))

    for m in _PAUSA.finditer(texto):
        agregar_habla(texto[pos:m.start()])
        salida.append(('silencio', _segundos(m.group(1), m.group(2))))
        pos = m.end()
    agregar_habla(texto[pos:])
    while salida and salida[0][0] == 'silencio':
        salida.pop(0)
    while salida and salida[-1][0] == 'silencio':
        salida.pop()
    return salida


# ─────────────────────────── Audio (solo Colab) ───────────────────────────

def _ffmpeg(*args):
    import subprocess
    r = subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)],
                       capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'ffmpeg falló: {r.stderr[-800:]}')


def duracion(ruta):
    import subprocess
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                          '-of', 'default=nk=1:nw=1', ruta], capture_output=True, text=True).stdout
    return float(out or 0)


def sintetizar_base(texto, ruta_wav, voz, velocidad=0, tono_hz=0, intentos=4):
    """edge-tts (gratis, voz femenina neural) → WAV mono 44,1 kHz. Reintenta cortes de red."""
    import os, time
    import edge_tts
    mp3 = ruta_wav[:-4] + '.mp3'
    for n in range(1, intentos + 1):
        try:
            edge_tts.Communicate(texto, voice=voz, rate=f'{int(velocidad):+d}%',
                                 pitch=f'{int(tono_hz):+d}Hz').save_sync(mp3)
            if os.path.getsize(mp3) > 0:
                break
        except Exception as e:  # noqa: BLE001 — red de Colab inestable
            if n == intentos:
                raise RuntimeError(f'edge-tts no respondió ({e}). Revisa la conexión y re-ejecuta.') from e
            time.sleep(2 * n)
    _ffmpeg('-i', mp3, '-ac', 1, '-ar', 44100, ruta_wav)
    os.remove(mp3)


def ensamblar(partes, ruta_salida):
    """partes = [('wav', ruta) | ('silencio', seg)] → un solo WAV (misma frecuencia)."""
    import numpy as np
    import soundfile as sf
    sr, bloques = None, []
    for tipo, valor in partes:
        if tipo == 'wav':
            audio, sr_i = sf.read(valor, dtype='float32', always_2d=False)
            if audio.ndim > 1:
                audio = audio.mean(axis=1)
            if sr is None:
                sr = sr_i
            elif sr_i != sr:
                raise RuntimeError(f'frecuencias distintas ({sr_i} vs {sr}) en {valor}')
            bloques.append(audio)
        else:
            bloques.append(('silencio', valor))
    sr = sr or 44100
    final = [np.zeros(int(b[1] * sr), dtype='float32') if isinstance(b, tuple) else b for b in bloques]
    sf.write(ruta_salida, np.concatenate(final) if final else np.zeros(1, 'float32'), sr)


def masterizar(ruta_wav, ruta_salida, formato='mp3', normalizar=True, cola=0.25, lufs=-16.0):
    """Recorta silencios de borde, iguala el volumen a `lufs` (el de la locutora), suaviza bordes y exporta."""
    filtros = [
        'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05',
        'areverse',
        'silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05',
        'areverse',
    ]
    if normalizar:
        filtros.append(f'loudnorm=I={max(-30.0, min(-9.0, lufs)):.1f}:TP=-1.0:LRA=11')
    filtros += ['afade=t=in:d=0.02', f'apad=pad_dur={cola}']
    args = ['-i', ruta_wav, '-af', ','.join(filtros), '-ac', 1, '-ar', 44100]
    args += ['-b:a', '128k'] if formato == 'mp3' else ['-c:a', 'pcm_s16le']
    _ffmpeg(*args, ruta_salida)


def generar(pares, voz, carpeta, convertir, velocidad=0, tono_hz=0, pronunciacion=None,
            formato='mp3', normalizar=True, sintetizar=None, log=print, lufs=-16.0):
    """[(nombre, texto)] → {nombre: ruta_final}.

    `convertir(carpeta_entrada, carpeta_salida)` aplica RVC a todos los WAV de una
    vez (el modelo se carga una sola vez) y deja `<base>.wav` en la salida.
    """
    import glob, os, shutil
    sintetizar = sintetizar or sintetizar_base
    pronunciacion = PRONUNCIACION_DEFECTO if pronunciacion is None else pronunciacion
    base_dir, rvc_dir, fin_dir = (os.path.join(carpeta, d) for d in ('base', 'rvc', 'final'))
    for d in (base_dir, rvc_dir, fin_dir):
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)

    planes = {}
    for i, (nombre, texto) in enumerate(pares, 1):
        plan = []
        for j, (tipo, valor) in enumerate(segmentar(aplicar_pronunciacion(texto, pronunciacion))):
            if tipo == 'habla':
                pieza = f'{i:03d}_{j:03d}'
                sintetizar(valor, os.path.join(base_dir, pieza + '.wav'), voz, velocidad, tono_hz)
                plan.append(('wav', pieza))
            else:
                plan.append(('silencio', valor))
        planes[nombre] = plan
        log(f'  [{i}/{len(pares)}] texto base: {nombre}')

    log('  convirtiendo a la voz de la locutora (RVC)…')
    convertir(base_dir, rvc_dir)

    salidas = {}
    for nombre, plan in planes.items():
        partes = []
        for tipo, valor in plan:
            if tipo == 'wav':
                ruta = os.path.join(rvc_dir, valor + '.wav')
                if not os.path.exists(ruta):
                    raise RuntimeError(f'RVC no produjo {valor}.wav (¿falló la conversión?). '
                                       f'Archivos en salida: {sorted(os.listdir(rvc_dir))[:5]}')
                partes.append(('wav', ruta))
            else:
                partes.append(('silencio', valor))
        crudo = os.path.join(rvc_dir, f'_{nombre}.wav')
        ensamblar(partes, crudo)
        final = os.path.join(fin_dir, f'{nombre}.{formato}')
        masterizar(crudo, final, formato, normalizar, lufs=lufs)
        salidas[nombre] = final
    for f in glob.glob(os.path.join(rvc_dir, '_*.wav')):
        os.remove(f)
    return salidas


# ─────────────────────── Calibración contra la voz real ───────────────────────

def _cargar_16k(rutas):
    import librosa
    import numpy as np
    partes = [librosa.load(r, sr=16000, mono=True)[0] for r in rutas]
    return np.concatenate(partes) if partes else np.zeros(16000, 'float32')


def analizar_voz(rutas):
    """Rasgos objetivos de una voz: tono (mediana de F0 en Hz), rango tonal
    (semitonos p10–p90), ritmo (sílabas/s aprox. por picos de energía) y segundos de habla."""
    import librosa
    import numpy as np
    from scipy.signal import find_peaks
    y = _cargar_16k([rutas] if isinstance(rutas, str) else rutas)
    f0, sonoro, _ = librosa.pyin(y, fmin=90, fmax=450, sr=16000, frame_length=1024, hop_length=160)
    f0 = f0[sonoro & ~np.isnan(f0)]
    if len(f0) < 10:
        raise RuntimeError('No se detectó voz suficiente para analizar.')
    # Envolvente de energía de la banda vocal (100 cuadros/s) → cada pico ≈ una sílaba
    banda = librosa.effects.preemphasis(y)
    rms = librosa.feature.rms(y=banda, frame_length=400, hop_length=160)[0]
    rms = np.convolve(rms, np.hanning(7) / np.hanning(7).sum(), mode='same')
    umbral = 0.12 * np.percentile(rms, 95)
    habla = rms > umbral
    # Une huecos cortos (<250 ms: oclusivas, valles entre sílabas) → tiempo de habla, sin contar pausas.
    huecos = np.flatnonzero(np.diff(np.concatenate([[1], habla.astype(int), [1]])))
    for ini, fin in zip(huecos[::2], huecos[1::2]):
        if 0 < ini and fin < len(habla) and fin - ini < 25:
            habla[ini:fin] = True
    picos, _ = find_peaks(rms, height=umbral, distance=8, prominence=0.08 * np.percentile(rms, 95))
    seg_habla = max(habla.sum() / 100, 0.1)
    return {
        'f0': float(np.median(f0)),
        'rango_st': float(12 * np.log2(np.percentile(f0, 90) / np.percentile(f0, 10))),
        'silabas_s': float(len(picos) / seg_habla),
        'seg_habla': float(seg_habla),
    }


def calibrar_base(ref, base, vel_actual=0, tono_actual=0):
    """Con los rasgos de la locutora (ref) y de una voz base ya sintetizada,
    calcula la velocidad (%) y el tono (Hz) de edge-tts que la acercan a la locutora."""
    import math
    factor = ref['silabas_s'] / max(base['silabas_s'], 0.1)
    velocidad = (1 + vel_actual / 100) * factor * 100 - 100
    tono = tono_actual + (ref['f0'] - base['f0'])
    return {'velocidad': int(max(-35, min(25, round(velocidad)))),
            'tono_hz': int(max(-40, min(40, round(tono)))),
            'dif_st': 12 * math.log2(ref['f0'] / base['f0'])}


def distancia_rasgos(ref, otro):
    """Qué tan lejos está una salida de la locutora en tono, ritmo y expresividad (0 = igual)."""
    import math
    return (abs(12 * math.log2(otro['f0'] / ref['f0']))            # semitonos
            + 4 * abs(math.log(max(otro['silabas_s'], 0.1) / max(ref['silabas_s'], 0.1)))  # ritmo
            + 0.3 * abs(otro['rango_st'] - ref['rango_st']))       # entonación


def medir_lufs(ruta):
    """Sonoridad integrada (LUFS) con ffmpeg loudnorm."""
    import json as _json, re as _re, subprocess
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', ruta, '-af',
                        'loudnorm=print_format=json', '-f', 'null', '-'], capture_output=True, text=True)
    m = _re.search(r'\{[^{}]*"input_i"[^{}]*\}', r.stderr)
    return float(_json.loads(m.group(0))['input_i']) if m else -16.0


def analizar_varias(entradas):
    """analizar_voz para varias entradas (cada una: ruta o lista de rutas) cargando librosa una vez."""
    return [analizar_voz(e) for e in entradas]


def similitudes(referencias, candidatos):
    """Similitud de hablante (coseno, WavLM-SV) de cada candidato contra el promedio de las
    referencias. Devuelve {'sims': [...]} o {'sims': None, 'aviso': motivo} si no hay red."""
    try:
        import librosa
        import numpy as np
        import torch
        from transformers import AutoFeatureExtractor, WavLMForXVector
        dev = 'cuda' if torch.cuda.is_available() else 'cpu'
        fe = AutoFeatureExtractor.from_pretrained('microsoft/wavlm-base-plus-sv')
        red = WavLMForXVector.from_pretrained('microsoft/wavlm-base-plus-sv').to(dev).eval()

        def vector(ruta):
            y = librosa.load(ruta, sr=16000, mono=True)[0][:16000 * 20]
            x = fe(y, sampling_rate=16000, return_tensors='pt').to(dev)
            with torch.no_grad():
                e = red(**x).embeddings[0]
            return torch.nn.functional.normalize(e, dim=-1).cpu().numpy()

        ref = np.mean([vector(r) for r in referencias], axis=0)
        ref = ref / np.linalg.norm(ref)
        return {'sims': [float(vector(c) @ ref) for c in candidatos]}
    except Exception as e:  # noqa: BLE001 — sin la red se calibra solo con tono/ritmo
        return {'sims': None, 'aviso': f'{type(e).__name__}: {str(e)[:160]}'}


if __name__ == '__main__':
    # En Colab las funciones con numpy/librosa/torch/edge-tts corren en un proceso aparte:
    # la instalación de Applio cambia numpy en disco y el kernel ya tiene cargado el viejo.
    import sys
    _resultado = globals()[sys.argv[1]](*json.loads(sys.argv[2]))
    print('@@RESULTADO@@' + json.dumps(_resultado))
