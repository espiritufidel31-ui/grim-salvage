"""Original bell motifs and chiptune effects, synthesized at build time."""
from pathlib import Path
import wave,math,struct,random
out=Path(__file__).resolve().parents[1]/'art/audio';out.mkdir(parents=True,exist_ok=True)
sr=22050
cues={'tap':[(740,.07)],'hit':[(180,.055)],'kill':[(490,.075),(740,.1)],'hurt':[(112,.15)],'start':[(392,.11),(523,.2)],'skill':[(659,.1),(988,.2)],'warn':[(247,.2)],'gain':[(523,.1),(659,.1),(784,.2)],'clear':[(392,.12),(523,.12),(659,.12),(784,.4)],'bell':[(523,.65)],'perfect':[(523,.16),(784,.6)],'boss':[(131,.2),(196,.2),(262,.6)]}
def save(name,notes):
    samples=[]
    for hz,dur in notes:
        for i in range(round(sr*dur)):
            t=i/sr;env=min(1,t/.004)*math.exp(-5*t/dur)*(1-(t/dur)**10)
            s=(math.sin(t*hz*math.tau)+.24*math.sin(t*hz*2.01*math.tau)+.1*math.sin(t*hz*4*math.tau))*env*.26
            samples.append(round(s*32767))
    with wave.open(str(out/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(struct.pack('<'+'h'*len(samples),*samples))
for name,notes in cues.items():save(name,notes)
melody=[392,0,523,659,0,587,523,0,330,0,440,523,0,494,440,0,349,0,466,587,0,523,466,0,294,0,392,494,0,440,392,0]
save('music',[(h,.42) for h in melody])
print('Original sound cues and bell music ready.')
