#!/usr/bin/env python3
"""Genera la familia de sonidos de interfaz de COSSMIL.

Sintetizador propio (sin dependencias ni descargas). El lenguaje sonoro es
deliberadamente CLÍNICO, no lúdico. Cuatro decisiones lo definen, y conviene
respetarlas al añadir sonidos nuevos:

1. **Timbre armónico, no metálico.** Los parciales son múltiplos exactos
   (×2, ×3) y muy discretos. Los parciales inarmónicos (×2.01, ×3.02) suenan a
   campanita de videojuego; estos suenan a tono de instrumento médico.
2. **Registro medio-grave (330–880 Hz).** Cerca de la voz humana. Lo agudo se
   lee como juguete; esta zona se lee como equipo profesional.
3. **Sin percusión.** Ataques de 8 a 30 ms, nunca golpes de 2 ms ni ráfagas de
   ruido. El sonido "entra", no "golpea".
4. **Intervalos, no melodías.** Como mucho dos notas (cuarta, quinta o tercera).
   Un arpegio de cuatro notas es una fanfarria de recompensa, y esto es una app
   de salud: informa, no premia.

Salida en assets/sounds/, mono 44.1 kHz. Los sonidos cortos de interacción
quedan en WAV (sin retardo de decodificador: es donde se nota la latencia) y
los largos se codifican a MP3 con ffmpeg. Uso:

    python3 tools/generate_ui_sounds.py

Los niveles de cada sonido son RELATIVOS entre sí: la familia ya sale
balanceada, así un único `volume` en Dart la escala entera por igual.
"""

import math
import os
import struct
import subprocess
import wave

SR = 44100
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sounds"
)

# Sonidos que se entregan en MP3 (los que duran lo suficiente para que el
# ahorro de tamaño supere al retardo de decodificación).
AS_MP3 = {
    "ui_sheet", "ui_coach", "ui_advance", "ui_success", "ui_error", "ui_alert",
    "ui_welcome",
}

# ── Notas (Hz) — registro medio-grave, tonalidad de Re ──────────────────────
D4, E4, F4, Fs4, G4, A4, B4, C5, Cs5, D5, E5, Fs5, G5, A5 = (
    293.66, 329.63, 349.23, 369.99, 392.00, 440.00, 493.88, 523.25, 554.37,
    587.33, 659.25, 739.99, 783.99, 880.00,
)


def bell(buf, start, freq, dur, amp, tau, attack=0.012, partials=None, glide=0.0):
    """Suma una voz al buffer, empezando en `start` segundos.

    partials: [(razón de frecuencia, amplitud relativa)]. Por defecto, octava y
    duodécima muy discretas sobre la fundamental: da cuerpo al tono sin el
    tintineo metálico de los parciales inarmónicos.
    """
    if partials is None:
        partials = [(1.0, 1.0), (2.0, 0.16), (3.0, 0.05)]
    i0 = int(start * SR)
    n = int(dur * SR)
    phases = [0.0] * len(partials)
    for i in range(n):
        t = i / SR
        # Ataque en coseno elevado: sin clic de arranque.
        a = 1.0 if attack <= 0 else min(1.0, t / attack)
        a = 0.5 - 0.5 * math.cos(math.pi * a)
        e = a * math.exp(-t / tau)
        # El corte por silencio solo aplica pasado el ataque: al arrancar la
        # envolvente vale 0 y cortaría la voz entera en la primera muestra.
        if t > attack and e < 1e-5:
            break
        f = freq * (1.0 + glide * (t / dur))
        s = 0.0
        for p, (ratio, pamp) in enumerate(partials):
            phases[p] += 2 * math.pi * f * ratio / SR
            s += pamp * math.sin(phases[p])
        idx = i0 + i
        if 0 <= idx < len(buf):
            buf[idx] += amp * e * s


def render(dur, voices, level, fade=0.006):
    """Mezcla, normaliza a pico 1, aplica el nivel de familia y un fundido."""
    buf = [0.0] * int(dur * SR)
    for v in voices:
        v(buf)
    peak = max(abs(x) for x in buf) or 1.0
    g = level / peak
    nf = int(fade * SR)
    out = []
    for i, x in enumerate(buf):
        y = x * g
        # Fundido final: garantiza cruce por cero al terminar (sin chasquido).
        if i >= len(buf) - nf:
            y *= (len(buf) - i) / nf
        # Saturación suave: nunca recorta duro aunque se sumen parciales.
        y = math.tanh(y * 1.2) / math.tanh(1.2)
        out.append(y)
    return out


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        ))
    return path


# ── La familia ──────────────────────────────────────────────────────────────
# Los niveles son RELATIVOS entre sí: la mezcla queda balanceada dentro del
# archivo, así un único `volume` en Dart escala todo el sistema por igual.

SOUNDS = {}

# Tap: el toque genérico de un botón. Casi subliminal — sostiene el háptico.
# Toque de un botón. Tono grave y MATE: sin octava ni duodécima, solo la
# fundamental. Es lo que separa el "pulso" de un panel clínico del "blip" de un
# juego — los armónicos superiores son los que suenan a juguete. Con la
# fundamental sola queda un golpe sordo, breve, que confirma sin cantar.
SOUNDS["ui_tap"] = lambda: render(0.085, [
    lambda b: bell(b, 0.0, G4, 0.085, 0.70, 0.020, attack=0.009,
                   partials=[(1.0, 1.0)]),
], level=0.17)

# Cambio de pestaña: mismo pulso mate, una cuarta más arriba para que se
# distinga del toque sin cambiar de familia.
SOUNDS["ui_nav"] = lambda: render(0.130, [
    lambda b: bell(b, 0.0, C5, 0.130, 0.70, 0.032, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.07)]),
], level=0.21)

# Avanzar en un flujo: cuarta ascendente. Dice "seguimos" sin celebrar nada.
SOUNDS["ui_select"] = lambda: render(0.230, [
    lambda b: bell(b, 0.000, A4, 0.110, 0.62, 0.036, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.08)]),
    lambda b: bell(b, 0.060, D5, 0.170, 0.70, 0.046, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.08)]),
], level=0.27)

# Volver atrás: la misma cuarta, descendente y algo más apagada.
SOUNDS["ui_back"] = lambda: render(0.230, [
    lambda b: bell(b, 0.000, D5, 0.105, 0.60, 0.032, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.08)]),
    lambda b: bell(b, 0.058, A4, 0.172, 0.68, 0.044, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.08)]),
], level=0.24)

# Interruptores: quinta corta, en un sentido y en el otro.
SOUNDS["ui_toggle_on"] = lambda: render(0.190, [
    lambda b: bell(b, 0.000, A4, 0.085, 0.55, 0.028, attack=0.007),
    lambda b: bell(b, 0.048, E5, 0.142, 0.62, 0.040, attack=0.007),
], level=0.26)

SOUNDS["ui_toggle_off"] = lambda: render(0.190, [
    lambda b: bell(b, 0.000, E5, 0.085, 0.55, 0.028, attack=0.007),
    lambda b: bell(b, 0.048, A4, 0.142, 0.60, 0.040, attack=0.007),
], level=0.25)

# Apertura de diálogo: un tono que entra despacio, casi un fundido. Sin ataque
# audible — la hoja aparece, no golpea.
SOUNDS["ui_sheet"] = lambda: render(0.300, [
    lambda b: bell(b, 0.0, D5, 0.300, 0.70, 0.090, attack=0.030),
    lambda b: bell(b, 0.0, D4, 0.300, 0.28, 0.080, attack=0.030),
], level=0.22)

# La instructora aparece: tercera mayor ascendente, cordial y breve. Es lo más
# "cálido" que se permite la familia, sin llegar a ser juguetón.
SOUNDS["ui_coach"] = lambda: render(0.320, [
    lambda b: bell(b, 0.000, D5, 0.150, 0.60, 0.050, attack=0.010),
    lambda b: bell(b, 0.070, Fs5, 0.245, 0.66, 0.070, attack=0.010),
], level=0.34)

# Avance de paso del tutorial: quinta ascendente, hermana de ui_select pero
# distinguible.
SOUNDS["ui_advance"] = lambda: render(0.330, [
    lambda b: bell(b, 0.000, A4, 0.140, 0.60, 0.048, attack=0.009),
    lambda b: bell(b, 0.075, E5, 0.250, 0.66, 0.072, attack=0.009),
], level=0.34)

# Éxito: quinta ascendente sostenida sobre su fundamental grave. Confirma con
# aplomo; deliberadamente NO es un arpegio ascendente de premio.
SOUNDS["ui_success"] = lambda: render(0.750, [
    lambda b: bell(b, 0.000, D4, 0.620, 0.30, 0.230, attack=0.014),
    lambda b: bell(b, 0.000, D5, 0.300, 0.62, 0.105, attack=0.014),
    lambda b: bell(b, 0.130, A5, 0.610, 0.60, 0.215, attack=0.016),
], level=0.52)

# Bienvenida: acorde de Re que se abre despacio y se sostiene. Sin ataque, sin
# brillo agudo, sin melodía — la firma institucional de "el sistema está listo".
SOUNDS["ui_welcome"] = lambda: render(1.400, [
    lambda b: bell(b, 0.000, D4, 1.150, 0.34, 0.480, attack=0.060),
    lambda b: bell(b, 0.090, A4, 1.060, 0.42, 0.430, attack=0.055),
    lambda b: bell(b, 0.190, D5, 0.980, 0.52, 0.400, attack=0.050),
    lambda b: bell(b, 0.320, Fs5, 0.860, 0.30, 0.330, attack=0.060),
], level=0.50)

# Error: tercera descendente, grave y mate. Señala el problema sin regañar.
SOUNDS["ui_error"] = lambda: render(0.480, [
    lambda b: bell(b, 0.000, A4, 0.190, 0.66, 0.062, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.10)]),
    lambda b: bell(b, 0.105, F4, 0.375, 0.72, 0.120, attack=0.010,
                   partials=[(1.0, 1.0), (2.0, 0.08)]),
], level=0.44)

# Alerta: tres pulsos iguales sobre la misma nota. Es la gramática de los
# equipos médicos para "atención de prioridad media": repetición, no estridencia.
SOUNDS["ui_alert"] = lambda: render(0.620, [
    lambda b: bell(b, 0.000, D5, 0.150, 0.70, 0.042, attack=0.009,
                   partials=[(1.0, 1.0), (2.0, 0.10)]),
    lambda b: bell(b, 0.165, D5, 0.150, 0.66, 0.042, attack=0.009,
                   partials=[(1.0, 1.0), (2.0, 0.10)]),
    lambda b: bell(b, 0.330, D5, 0.280, 0.70, 0.090, attack=0.009,
                   partials=[(1.0, 1.0), (2.0, 0.10)]),
], level=0.46)



def to_mp3(wav_path):
    mp3_path = wav_path[:-4] + ".mp3"
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav_path,
         "-codec:a", "libmp3lame", "-q:a", "4", "-ac", "1", "-ar", str(SR),
         mp3_path],
        check=True,
    )
    os.remove(wav_path)
    return mp3_path


if __name__ == "__main__":
    total = 0
    for name, make in SOUNDS.items():
        p = write_wav(name, make())
        if name in AS_MP3:
            p = to_mp3(p)
        size = os.path.getsize(p)
        total += size
        print(f"{os.path.basename(p):20s} {size/1024:6.1f} KB")
    print(f"{'TOTAL':20s} {total/1024:6.1f} KB")
