"""Pruebas del motor del Estudio de voz: python3 tools/rvc/test_estudio_voz_lib.py

La parte de texto no necesita nada. La de audio corre solo si hay ffmpeg,
numpy y soundfile (la voz clonada y RVC se reemplazan por dobles de prueba).
"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import estudio_voz_lib as L  # noqa: E402


def test_parse_textos():
    pares = L.parse_textos("""
        # comentario
        bienvenida | Bienvenido a COSSMIL.
        Recuerde: lleve su carnet | y su cédula.
        Otra línea sin nombre, con tildes: ¡Atención!

        bienvenida | Repetido.
        [pausa]
        mal id con espacios | se queda entero
    """)
    assert pares[0] == ('bienvenida', 'Bienvenido a COSSMIL.')
    # "Recuerde: lleve…" no es un id válido → la línea entera es texto
    assert pares[1] == ('clip_01_recuerde-lleve-su-carnet', 'Recuerde: lleve su carnet | y su cédula.')
    assert pares[2][0] == 'clip_02_otra-linea-sin-nombre'
    assert pares[3] == ('bienvenida_2', 'Repetido.')
    assert pares[4][1] == 'mal id con espacios | se queda entero'
    assert len(pares) == 5  # la línea que solo tiene [pausa] se ignora


def test_parse_archivo():
    assert L.parse_archivo('g.json', '{"lines": {"ficha_00": "Hola"}}') == [('ficha_00', 'Hola')]
    assert L.parse_archivo('g.json', b'[{"id": "a.mp3", "texto": "Uno"}, "Dos"]') == [('a', 'Uno'), ('clip_01_dos', 'Dos')]
    assert L.parse_archivo('g.csv', 'id,texto\nx,"Hola, mundo"\n,\nSolo texto\n') == [('x', 'Hola, mundo'), ('clip_01_solo-texto', 'Solo texto')]
    assert L.parse_archivo('g.txt', 'a | Uno\nDos') == [('a', 'Uno'), ('clip_01_dos', 'Dos')]


def test_pronunciacion():
    d = L.PRONUNCIACION_DEFECTO
    assert L.aplicar_pronunciacion('Bienvenido a COSSMIL, con la Dra. Pérez y el Dr. Ruiz.', d) == \
        'Bienvenido a Cossmil, con la doctora Pérez y el doctor Ruiz.'
    assert L.aplicar_pronunciacion('COSSMILES y Drama', d) == 'COSSMILES y Drama'  # límite de palabra


def test_segmentar_pausas():
    s = L.segmentar('Hola. [pausa] Siga. [pausa 1,5] Fin. [PAUSA 800ms] Ya. [pausa]')
    assert s == [('habla', 'Hola.'), ('silencio', 0.6), ('habla', 'Siga.'), ('silencio', 1.5),
                 ('habla', 'Fin.'), ('silencio', 0.8), ('habla', 'Ya.')]
    assert L.segmentar('[pausa 2] Hola') == [('habla', 'Hola')]


def test_segmentar_texto_largo():
    frase = 'Esta es una oración de prueba bastante normal. '
    texto = frase * 30  # ~1400 caracteres
    s = L.segmentar(texto, max_car=200)
    habla = [v for t, v in s if t == 'habla']
    assert all(len(h) <= 200 for h in habla)
    assert ' '.join(habla) == texto.strip()
    assert all(t == 'silencio' for t, _ in s[1::2])
    sin_puntos = 'palabra ' * 100
    assert all(len(v) <= 120 for t, v in L.segmentar(sin_puntos, max_car=120) if t == 'habla')


def test_slug_y_nombre():
    assert L.slug('¡Hola, señor Pérez! ¿Cómo está?') == 'hola-senor-perez-como'
    assert L.slug('¿?') == 'audio'
    assert L.nombre_seguro('Guiado Intro.mp3') == 'Guiado_Intro'


def test_generar_extremo_a_extremo():
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        print('  (omitido: falta numpy/soundfile)')
        return
    if not shutil.which('ffmpeg'):
        print('  (omitido: falta ffmpeg)')
        return
    llamadas = []

    def sintetizar(texto, ruta, voz, vel, tono):
        llamadas.append(texto)
        t = np.linspace(0, 0.5, 22050, endpoint=False)
        sf.write(ruta, (0.3 * np.sin(2 * np.pi * 220 * t)).astype('float32'), 44100)

    def convertir(entrada, salida):  # RVC de mentira: remuestrea a 40 kHz como el modelo
        for f in os.listdir(entrada):
            a, _ = sf.read(os.path.join(entrada, f), dtype='float32')
            x = np.linspace(0, len(a), int(len(a) * 40000 / 44100), endpoint=False)
            sf.write(os.path.join(salida, f), np.interp(x, np.arange(len(a)), a).astype('float32'), 40000)

    with tempfile.TemporaryDirectory() as tmp:
        out = L.generar([('uno', 'Hola COSSMIL. [pausa 1] Adiós.'), ('dos', 'Solo esto.')],
                        'es-BO-SofiaNeural', tmp, convertir, sintetizar=sintetizar, log=lambda *_: None)
        assert set(out) == {'uno', 'dos'} and all(p.endswith('.mp3') and os.path.getsize(p) > 1000 for p in out.values())
        assert llamadas == ['Hola Cossmil.', 'Adiós.', 'Solo esto.']
        lotes = []

        def lote(trabajos):
            lotes.append([t for t, _ in trabajos])
            for texto, ruta in trabajos:
                sintetizar(texto, ruta, None, 0, 0)
        out = L.generar([('c', 'Son las 8:30. [pausa] 1 médico.')], None, tmp, None,
                        sintetizar_lote=lote, log=lambda *_: None)
        assert lotes == [['Son las ocho y treinta.', 'un médico.']] and os.path.getsize(out['c']) > 1000
        wav = L.generar([('w', 'x [pausa 1] y')], 'v', tmp, convertir, sintetizar=sintetizar,
                        formato='wav', log=lambda *_: None)['w']
        a, sr = sf.read(wav)
        # 0,5 s + 1 s + 0,5 s + 0,25 s de cola (silencio de borde recortado solo en los extremos)
        assert sr == 44100 and 2.1 < len(a) / sr < 2.4, len(a) / sr


def _voz_sintetica(ruta, f0, silabas_s, seg=6.0, sr=16000):
    """Tono con vibrato y 'sílabas' (pulsos de energía) a ritmo conocido."""
    import numpy as np
    import soundfile as sf
    t = np.arange(int(seg * sr)) / sr
    fase = 2 * np.pi * np.cumsum(f0 * (1 + 0.08 * np.sin(2 * np.pi * 0.7 * t))) / sr
    voz = sum(np.sin(k * fase) / k for k in range(1, 6))
    env = np.sin(np.pi * silabas_s * t) ** 2  # un pulso por sílaba
    sf.write(ruta, (0.2 * voz * env).astype('float32'), sr)


def test_analizar_voz():
    try:
        import librosa  # noqa: F401
    except ImportError:
        print('  (omitido: falta librosa)')
        return
    with tempfile.TemporaryDirectory() as tmp:
        ref_p, base_p = os.path.join(tmp, 'ref.wav'), os.path.join(tmp, 'base.wav')
        _voz_sintetica(ref_p, 218, 6.0)
        _voz_sintetica(base_p, 190, 4.5)
        ref, base = L.analizar_voz(ref_p), L.analizar_voz(base_p)
        assert abs(ref['f0'] - 218) < 8 and abs(base['f0'] - 190) < 8, (ref, base)
        assert abs(ref['silabas_s'] - 6.0) < 0.8 and abs(base['silabas_s'] - 4.5) < 0.8, (ref, base)
        assert L.distancia_rasgos(ref, ref) == 0
        assert L.distancia_rasgos(ref, base) > L.distancia_rasgos(ref, dict(base, f0=ref['f0']))
        if shutil.which('ffmpeg'):
            assert -40 < L.medir_lufs(ref_p) < -5


def test_numeros_a_palabras():
    f = L.numeros_a_palabras
    assert f('Llegue a la 1:00 o a las 14:05.') == 'Llegue a la una o a las catorce y cinco.'
    assert f('Tiene 21 fichas y 1.500 afiliados; 15% más.') == \
        'Tiene veintiún fichas y mil quinientos afiliados; quince por ciento más.'
    assert f('1 médico, 31 días, 71. Año 2026') == 'un médico, treinta y un días, setenta y uno. Año dos mil veintiséis'
    assert f('Carnet 4567891 y 100') == 'Carnet 4567891 y cien'
    assert f('versión 2.5 y A12') == 'versión 2.5 y A12'
    assert f('Hola. [pausa 1.5] 2 veces') == 'Hola. [pausa 1.5] dos veces'
    assert L._cardinal(999999) == 'novecientos noventa y nueve mil novecientos noventa y nueve'
    assert L._cardinal(21000) == 'veintiún mil' and L._cardinal(31000000) == 'treinta y un millones'


def test_verificacion_de_tomas():
    txt = 'Seleccione el horario de su preferencia dentro del día elegido.'
    assert L.coincidencia(txt, 'Seleccione el horario de su preferencia dentro del día elegido.') == (1.0, True)
    p, fin = L.coincidencia(txt, 'Seleccione el horario de su preferencia dentro')   # cortado
    assert not fin and p < 0.92
    p, fin = L.coincidencia(txt, 'Seleccione el horario de su preferencia dentro del día elegido. Eh eh mm ah ja')
    assert p < 0.92                                                                   # balbuceo al final
    assert L.coincidencia('Bienvenido a Cossmil a las ocho y treinta.', 'Bienvenido a Cosmil a las 8:30.') == (1.0, True)
    buena = L.puntuar_toma(1.0, True, 1.0, 50)
    assert buena > L.puntuar_toma(0.8, False, 1.0, 50) and buena > L.puntuar_toma(1.0, True, 2.5, 50)
    assert buena > L.puntuar_toma(1.0, True, 1.0, 20)
    assert L.cerrar_frase('Hola, cómo está') == 'Hola, cómo está.' and L.cerrar_frase('¿Listo?') == '¿Listo?'
    assert L.cerrar_frase('Elija:') == 'Elija.'


def test_limpieza_y_snr():
    try:
        import numpy as np
    except ImportError:
        return
    sr = 24000
    t = np.arange(sr * 2) / sr
    voz = (0.3 * np.sin(2 * np.pi * 220 * t) * (t % 0.5 < 0.3)).astype('float32')
    ruido = (0.01 * np.random.default_rng(0).standard_normal(len(t))).astype('float32')
    assert L.relacion_senal_ruido(voz + ruido, sr) < L.relacion_senal_ruido(voz + ruido / 10, sr)
    try:
        import noisereduce  # noqa: F401
    except ImportError:
        print('  (limpieza omitida: falta noisereduce)')
        return
    limpio = L.limpiar_ruido(voz + ruido, sr)
    assert L.relacion_senal_ruido(limpio, sr) > L.relacion_senal_ruido(voz + ruido, sr) + 6


def test_seleccion_de_tomas():
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        return
    import types
    if 'torch' not in sys.modules:  # la lógica de tomas no necesita torch real
        sys.modules['torch'] = types.SimpleNamespace(manual_seed=lambda s: None)

    class Onda:
        def __init__(self, y): self.y = y
        def squeeze(self, i): return self
        def detach(self): return self
        def cpu(self): return self
        def numpy(self): return self.y

    class Modelo:
        sr = 24000
        def __init__(self): self.n = 0
        def generate(self, texto, **k):
            self.n += 1
            return Onda(np.full(int(self.sr * 2.0), 0.1 * self.n, dtype='float32'))  # toma n = amplitud n

    frase = 'Ahora, elija el horario que prefiera.'
    oidos = {1: 'Ahora, elija el horario', 2: frase, 3: frase, 4: frase, 5: frase}  # la toma 1 sale cortada
    asr = lambda y, sr: oidos[round(float(y[len(y) // 2]) * 10)]
    mos = lambda y, sr: {1: 4.5, 2: 3.2, 3: 4.1, 4: 3.9, 5: 3.0}[round(float(y[len(y) // 2]) * 10)]
    realzar = lambda y, sr: (np.repeat(y, 2), sr * 2)
    with tempfile.TemporaryDirectory() as tmp:
        ruta = os.path.join(tmp, 'x.wav')
        inf = L._clonar(Modelo(), [[frase, ruta]], {'silabas_s': 5.5, 'intentos': 5, 'tomas_min': 3},
                        mostrar=False, asr=asr, mos=mos, realzar=realzar)[0]
        y, sr = sf.read(ruta)
        assert inf['tomas'] == 3 and inf['ok'] and inf['mos'] == 4.1, inf  # la 1 (cortada) pierde pese a su MOS
        assert sr == 48000 and abs(y[len(y) // 2] - 0.3) < 1e-3                       # se guardó la toma 3, realzada
        inf = L._clonar(Modelo(), [[frase, ruta]], {'silabas_s': 5.5, 'intentos': 2, 'tomas_min': 3},
                        mostrar=False, asr=lambda y, sr: 'Ahora elija', mos=None)[0]
        assert inf['tomas'] == 2 and not inf['ok']                           # sin toma buena: se marca ⚠


def _voz_con_pausas(sr=24000, seg=3.0, ruido=0.003):
    import numpy as np
    t = np.arange(int(sr * seg)) / sr
    habla = (t % 1.0) < 0.6                                   # 0,6 s de voz, 0,4 s de pausa
    voz = 0.3 * np.sin(2 * np.pi * 220 * t) * habla
    return (voz + ruido * np.random.default_rng(1).standard_normal(len(t))).astype('float32'), habla


def test_silenciar_pausas():
    try:
        import numpy as np
    except ImportError:
        return
    sr = 24000
    y, habla = _voz_con_pausas(sr)
    z = L.silenciar_pausas(y, sr)
    pausa = ~habla
    pausa[:int(0.1 * sr)] = False  # lejos de los márgenes de 80 ms
    centro_pausa = np.zeros_like(pausa)
    for i in range(3):
        centro_pausa[int((i + 0.7) * sr):int((i + 0.9) * sr)] = True
    centro_voz = np.zeros_like(pausa)
    for i in range(3):
        centro_voz[int((i + 0.1) * sr):int((i + 0.5) * sr)] = True
    rms = lambda a: float(np.sqrt(np.mean(a ** 2)))
    assert rms(z[centro_pausa]) < rms(y[centro_pausa]) / 20        # soplido de la pausa: −26 dB o más
    assert abs(rms(z[centro_voz]) / rms(y[centro_voz]) - 1) < 0.01  # la voz queda intacta


def test_masterizar_no_sube_el_ruido_de_las_pausas():
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        return
    if not shutil.which('ffmpeg'):
        return
    sr = 24000
    y, habla = _voz_con_pausas(sr, ruido=0.002)
    y *= 0.2  # voz baja: el masterizado debe subir TODO por igual, no solo las pausas
    with tempfile.TemporaryDirectory() as tmp:
        ent, sal = os.path.join(tmp, 'e.wav'), os.path.join(tmp, 's.wav')
        sf.write(ent, y, sr)
        L.masterizar(ent, sal, formato='wav', cola=0.0, lufs=-16)
        z, sr2 = sf.read(sal)
        assert abs(L.medir_lufs(sal) + 16) < 1.5
        relacion = lambda a, s: (np.percentile(np.abs(a), 99.5) / np.sqrt(np.mean(a[s] ** 2)))
        pausa_e = np.zeros(len(y), bool)
        pausa_s = np.zeros(len(z), bool)
        for i in range(2):
            pausa_e[int((i + 0.7) * sr):int((i + 0.9) * sr)] = True
        rel_e = relacion(y, pausa_e)
        # tras recortar bordes el audio se desplaza un poco: busca la zona más silenciosa comparable
        marco = int(0.2 * sr2)
        rms = [np.sqrt(np.mean(z[i:i + marco] ** 2)) for i in range(0, len(z) - marco, marco // 4)]
        rel_s = np.percentile(np.abs(z), 99.5) / min(rms)
        assert rel_s > 0.7 * rel_e, (rel_s, rel_e)  # la distancia voz/ruido no se achica


def test_recortar_sonidos_al_final():
    try:
        import numpy as np
    except ImportError:
        return
    sr = 24000
    t = np.arange(sr * 3) / sr
    voz = 0.3 * np.sin(2 * np.pi * 220 * t)
    y = np.zeros(len(t), 'float32')
    y[int(0.2 * sr):int(1.0 * sr)] = voz[int(0.2 * sr):int(1.0 * sr)]    # "Ahora, elija"
    y[int(1.1 * sr):int(1.9 * sr)] = voz[int(1.1 * sr):int(1.9 * sr)]    # "el horario."
    y[int(2.3 * sr):int(2.5 * sr)] = 0.2 * voz[int(2.3 * sr):int(2.5 * sr)]  # sonido extraño al final
    texto = 'Ahora, elija el horario.'

    def asr(a, sr_):
        dur = len(a) / sr_
        return texto if dur < 2.2 else texto + ' ah'   # el murmullo final se "oye" como una palabra más
    z, oido, parecido, fin, cortado = L.recortar_bordes(y, sr, texto, asr)
    assert oido == texto and parecido == 1.0 and fin
    assert 1.9 < 0.12 + len(z) / sr < 2.2 and cortado > 0.8, (len(z) / sr, cortado)  # sin cola extraña
    # si el último tramo ES parte del texto, no se toca
    asr2 = lambda a, sr_: texto if len(a) / sr_ > 2.2 else 'Ahora, elija el'
    z2 = L.recortar_bordes(y, sr, texto, asr2)[0]
    assert len(z2) / sr > 2.3
    # sin Whisper: se quita un chasquido corto y separado, pero no una palabra larga
    z3 = L.recortar_bordes(y, sr, texto, None)[0]
    assert len(z3) / sr < 2.0
    assert abs(float(z[0])) < 1e-6 and abs(float(z[-1])) < 1e-3  # entra y sale en silencio (fundidos)


def test_elige_la_toma_sin_ruido_y_descarta_realce_que_empeora():
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        return
    import types
    if 'torch' not in sys.modules:
        sys.modules['torch'] = types.SimpleNamespace(manual_seed=lambda s: None)

    class Onda:
        def __init__(self, y): self.y = y
        def squeeze(self, i): return self
        def detach(self): return self
        def cpu(self): return self
        def numpy(self): return self.y

    class Modelo:
        sr = 24000
        def __init__(self): self.n = 0
        def generate(self, texto, **k):
            self.n += 1
            return Onda(np.full(int(self.sr * 2.0), 0.1 * self.n, dtype='float32'))

    toma = lambda y: round(float(y[len(y) // 2]) * 10)
    frase = 'Ahora, elija el horario de su preferencia.'
    asr = lambda y, sr: frase
    # tomas 1-3 con ruido de fondo (bak 3,0–3,5); la 4 limpia (4,2)
    fondo_por_toma = {1: 3.0, 2: 3.5, 3: 3.2, 4: 4.2, 5: 4.3, 6: 4.1}
    medir = lambda y, sr: {'sig': 3.6, 'bak': fondo_por_toma.get(toma(y), 4.2), 'ovr': 3.4}
    limpiar = lambda y, sr: (y, sr)
    with tempfile.TemporaryDirectory() as tmp:
        ruta = os.path.join(tmp, 'x.wav')
        # realce que ENSUCIA (bak baja a 3,0): debe descartarse
        realce_malo = lambda y, sr: (y * 1.0 + 0.0 * y, 48000)
        medir_malo = lambda y, sr: ({'sig': 3.6, 'bak': 3.0, 'ovr': 3.0} if sr == 48000 else medir(y, sr))
        inf = L._clonar(Modelo(), [[frase, ruta]], {'intentos': 6, 'tomas_min': 3},
                        mostrar=False, asr=asr, limpiar=limpiar, realzar=realce_malo, medir=medir_malo)[0]
        y, sr = sf.read(ruta)
        assert inf['tomas'] == 4 and inf['ok'] and not inf['realce'], inf   # siguió hasta la toma limpia
        assert sr == 24000 and abs(y[len(y) // 2] - 0.4) < 1e-3               # guardó la 4, sin realce
        # realce que NO empeora: se conserva
        realce_bueno = lambda y, sr: (np.repeat(y, 2), 48000)
        inf = L._clonar(Modelo(), [[frase, ruta]], {'intentos': 6, 'tomas_min': 3},
                        mostrar=False, asr=asr, limpiar=limpiar, realzar=realce_bueno, medir=medir)[0]
        assert inf['realce'] and sf.read(ruta)[1] == 48000
        # si ninguna toma queda limpia, se marca para revisar
        inf = L._clonar(Modelo(), [[frase, ruta]], {'intentos': 3, 'tomas_min': 3},
                        mostrar=False, asr=asr, limpiar=limpiar, medir=lambda y, sr: {'sig': 3, 'bak': 3.1, 'ovr': 2.9})[0]
        assert not inf['ok'] and inf['tomas'] == 3


def test_dnsmos_distingue_ruido():
    try:
        import numpy as np
        import onnxruntime  # noqa: F401
        import librosa
    except ImportError:
        print('  (omitido: falta onnxruntime/librosa)')
        return
    y, sr = librosa.load(sorted(__import__('glob').glob(os.path.join(os.path.dirname(__file__),
                                                                       '../../assets/vof/*.mp3')))[1], sr=16000)
    limpio = L.dnsmos(y, sr)
    if limpio is None:
        print('  (omitido: no se pudo descargar el modelo DNSMOS)')
        return
    sucio = L.dnsmos(y + 0.01 * np.random.default_rng(0).standard_normal(len(y)).astype('float32'), sr)
    assert limpio['bak'] >= L.FONDO_LIMPIO and sucio['bak'] < 3.0, (limpio, sucio)


def test_igualar_timbre():
    try:
        import numpy as np
        import librosa
        from scipy.signal import fftconvolve, firwin2
    except ImportError:
        return
    import glob as _g
    vofs = sorted(_g.glob(os.path.join(os.path.dirname(__file__), '../../assets/vof/*.mp3')))
    if len(vofs) < 6:
        return
    sr = 24000
    perfil = L.perfil_timbre(np.concatenate([librosa.load(f, sr=sr)[0] for f in vofs[:4]]), sr)
    y = librosa.load(vofs[4], sr=sr)[0]
    assert L.igualar_timbre(y, sr, perfil) is y                      # ya se parece: no se toca
    f = firwin2(1025, [0, 1500, 4000, 12000], [1, 1, 10 ** (-8 / 20), 10 ** (-8 / 20)], fs=sr)
    apagada = fftconvolve(y, f, mode='same').astype('float32')       # agudos -8 dB
    z = L.igualar_timbre(apagada, sr, perfil)
    antes = L.distancia_timbre(perfil, L.perfil_timbre(apagada, sr))
    despues = L.distancia_timbre(perfil, L.perfil_timbre(z, sr))
    assert despues < antes - 0.8, (antes, despues)                    # recupera el color
    rms = lambda a: 20 * np.log10(np.sqrt(np.mean(a ** 2)))
    assert abs(rms(z) - rms(apagada)) < 1.5                           # sin cambiar mucho el volumen
    # la misma locutora pesa en la nota
    assert L.puntuar_toma(1.0, True, 1.0, voz=0.92) > L.puntuar_toma(1.0, True, 1.0, voz=0.80)


if __name__ == '__main__':
    for nombre, f in list(globals().items()):
        if nombre.startswith('test_'):
            f()
            print('ok', nombre)
