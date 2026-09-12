"""Original small synthesized scores and soft game effects; no external audio."""
from pathlib import Path
import math, random, wave, array
RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
def write(name, samples):
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE)
        f.writeframes(array.array('h', (int(max(-1, min(1, v)) * 32767) for v in samples)).tobytes())
def hz(note): return 440 * 2 ** ((note - 69) / 12)
melodies = [
 [72,76,79,76,74,77,81,77,76,79,84,79,74,77,79,72],
 [76,79,83,86,83,79,78,74,76,81,84,81,79,78,74,76],
 [79,83,86,91,86,83,81,78,79,83,88,86,83,81,78,79],
 [74,78,81,78,76,81,83,81,78,81,86,83,81,78,76,74],
 [69,72,76,79,76,72,71,67,69,74,77,74,72,71,67,69]]
for world, notes in enumerate(melodies):
    beat = [.37,.43,.40,.34,.47][world]
    duration = beat * len(notes) * 4
    samples = []
    for i in range(int(duration * RATE)):
        t = i / RATE; tick = int(t / beat); u = t % beat
        note = notes[tick % len(notes)]; f = hz(note)
        pluck = math.exp(-u * (8 if world != 1 else 5)) * min(1, u * 180)
        melody = (math.sin(math.tau*f*t) + .22*math.sin(math.tau*f*2*t)) * pluck * .22
        bass = hz(notes[(tick // 4 * 4) % len(notes)] - 24)
        pad = math.sin(math.tau*bass*t) * .065 + math.sin(math.tau*bass*1.5*t) * .035
        fade = min(1, t/.12, (duration-t)/.25)
        samples.append((melody + pad) * fade)
    write('world'+str(world),samples)
    write('bounce'+str(world), [math.sin(math.tau * (290 + world*55) * (i/RATE) + 450*(i/RATE)**2) * math.exp(-i/RATE*40) * .32 for i in range(int(.13*RATE))])
rng=random.Random(8241)
for name,duration,decay in [('crack',.11,35),('crumble',.36,10)]:
    write(name, [(rng.uniform(-1,1)*.13 + math.sin(math.tau*180*i/RATE)*.16) * math.exp(-i/RATE*decay) for i in range(int(duration*RATE))])
write('power', [math.sin(math.tau*hz([76,81,88][min(2,int(i/RATE/.10))])*i/RATE)*.23*min(1,i/RATE*200)*math.exp(-(i/RATE%.1)*18) for i in range(int(.30*RATE))])
print('Generated five original world scores, five surface sounds and three effects.')
