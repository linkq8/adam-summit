"""Generate original lightweight music and UI tones; standard library only."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'assets' / 'audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def render(name, notes, duration):
    data = [0.0] * int(duration * RATE)
    for start, freq, length, gain in notes:
        for j in range(int(length * RATE)):
            i = int(start * RATE) + j
            if i >= len(data):
                break
            t = j / RATE
            env = min(1, t / 0.008) * math.exp(-t * 5 / length)
            tone = math.sin(math.tau * freq * t) + .22 * math.sin(math.tau * freq * 2 * t)
            data[i] += gain * env * tone
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', int(max(-.95, min(.95, x)) * 32767)) for x in data))

render('bounce', [(0, 360, .11, .28), (.035, 510, .10, .18)], .18)
render('star', [(0, 1046.5, .16, .26), (.065, 1568, .20, .23)], .30)
render('count', [(0, 523.25, .20, .4)], .25)
render('go', [(0, 1046.5, .42, .4)], .50)
render('checkpoint', [(0, 659.25, .2, .3), (.10, 783.99, .2, .3), (.2, 1046.5, .3, .3)], .6)
render('rescue', [(0, 440, .18, .25), (.09, 523.25, .18, .25), (.18, 659.25, .24, .25)], .5)
render('win', [(j * .13, f, .5, .3) for j, f in enumerate([523.25, 659.25, 783.99, 1046.5])], 1.3)
melody = [76, 79, 81, 79, 76, 74, 72, 0, 74, 76, 79, 76, 74, 72, 69, 0,
          72, 76, 79, 81, 79, 76, 74, 0, 72, 74, 76, 74, 72, 69, 72, 0]
notes = []
for i, pitch in enumerate(melody):
    if pitch:
        notes.append((i * .5, 440 * 2 ** ((pitch - 69) / 12), .6, .15))
for i, pitch in enumerate([48, 53, 55, 48, 57, 53, 55, 48]):
    notes.append((i * 2, 440 * 2 ** ((pitch - 69) / 12), 1.9, .12))
render('garden', notes, 16)
