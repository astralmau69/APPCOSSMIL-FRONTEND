"""Motor del Estudio de voz COSSMIL (texto libre → voz de la locutora vof).

Este archivo se EMBEBE en la celda "Motor" del notebook de Colab al correr
`build_colab_notebook.py`. La parte de texto (parse_textos, segmentar, …) es
Python puro y se prueba localmente con `test_estudio_voz_lib.py`; la parte de
audio (clonación Chatterbox desde las vof → RVC opcional → ffmpeg) solo corre en Colab.

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


_UNIDADES = ('cero uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince '
             'dieciséis diecisiete dieciocho diecinueve veinte veintiuno veintidós veintitrés veinticuatro '
             'veinticinco veintiséis veintisiete veintiocho veintinueve').split()
_DECENAS = {3: 'treinta', 4: 'cuarenta', 5: 'cincuenta', 6: 'sesenta', 7: 'setenta', 8: 'ochenta', 9: 'noventa'}
_CENTENAS = {1: 'ciento', 2: 'doscientos', 3: 'trescientos', 4: 'cuatrocientos', 5: 'quinientos',
             6: 'seiscientos', 7: 'setecientos', 8: 'ochocientos', 9: 'novecientos'}


def _apocope(palabras):
    """'veintiuno' → 'veintiún', 'treinta y uno' → 'treinta y un' (delante de un sustantivo o de mil)."""
    if palabras.endswith('veintiuno'):
        return palabras[:-9] + 'veintiún'
    return palabras[:-3] + 'un' if palabras.endswith('uno') else palabras


def _cardinal(n):
    """Entero (0 ≤ n < 10**12) → palabras en español ('ciento veintiuno')."""
    if n < 30:
        return _UNIDADES[n]
    if n < 100:
        d, u = divmod(n, 10)
        return _DECENAS[d] + (f' y {_UNIDADES[u]}' if u else '')
    if n < 1000:
        c, r = divmod(n, 100)
        if n == 100:
            return 'cien'
        return _CENTENAS[c] + (f' {_cardinal(r)}' if r else '')
    if n < 10**6:
        m, r = divmod(n, 1000)
        miles = 'mil' if m == 1 else f'{_apocope(_cardinal(m))} mil'
        return miles + (f' {_cardinal(r)}' if r else '')
    mm, r = divmod(n, 10**6)
    millones = 'un millón' if mm == 1 else f'{_apocope(_cardinal(mm))} millones'
    return millones + (f' {_cardinal(r)}' if r else '')


def numeros_a_palabras(texto):
    """Horas (8:30), porcentajes y enteros → palabras: el modelo de voz lee mal los dígitos.
    Deja intactos los números largos tipo código (≥ 7 dígitos) salvo que tengan separador de miles,
    y las marcas entre corchetes ([pausa 1.5])."""
    partes = re.split(r'(\[[^\]]*\])', texto)
    return ''.join(p if p.startswith('[') else _numeros(p) for p in partes)


def _numeros(texto):
    def hora(m):
        h, mi = int(m.group(1)), int(m.group(2))
        if h > 24 or mi > 59:
            return m.group(0)
        h_txt = 'una' if h == 1 else _cardinal(h)
        return h_txt if mi == 0 else f'{h_txt} y {_cardinal(mi)}'
    texto = re.sub(r'\b(\d{1,2}):(\d{2})\b', hora, texto)
    texto = re.sub(r'\b(\d{1,3}(?:\.\d{3})+)\b', lambda m: m.group(1).replace('.', ''), texto)
    texto = re.sub(r'(\d+)\s?%', lambda m: m.group(1) + ' por ciento', texto)

    def entero(m):
        dig, sigue = m.group(1), m.group(2) or ''
        if len(dig) >= 7:
            return m.group(0)
        palabras = _cardinal(int(dig))
        if sigue:  # apócope ante sustantivo: un médico, veintiún días
            palabras = _apocope(palabras)
        return palabras + sigue
    return re.sub(r'(?<![\w.,])(\d+)(?![\w]|[.,]\d)(\s+(?=[^\W\d_]))?', entero, texto)


def cerrar_frase(texto):
    """El modelo tiende a cortar o balbucear si la frase no termina en puntuación."""
    texto = texto.strip()
    return texto if not texto or texto[-1] in '.!?…' else texto.rstrip(',;:') + '.'


def _palabras(texto):
    t = unicodedata.normalize('NFKD', texto.lower()).encode('ascii', 'ignore').decode()
    return re.findall(r'[a-z0-9]+', t)


def coincidencia(esperado, oido):
    """Compara el texto pedido con lo que se entiende en el audio (transcripción).
    Devuelve (parecido 0–1 por palabras, ¿se oye el final?) — detecta cortes y balbuceos."""
    import difflib
    a, b = _palabras(numeros_a_palabras(esperado)), _palabras(numeros_a_palabras(oido))
    if not a:
        return 1.0, True
    if not b:
        return 0.0, False
    conocidas = set(a)
    for i, w in enumerate(b):  # variantes de escritura (Cossmil/Cosmil) cuentan como la misma palabra
        if w not in conocidas:
            cerca = max(conocidas, key=lambda c: difflib.SequenceMatcher(None, c, w).ratio())
            if difflib.SequenceMatcher(None, cerca, w).ratio() >= 0.8:
                b[i] = cerca
    parecido = difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()
    cola = b[-4:]
    fin = any(difflib.SequenceMatcher(None, a[-1], w).ratio() >= 0.75 for w in cola)
    if len(a) >= 2:  # la penúltima también debe estar cerca del final
        fin = fin and any(difflib.SequenceMatcher(None, a[-2], w).ratio() >= 0.75 for w in b[-6:])
    return round(parecido, 3), fin


def puntuar_toma(parecido, fin, razon_duracion, snr_db=None, mos=None, fondo=None):
    """Nota de una toma: manda que se entienda completa; luego que el FONDO esté limpio
    (DNSMOS: bak = limpieza del fondo, ovr = calidad global), la naturalidad (UTMOS: lo que
    separa una toma humana de una robótica), la duración plausible y la relación señal/ruido."""
    import math
    nota = parecido + (0.1 if fin else -0.35)
    nota -= 0.3 * max(0.0, abs(math.log(max(razon_duracion, 1e-3))) - math.log(1.5))
    if snr_db is not None:
        nota -= 0.01 * max(0.0, 40.0 - snr_db)
    if mos is not None:
        nota += 0.3 * (mos - 3.5)
    if fondo:
        nota -= 0.6 * max(0.0, FONDO_LIMPIO - fondo['bak'])  # cualquier ruido audible pesa mucho
        nota += 0.2 * (fondo['ovr'] - 3.3)
    return round(nota, 4)


FONDO_LIMPIO = 4.0  # DNSMOS bak de las vof originales: 4,06–4,22


def silabas_estimadas(texto):
    """Sílabas aproximadas (grupos vocálicos) para prever cuánto debería durar un audio."""
    return max(1, len(re.findall(r'[aeiouáéíóúü]+', texto.lower())))


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
            elif sr_i != sr:  # p. ej. un trozo sin realce (24 kHz) entre trozos realzados (44,1 kHz)
                import librosa
                audio = librosa.resample(audio, orig_sr=sr_i, target_sr=sr)
            bloques.append(audio)
        else:
            bloques.append(('silencio', valor))
    sr = sr or 44100
    final = [np.zeros(int(b[1] * sr), dtype='float32') if isinstance(b, tuple) else b for b in bloques]
    sf.write(ruta_salida, np.concatenate(final) if final else np.zeros(1, 'float32'), sr)


def masterizar(ruta_wav, ruta_salida, formato='mp3', normalizar=True, cola=0.25, lufs=-16.0):
    """Recorta silencios de borde SIN comerse finales de palabra (umbral bajo y 150 ms de
    margen), quita zumbidos graves, funde entrada y salida, e iguala el volumen a `lufs` (el
    de la locutora) con una GANANCIA LINEAL PURA, limitada para que ningún pico pase de −1 dBFS.
    Sin compresión ni limitador: el loudnorm de una pasada sube el ruido de las pausas y un
    limitador rápido hace "respirar" el fondo (medido con DNSMOS: bak 3,82 → 3,62)."""
    import os
    import tempfile
    borde = 'silenceremove=start_periods=1:start_threshold=-58dB:start_silence=0.15'
    recorte = ['highpass=f=70', borde, 'areverse', borde, 'afade=t=in:d=0.06', 'areverse',
               'afade=t=in:d=0.02']
    fd, tmp = tempfile.mkstemp(suffix='.wav')
    os.close(fd)
    try:
        _ffmpeg('-i', ruta_wav, '-af', ','.join(recorte), '-ac', 1, '-ar', 44100, '-c:a', 'pcm_f32le', tmp)
        filtros = []
        if normalizar:
            objetivo = max(-30.0, min(-9.0, lufs))
            ganancia = max(-20.0, min(30.0, objetivo - medir_lufs(tmp), -1.0 - medir_pico_db(tmp)))
            filtros.append(f'volume={ganancia:.2f}dB')
        filtros.append(f'apad=pad_dur={cola}')
        args = ['-i', tmp, '-af', ','.join(filtros), '-ac', 1, '-ar', 44100]
        args += ['-b:a', '160k'] if formato == 'mp3' else ['-c:a', 'pcm_s16le']
        _ffmpeg(*args, ruta_salida)
    finally:
        os.remove(tmp)


def generar(pares, voz, carpeta, convertir, velocidad=0, tono_hz=0, pronunciacion=None,
            formato='mp3', normalizar=True, sintetizar=None, log=print, lufs=-16.0,
            sintetizar_lote=None, max_car=MAX_CARACTERES):
    """[(nombre, texto)] → {nombre: ruta_final}.

    Voz: `sintetizar_lote([[texto, ruta_wav], …])` genera todos los trozos de una vez
    (clonación: el modelo se carga una sola vez) o, si no se da, `sintetizar` trozo a trozo.
    `convertir(carpeta_entrada, carpeta_salida)` aplica RVC en lote y deja `<base>.wav`;
    con `convertir=None` se usa la voz tal cual.
    """
    import glob, os, shutil
    pronunciacion = PRONUNCIACION_DEFECTO if pronunciacion is None else pronunciacion
    base_dir, rvc_dir, fin_dir = (os.path.join(carpeta, d) for d in ('base', 'rvc', 'final'))
    for d in (base_dir, rvc_dir, fin_dir):
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)

    planes, trabajos = {}, []
    for i, (nombre, texto) in enumerate(pares, 1):
        plan = []
        limpio = numeros_a_palabras(aplicar_pronunciacion(texto, pronunciacion))
        for j, (tipo, valor) in enumerate(segmentar(limpio, max_car=max_car)):
            if tipo == 'habla':
                valor = cerrar_frase(valor)
                pieza = f'{i:03d}_{j:03d}'
                trabajos.append([valor, os.path.join(base_dir, pieza + '.wav')])
                plan.append(('wav', pieza))
            else:
                plan.append(('silencio', valor))
        planes[nombre] = plan

    if sintetizar_lote:
        log(f'  generando {len(trabajos)} frase(s) con la voz clonada…')
        sintetizar_lote(trabajos)
    else:
        for n, (valor, ruta) in enumerate(trabajos, 1):
            sintetizar(valor, ruta, voz, velocidad, tono_hz)
            log(f'  [{n}/{len(trabajos)}] texto base')

    if convertir:
        log('  reforzando el timbre con RVC…')
        convertir(base_dir, rvc_dir)
    else:
        for f in glob.glob(os.path.join(base_dir, '*.wav')):
            shutil.copy(f, rvc_dir)

    salidas = {}
    for nombre, plan in planes.items():
        partes = []
        for tipo, valor in plan:
            if tipo == 'wav':
                ruta = os.path.join(rvc_dir, valor + '.wav')
                if not os.path.exists(ruta):
                    raise RuntimeError(f'No se generó {valor}.wav (¿falló la voz o RVC?). '
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


def distancia_rasgos(ref, otro):
    """Qué tan lejos está una salida de la locutora en tono, ritmo y expresividad (0 = igual)."""
    import math
    return (abs(12 * math.log2(otro['f0'] / ref['f0']))            # semitonos
            + 4 * abs(math.log(max(otro['silabas_s'], 0.1) / max(ref['silabas_s'], 0.1)))  # ritmo
            + 0.3 * abs(otro['rango_st'] - ref['rango_st']))       # entonación


def medir_pico_db(ruta):
    """Pico de muestra en dBFS (ffmpeg volumedetect)."""
    import re as _re, subprocess
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', ruta, '-af', 'volumedetect',
                        '-f', 'null', '-'], capture_output=True, text=True)
    m = _re.search(r'max_volume:\s*(-?[\d.]+) dB', r.stderr)
    return float(m.group(1)) if m else 0.0


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


def preparar_referencias(wavs, carpeta, seg_min=8.0):
    """Referencias para clonar: cada vof sin silencios de borde y con pausas internas acortadas.
    La candidata i empieza con la vof i (el modelo toma de ahí la prosodia, primeros 6-10 s) y
    sigue con las demás (la huella de la voz se calcula sobre todo el audio)."""
    import os
    import librosa
    import numpy as np
    import soundfile as sf
    os.makedirs(carpeta, exist_ok=True)
    limpios = []
    for w in wavs:
        y, sr = librosa.load(w, sr=24000, mono=True)
        trozos = [y[a:b] for a, b in librosa.effects.split(y, top_db=35)]
        pausa = np.zeros(int(0.25 * sr), 'float32')
        partes = []
        for t in trozos:
            partes += [t, pausa]
        limpios.append(np.concatenate(partes[:-1]) if partes else y)
    salidas = []
    for i, y in enumerate(limpios):
        resto = [z for j, z in enumerate(limpios) if j != i]
        todo = np.concatenate([y] + resto)
        ruta = os.path.join(carpeta, f'ref_{os.path.splitext(os.path.basename(wavs[i]))[0]}.wav')
        sf.write(ruta, (0.9 * todo / max(1e-6, np.abs(todo).max())).astype('float32'), 24000)
        salidas.append({'ruta': ruta, 'seg_propios': round(len(y) / 24000, 1)})
    return salidas


def _modelo_clonacion():
    import torch
    from chatterbox.mtl_tts import ChatterboxMultilingualTTS
    return ChatterboxMultilingualTTS.from_pretrained(device='cuda' if torch.cuda.is_available() else 'cpu')


def _cargar_asr(nombre='openai/whisper-large-v3-turbo'):
    """Whisper para 'escuchar' cada toma. Devuelve transcribir(y, sr) o None si no se puede."""
    try:
        import librosa
        import torch
        from transformers import WhisperForConditionalGeneration, WhisperProcessor
        dev = 'cuda' if torch.cuda.is_available() else 'cpu'
        tipo = torch.float16 if dev == 'cuda' else torch.float32
        proc = WhisperProcessor.from_pretrained(nombre)
        red = WhisperForConditionalGeneration.from_pretrained(nombre).to(dev, dtype=tipo).eval()

        def transcribir(y, sr):
            y16 = librosa.resample(y, orig_sr=sr, target_sr=16000) if sr != 16000 else y
            x = proc(y16, sampling_rate=16000, return_tensors='pt').input_features.to(dev, dtype=tipo)
            with torch.no_grad():
                ids = red.generate(x, language='es', task='transcribe', max_new_tokens=220)
            return proc.batch_decode(ids, skip_special_tokens=True)[0]
        return transcribir
    except Exception as e:  # noqa: BLE001
        print(f'  [aviso] verificación con Whisper no disponible ({type(e).__name__}: {str(e)[:120]}); '
              'se usa solo la duración', flush=True)
        return None


def _cargar_mos():
    """UTMOS (predictor de naturalidad, MOS 1–5). Devuelve mos(y, sr) o None."""
    try:
        import librosa
        import torch
        dev = 'cuda' if torch.cuda.is_available() else 'cpu'
        red = torch.hub.load('tarepan/SpeechMOS:v1.2.0', 'utmos22_strong', trust_repo=True).to(dev).eval()

        def mos(y, sr):
            y16 = librosa.resample(y, orig_sr=sr, target_sr=16000) if sr != 16000 else y
            with torch.no_grad():
                return float(red(torch.from_numpy(y16).float().unsqueeze(0).to(dev), 16000).item())
        return mos
    except Exception as e:  # noqa: BLE001
        print(f'  [aviso] medidor de naturalidad (UTMOS) no disponible ({type(e).__name__}: {str(e)[:100]})', flush=True)
        return None


def _cargar_limpiador():
    """DeepFilterNet 3 (MIT/Apache): quita ruido de fondo con una red NO generativa (no inventa
    sonidos). Devuelve limpiar(y, sr) -> (y, 48000) o None."""
    try:
        import librosa
        import torch
        from df.enhance import enhance, init_df
        modelo, estado, _ = init_df(log_level='ERROR', log_file=None)
        sr_df = estado.sr()

        def limpiar(y, sr):
            y48 = librosa.resample(y, orig_sr=sr, target_sr=sr_df) if sr != sr_df else y
            with torch.no_grad():
                out = enhance(modelo, estado, torch.from_numpy(y48).float().unsqueeze(0))
            return out.squeeze(0).detach().cpu().numpy().astype('float32'), int(sr_df)
        return limpiar
    except Exception as e:  # noqa: BLE001
        print(f'  [aviso] limpiador DeepFilterNet no disponible ({type(e).__name__}: {str(e)[:100]})', flush=True)
        return None


def _cargar_realce(fuerza=0.9):
    """Resemble Enhance (MIT): quita ruido con una red neuronal y reconstruye la voz a 44,1 kHz
    (más nítida que los 24 kHz del modelo de voz). Devuelve realzar(y, sr) -> (y, sr) o None."""
    try:
        import torch
        from resemble_enhance.enhancer.inference import enhance
        dev = 'cuda' if torch.cuda.is_available() else 'cpu'

        def realzar(y, sr):
            wav, sr2 = enhance(torch.from_numpy(y).float(), sr, dev, nfe=64, solver='midpoint',
                               lambd=fuerza, tau=0.5)
            return wav.detach().cpu().numpy().astype('float32'), int(sr2)
        return realzar
    except Exception as e:  # noqa: BLE001
        print(f'  [aviso] realce de nitidez (Resemble Enhance) no disponible ({type(e).__name__}: {str(e)[:100]})',
              flush=True)
        return None


_DNSMOS_URL = 'https://raw.githubusercontent.com/microsoft/DNS-Challenge/master/DNSMOS/DNSMOS/sig_bak_ovr.onnx'
_DNSMOS = {}
_AVISOS = {}


def dnsmos(y, sr):
    """DNSMOS P.835 de Microsoft (sin referencia): califica de 1 a 5 la VOZ (sig), el FONDO
    (bak: 5 = sin ruido audible) y el conjunto (ovr). Corre con onnxruntime (sin torch).
    Devuelve {'sig', 'bak', 'ovr'} o None si no se puede cargar el modelo."""
    import os
    import numpy as np
    try:
        if 'sesion' not in _DNSMOS:
            import onnxruntime as ort
            ruta = os.path.expanduser('~/.cache/cossmil_dnsmos/sig_bak_ovr.onnx')
            if not os.path.exists(ruta):
                import urllib.request
                os.makedirs(os.path.dirname(ruta), exist_ok=True)
                urllib.request.urlretrieve(_DNSMOS_URL, ruta + '.tmp')
                os.replace(ruta + '.tmp', ruta)
            _DNSMOS['sesion'] = ort.InferenceSession(ruta, providers=['CPUExecutionProvider'])
        sesion = _DNSMOS['sesion']
    except Exception as e:  # noqa: BLE001
        if not _AVISOS.get('dnsmos'):
            _AVISOS['dnsmos'] = True
            print(f'  [aviso] medidor de ruido DNSMOS no disponible ({type(e).__name__}: {str(e)[:100]})', flush=True)
        return None
    y = np.asarray(y, dtype='float32')
    if sr != 16000:
        import librosa
        y = librosa.resample(y, orig_sr=sr, target_sr=16000)
    largo = int(9.01 * 16000)
    while len(y) < largo:  # como el original: repite el audio hasta 9,01 s
        y = np.concatenate([y, y])
    saltos = int(np.floor(len(y) / 16000) - 9.01) + 1
    crudos = []
    for i in range(max(1, saltos)):
        seg = y[i * 16000:i * 16000 + largo]
        if len(seg) < largo:
            continue
        crudos.append(sesion.run(None, {'input_1': seg[np.newaxis, :]})[0][0])
    sig, bak, ovr = np.mean(crudos, axis=0)
    return {'sig': float(np.poly1d([-0.08397278, 1.22083953, 0.0052439])(sig)),
            'bak': float(np.poly1d([-0.13166888, 1.60915514, -0.39604546])(bak)),
            'ovr': float(np.poly1d([-0.06766283, 1.11546468, 0.04602535])(ovr))}


def relacion_senal_ruido(y, sr):
    """dB entre la voz (percentil 95 de energía) y el fondo (percentil 10)."""
    import numpy as np
    marco = int(0.02 * sr)
    n = len(y) // marco
    if n < 10:
        return 60.0
    e = np.sqrt(np.mean(y[:n * marco].reshape(n, marco) ** 2, axis=1)) + 1e-9
    return float(20 * np.log10(np.percentile(e, 95) / np.percentile(e, 10)))


def tramos_de_voz(y, sr, umbral_db=-35.0, hueco_max=0.15, minimo=0.05):
    """[(inicio, fin)] en muestras de los tramos con voz: cuadros de 10 ms sobre `umbral_db`
    respecto a la voz fuerte, uniendo huecos cortos (< `hueco_max` s) y sin tramos mínimos."""
    import numpy as np
    marco = max(1, int(0.01 * sr))
    n = len(y) // marco
    if n == 0:
        return []
    e = np.sqrt(np.mean(np.asarray(y[:n * marco], dtype='float64').reshape(n, marco) ** 2, axis=1)) + 1e-9
    voz = 20 * np.log10(e / np.percentile(e, 95)) > umbral_db
    tramos, i = [], 0
    while i < n:
        if voz[i]:
            j = i
            while j < n and voz[j]:
                j += 1
            tramos.append([i, j])
            i = j
        else:
            i += 1
    unidos = []
    for t in tramos:
        if unidos and (t[0] - unidos[-1][1]) * 0.01 < hueco_max:
            unidos[-1][1] = t[1]
        else:
            unidos.append(t)
    return [(a * marco, b * marco) for a, b in unidos if (b - a) * 0.01 >= minimo]


def recortar_bordes(y, sr, texto, asr=None, margen_ini=0.08, margen_fin=0.15, max_cortes=3):
    """Quita lo que sobra antes de la primera palabra y DESPUÉS de la última (el modelo a veces
    agrega al final un respiro, un murmullo o sonidos sueltos). Un tramo final se corta solo si,
    sin él, Whisper sigue oyendo el texto completo; sin Whisper, solo si es un chasquido corto
    (< 0,25 s) y separado de la voz (> 0,3 s). Termina con fundido suave.
    Devuelve (y, oido, parecido, fin, segundos_recortados)."""
    import numpy as np
    y = np.asarray(y, dtype='float32')
    largo = len(y)
    tramos = tramos_de_voz(y, sr)
    oido, parecido, fin = None, None, True
    if asr:
        oido = asr(y, sr)
        parecido, fin = coincidencia(texto, oido)
    if tramos:
        fin_voz = len(tramos)
        for _ in range(max_cortes):
            if fin_voz <= 1:
                break
            ultimo, previo = tramos[fin_voz - 1], tramos[fin_voz - 2]
            corte = min(largo, previo[1] + int(margen_fin * sr))
            if asr:
                oido_c = asr(y[:corte], sr)
                parecido_c, fin_c = coincidencia(texto, oido_c)
                if not (fin_c and parecido_c >= (parecido or 0) - 0.01):
                    break
                oido, parecido, fin = oido_c, parecido_c, fin_c
            else:
                corto = (ultimo[1] - ultimo[0]) / sr < 0.25
                separado = (ultimo[0] - previo[1]) / sr > 0.3
                if not (corto and separado):
                    break
            fin_voz -= 1
        ini = max(0, tramos[0][0] - int(margen_ini * sr))
        fin_m = min(largo, tramos[fin_voz - 1][1] + int(margen_fin * sr))
        y = y[ini:fin_m].copy()
        f_in, f_out = min(len(y), int(0.01 * sr)), min(len(y), int(0.06 * sr))
        if f_in:
            y[:f_in] *= np.linspace(0, 1, f_in, dtype='float32')
        if f_out:
            y[-f_out:] *= np.linspace(1, 0, f_out, dtype='float32')
    return y, oido, parecido, fin, round((largo - len(y)) / sr, 2)


def silenciar_pausas(y, sr, atenuacion_db=-35.0, sosten=0.08):
    """Baja SOLO los huecos entre palabras (donde se oye el soplido de fondo). El umbral se
    adapta a cada audio: 8 dB sobre su piso de ruido (percentil 10), entre −45 y −25 dB respecto
    a la voz fuerte. Lo que queda debajo se atenúa `atenuacion_db`, con 80 ms de margen alrededor
    de la voz (protege inicios y finales de palabra) y transiciones suaves."""
    import numpy as np
    y = np.asarray(y, dtype='float32')
    marco = max(1, int(0.01 * sr))
    n = len(y) // marco
    if n < 20:
        return y
    e = np.sqrt(np.mean(y[:n * marco].reshape(n, marco) ** 2, axis=1)) + 1e-9
    db = 20 * np.log10(e / np.percentile(e, 95))
    umbral_db = min(-25.0, max(float(np.percentile(db, 10)) + 8.0, -45.0))
    voz = db > umbral_db
    k = max(1, int(sosten / 0.01))
    voz = np.convolve(voz.astype(float), np.ones(2 * k + 1), mode='same') > 0  # margen a ambos lados
    g = np.where(voz, 1.0, 10 ** (atenuacion_db / 20))
    g = np.convolve(np.pad(g, 1, mode='edge'), np.ones(3) / 3, mode='valid')  # ~30 ms de transición
    ganancia = np.repeat(g, marco)
    ganancia = np.concatenate([ganancia, np.full(len(y) - len(ganancia), ganancia[-1])])
    return (y * ganancia).astype('float32')


def limpiar_ruido(y, sr, fuerza=0.9):
    """Quita zumbido grave y ruido de fondo (reducción espectral) sin tocar la voz."""
    try:
        import noisereduce as nr
        from scipy.signal import butter, sosfiltfilt
        y = sosfiltfilt(butter(4, 70, 'highpass', fs=sr, output='sos'), y).astype('float32')
        return nr.reduce_noise(y=y, sr=sr, stationary=True, prop_decrease=fuerza,
                               n_std_thresh_stationary=1.5).astype('float32')
    except Exception as e:  # noqa: BLE001
        if not _AVISOS.get('limpieza'):
            _AVISOS['limpieza'] = True
            print(f'  [aviso] limpieza de ruido omitida ({type(e).__name__}: {str(e)[:100]})', flush=True)
        return y


def _clonar(modelo, trabajos, ajustes, mostrar=True, asr=None, mos=None, realzar=None, limpiar=None,
            medir=None):
    """Lee cada [texto, ruta_wav] con la voz ya condicionada en `modelo`.

    Por frase genera varias tomas (al menos `tomas_min`, hasta `intentos`). Cada toma:
    recorte de lo que sobra al final (verificado con Whisper) → limpieza con DeepFilterNet →
    medición del fondo (DNSMOS) y de la naturalidad (UTMOS). Gana la que se entiende completa,
    con el fondo tan limpio como las vof (bak ≥ 4,0) y más natural; si ninguna llega, se
    siguen generando tomas. A la elegida se le prueba el realce de nitidez (Resemble Enhance)
    y SOLO se conserva si DNSMOS confirma que no empeoró (a veces inventa sonidos)."""
    import os
    import random
    import numpy as np
    import soundfile as sf
    import torch
    ritmo = ajustes.get('silabas_s', 5.5)
    max_tomas = max(1, int(ajustes.get('intentos', 6)))
    min_tomas = min(max_tomas, max(1, int(ajustes.get('tomas_min', 3))))
    exigir_fondo = float(ajustes.get('fondo_min', FONDO_LIMPIO))
    informe = []
    for n, (texto, ruta) in enumerate(trabajos):
        esperado = silabas_estimadas(texto) / ritmo
        mejor = None
        for toma in range(max_tomas):
            semilla = int(ajustes.get('semilla', 1234)) + 1000 * toma + n
            random.seed(semilla); np.random.seed(semilla); torch.manual_seed(semilla)
            wav = modelo.generate(texto, language_id='es',
                                  exaggeration=ajustes.get('exageracion', 0.5),
                                  cfg_weight=ajustes.get('cfg', 0.4),
                                  temperature=ajustes.get('temperatura', 0.7))
            y = wav.squeeze(0).detach().cpu().numpy().astype('float32')
            y, oido, parecido, fin, recorte = recortar_bordes(y, modelo.sr, texto, asr)
            sr = modelo.sr
            if limpiar:
                try:
                    y, sr = limpiar(y, sr)
                except Exception as e:  # noqa: BLE001
                    print(f'  [aviso] limpieza omitida en una toma ({type(e).__name__})', flush=True)
            razon = (len(y) / sr) / max(esperado, 0.3)
            snr = relacion_senal_ruido(y, sr)
            fondo = medir(y, sr) if medir else None
            natural = mos(y, sr) if mos else None
            nota = puntuar_toma(parecido if parecido is not None else 1.0, fin, razon, snr, natural, fondo)
            limpia = fondo is None or fondo['bak'] >= exigir_fondo
            completa = 0.6 <= razon <= 1.7 and (parecido is None or (parecido >= 0.92 and fin)) and limpia
            if mejor is None or nota > mejor['nota']:
                mejor = dict(y=y, sr=sr, nota=nota, razon=razon, parecido=parecido, fin=fin, oido=oido,
                             snr=snr, mos=natural, fondo=fondo, completa=completa, recorte=recorte)
            if toma + 1 >= min_tomas and mejor['completa']:
                break
        y, sr, fondo = mejor['y'], mejor['sr'], mejor['fondo']
        realce_usado = False
        if realzar:
            try:
                y2, sr2 = realzar(y, sr)
                fondo2 = medir(y2, sr2) if medir else None
                if fondo is None or fondo2 is None or (fondo2['bak'] >= fondo['bak'] - 0.05
                                                       and fondo2['ovr'] >= fondo['ovr'] - 0.05):
                    y, sr, fondo, realce_usado = y2, sr2, fondo2 or fondo, True
            except Exception as e:  # noqa: BLE001
                print(f'  [aviso] realce omitido en esta frase ({type(e).__name__})', flush=True)
        elif not limpiar and ajustes.get('limpiar_ruido', False) and mejor['snr'] < 30:
            y = limpiar_ruido(y, sr, 0.6)  # respaldo suave solo si no hay limpiador neuronal
        if ajustes.get('silenciar_pausas', True):
            y = silenciar_pausas(y, sr)
        y = recortar_bordes(y, sr, texto, None, max_cortes=0)[0]  # cierre limpio tras el realce
        final = medir(y, sr) if medir else None
        sf.write(ruta, y, sr)
        entendida = mejor['parecido'] is None or (mejor['parecido'] >= 0.85 and mejor['fin'])
        limpio = final is None or final['bak'] >= exigir_fondo - 0.1
        informe.append({'ruta': os.path.basename(ruta), 'texto': texto, 'oido': mejor['oido'],
                        'parecido': mejor['parecido'], 'fin': mejor['fin'], 'razon': round(mejor['razon'], 2),
                        'snr': round(mejor['snr'], 1), 'mos': None if mejor['mos'] is None else round(mejor['mos'], 2),
                        'fondo': None if final is None else {k: round(v, 2) for k, v in final.items()},
                        'realce': realce_usado, 'tomas': toma + 1, 'ok': entendida and limpio,
                        'cola_recortada_s': mejor['recorte']})
        if mostrar:
            nat = f" · naturalidad {mejor['mos']:.2f}/5" if mejor['mos'] is not None else ''
            fon = f" · fondo {final['bak']:.2f}/5" if final else ''
            marca = ''
            if not entendida:
                marca = f" ⚠ revisar (se oyó: «{(mejor['oido'] or '')[:70]}»)"
            elif not limpio:
                marca = ' ⚠ revisar (aún con algo de ruido)'
            print(f"  [{n + 1}/{len(trabajos)}] {texto[:55]} · {toma + 1} tomas{nat}{fon}{marca}", flush=True)
    return informe


def limpiar_referencia(ruta, limpiar=None):
    """Limpia la referencia (DeepFilterNet; respaldo: denoise de Resemble Enhance) — solo quita
    ruido, no cambia la voz — y la guarda al lado como *_limpia.wav. Si no se puede, la original.
    Importa porque el clon copia también el "ambiente" de la grabación de referencia."""
    import os
    destino = ruta[:-4] + '_limpia.wav'
    if os.path.exists(destino) and os.path.getmtime(destino) >= os.path.getmtime(ruta):
        return destino
    if limpiar:
        try:
            import librosa
            import soundfile as sf
            y, sr = librosa.load(ruta, sr=None, mono=True)
            y2, sr2 = limpiar(y, sr)
            sf.write(destino, y2, sr2)
            print('  referencia de la voz limpiada ✔ (DeepFilterNet)', flush=True)
            return destino
        except Exception as e:  # noqa: BLE001
            print(f'  [aviso] DeepFilterNet no limpió la referencia ({type(e).__name__}); se prueba otro', flush=True)
    try:
        import librosa
        import soundfile as sf
        import torch
        from resemble_enhance.enhancer.inference import denoise
        y, sr = librosa.load(ruta, sr=44100, mono=True)
        dev = 'cuda' if torch.cuda.is_available() else 'cpu'
        limpio, sr2 = denoise(torch.from_numpy(y).float(), sr, dev)
        sf.write(destino, limpio.detach().cpu().numpy(), int(sr2))
        print('  referencia de la voz limpiada ✔', flush=True)
        return destino
    except Exception as e:  # noqa: BLE001
        print(f'  [aviso] no se pudo limpiar la referencia ({type(e).__name__}); se usa la original', flush=True)
        return ruta


def clonar_lote(trabajos, referencia, ajustes):
    """Chatterbox Multilingual (MIT): clona la voz de `referencia` y lee cada [texto, ruta_wav]."""
    modelo = _modelo_clonacion()
    limpiar = _cargar_limpiador() if ajustes.get('limpieza_neuronal', True) else None
    if ajustes.get('limpiar_referencia', True):
        referencia = limpiar_referencia(referencia, limpiar)
    modelo.prepare_conditionals(referencia, exaggeration=ajustes.get('exageracion', 0.5))
    asr = _cargar_asr(ajustes.get('asr', 'openai/whisper-large-v3-turbo')) if ajustes.get('verificar', True) else None
    mos = _cargar_mos() if ajustes.get('naturalidad', True) else None
    realzar = _cargar_realce(ajustes.get('fuerza_realce', 0.9)) if ajustes.get('nitidez', True) else None
    medir = dnsmos if ajustes.get('medir_fondo', True) else None
    return _clonar(modelo, trabajos, ajustes, asr=asr, mos=mos, realzar=realzar, limpiar=limpiar, medir=medir)


def clonar_candidatas(frase, referencias, carpeta, ajustes):
    """Lee la misma frase con cada referencia candidata (modelo cargado una sola vez)."""
    import os
    os.makedirs(carpeta, exist_ok=True)
    modelo = _modelo_clonacion()
    salidas = []
    for i, ref in enumerate(referencias):
        modelo.prepare_conditionals(ref, exaggeration=ajustes.get('exageracion', 0.5))
        ruta = os.path.join(carpeta, f'cand_{i + 1:02d}.wav')
        _clonar(modelo, [[frase, ruta]], dict(ajustes, intentos=1, tomas_min=1), mostrar=False)
        print(f'  referencia {i + 1}/{len(referencias)} lista', flush=True)
        salidas.append(ruta)
    return salidas


if __name__ == '__main__':
    # En Colab lo que usa numpy/librosa/torch corre en un proceso aparte, dentro del entorno
    # aislado de Chatterbox: así nunca choca con el numpy del kernel ni con el torch de Applio.
    import sys
    _resultado = globals()[sys.argv[1]](*json.loads(sys.argv[2]))
    print('@@RESULTADO@@' + json.dumps(_resultado))
