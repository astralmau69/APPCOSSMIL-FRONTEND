"""Pruebas del motor del Estudio de voz: python3 tools/rvc/test_estudio_voz_lib.py

La parte de texto no necesita nada. La de audio corre solo si hay ffmpeg,
numpy y soundfile (edge-tts y RVC se reemplazan por dobles de prueba).
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
        wav = L.generar([('w', 'x [pausa 1] y')], 'v', tmp, convertir, sintetizar=sintetizar,
                        formato='wav', log=lambda *_: None)['w']
        a, sr = sf.read(wav)
        # 0,5 s + 1 s + 0,5 s + 0,25 s de cola (silencio de borde recortado solo en los extremos)
        assert sr == 44100 and 2.1 < len(a) / sr < 2.4, len(a) / sr


if __name__ == '__main__':
    for nombre, f in list(globals().items()):
        if nombre.startswith('test_'):
            f()
            print('ok', nombre)
