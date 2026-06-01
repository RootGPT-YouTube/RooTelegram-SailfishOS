#!/usr/bin/env python3
# Genera i toni telefonici per le chiamate vocali uscenti di RooTelegram.
# Standard europeo/italiano: tono a 425 Hz.
#   ringback.wav ("libero")  -> 1.0s acceso / 4.0s spento, riprodotto in loop
#                               mentre l'altro telefono squilla.
#   callbusy.wav ("occupato/irraggiungibile") -> 0.2s acceso / 0.2s spento,
#                               cadenza rapida, riprodotto una volta a fine
#                               chiamata non andata a buon fine.
# PCM 16-bit mono 8000 Hz (telefonia): file piccoli, 425 Hz ben sotto Nyquist.
import math
import os
import struct
import wave

SAMPLE_RATE = 8000
FREQ = 425.0
AMPLITUDE = 0.45          # frazione di fondo scala (evita clipping)
FADE_MS = 5               # fade in/out su ogni burst per togliere i click

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "sounds")


def tone(samples):
    """Burst sinusoidale a FREQ con fade lineare ai bordi."""
    fade = max(1, int(SAMPLE_RATE * FADE_MS / 1000))
    out = []
    for n in range(samples):
        v = math.sin(2.0 * math.pi * FREQ * n / SAMPLE_RATE)
        if n < fade:
            v *= n / fade
        elif n >= samples - fade:
            v *= (samples - n) / fade
        out.append(v)
    return out


def silence(samples):
    return [0.0] * samples


def write_wav(path, pattern, repeats):
    """pattern = lista di (durata_secondi, is_tono); ripetuta `repeats` volte."""
    data = []
    for _ in range(repeats):
        for seconds, is_tone in pattern:
            n = int(SAMPLE_RATE * seconds)
            data.extend(tone(n) if is_tone else silence(n))
    frames = b"".join(
        struct.pack("<h", max(-32767, min(32767, int(v * AMPLITUDE * 32767))))
        for v in data
    )
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)
    print("scritto %s (%d frame, %.1fs)" % (path, len(data), len(data) / SAMPLE_RATE))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    # ringback: un ciclo da 5s (1 on / 4 off); il loop lo fa SoundEffect.
    write_wav(os.path.join(OUT_DIR, "ringback.wav"),
              [(1.0, True), (4.0, False)], repeats=1)
    # occupato/irraggiungibile: 8 cicli rapidi 0.2/0.2 = 3.2s, riprodotto una volta.
    write_wav(os.path.join(OUT_DIR, "callbusy.wav"),
              [(0.2, True), (0.2, False)], repeats=8)


if __name__ == "__main__":
    main()
