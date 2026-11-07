"""Original pixel scenery, enemies and bell icon; no third-party art."""
from PIL import Image, ImageDraw
from pathlib import Path
import random, math
OUT=Path(__file__).resolve().parents[1]/'art'
OUT.mkdir(exist_ok=True)
PALETTES=[('#101e2b','#213b47','#33494d','#52645b','#ae8b60','#efd29a'),('#181b30','#33384e','#45455c','#716b78','#b99383','#edd0a1'),('#14272d','#28423e','#40534b','#758071','#c0a471','#e9dcad'),('#241e34','#3e354c','#4e445c','#80727b','#c09a8b','#f0d3ab')]
for region,pal in enumerate(PALETTES):
    rng=random.Random(817+region); sky,far,stone,edge,gold,light=pal
    im=Image.new('RGB',(360,640),sky);d=ImageDraw.Draw(im)
    # Layered horizon and tiny windows: deliberately stepped contours.
    d.rectangle((0,106,359,242),fill=far)
    for i in range(0,360,3):
        h=126+int(15*math.sin(i/44))+rng.randrange(12)
        d.rectangle((i,h,i+3,238),fill=stone)
    for i in range(48):
        x=rng.randrange(8,354);y=rng.randrange(8,136)
        d.point((x,y),fill=edge)
        if i%6==0:d.line((x-1,y,x+1,y),fill=gold)
    d.ellipse((249,66,291,108),fill=gold);d.rectangle((247,82,294,94),fill=gold)
    d.ellipse((243,62,279,99),fill=sky)
    for i in range(0,380,24):
        top=rng.randrange(146,207)
        d.rectangle((i,top,i+19,281),fill=far);d.line((i,top,i+19,top),fill=edge)
        for y in range(top+8,232,13):
            for x in range(i+5,i+16,7):
                if rng.random()<.5:d.rectangle((x,y,x+2,y+3),fill=gold)
    # Heavy station foundations, worn brick and underground tunnel.
    d.rectangle((0,359,359,639),fill=sky)
    for y in range(364,640,15):
        d.line((0,y,359,y),fill=far)
        for x in range(-20+(15 if (y//15)%2 else 0),360,35):
            d.line((x,y,x,y+14),fill=far)
            if rng.random()<.3:d.line((x+3,y+3,x+18,y+3),fill=stone)
    for x in [18,282]:
        d.rectangle((x,371,x+58,453),fill=stone)
        d.ellipse((x,375,x+58,430),fill=sky)
        d.rectangle((x,406,x+58,457),fill=sky)
        d.line((x,415,x+58,415),fill=far,width=3)
    d.rectangle((81,415,279,463),fill=sky)
    # A stationary last train beneath the platform.
    d.rectangle((88,425,272,451),fill=stone);d.rectangle((99,419,257,425),fill=edge)
    for x in range(102,264,23):
        d.rectangle((x,430,x+15,440),fill=gold);d.rectangle((x+2,432,x+13,438),fill=light)
        d.line((x+7,431,x+7,439),fill=stone)
    d.rectangle((92,447,267,451),fill=gold)
    for x in [110,239]:d.ellipse((x,450,x+12,462),fill=far)
    d.line((10,462,350,462),fill=edge,width=2)
    # Bell gantry rises behind the actors.
    for x in [114,238]:
        d.rectangle((x,149,x+8,331),fill=sky);d.rectangle((x+1,152,x+4,329),fill=stone)
        d.line((x+5,153,x+5,326),fill=edge)
        for y in [172,252,322]:d.rectangle((x-2,y,x+10,y+4),fill=gold)
    d.rectangle((98,140,263,152),fill=sky);d.rectangle((99,141,262,145),fill=gold)
    d.rectangle((108,153,252,159),fill=stone)
    d.line((122,159,154,186),fill=edge,width=3);d.line((237,159,206,186),fill=edge,width=3)
    d.line((180,152,180,173),fill=gold,width=3)
    d.rectangle((175,170,185,174),fill=gold)
    d.polygon([(174,176),(187,176),(191,184),(191,195),(195,199),(195,202),(166,202),(166,199),(170,195),(170,184)],fill=gold)
    d.rectangle((173,182,176,195),fill=light);d.rectangle((167,200,195,202),fill=light)
    d.rectangle((177,204,184,208),fill=gold)
    # Two stair approaches. Match the game's diagonal path.
    for side in [-1,1]:
        for step in range(15):
            x=-8+step*10;y=204+step*9
            if side==1:x=360-x-38
            d.rectangle((x,y,x+38,y+13),fill=sky)
            d.rectangle((x,y,x+38,y+3),fill=edge)
            d.rectangle((x+1,y+4,x+37,y+10),fill=stone)
            d.line((x+4,y+6,x+34,y+6),fill=far)
            d.line((x,y+1,x+37,y+1),fill=gold if step%5==0 else edge)
        for t in [0,6,11]:
            x=19+t*10;y=193+t*9
            if side==1:x=360-x
            d.line((x,y-24,x,y+13),fill=sky,width=3)
            d.rectangle((x-5,y-27,x+5,y-13),fill=sky)
            d.rectangle((x-3,y-25,x+3,y-15),fill=gold)
            d.rectangle((x-1,y-24,x+1,y-16),fill=light)
        p=[(11,184),(153,311)] if side==-1 else [(349,184),(207,311)]
        d.line(p,fill=sky,width=5);d.line(p,fill=edge,width=2)
    # Central tile dais, light above dark relief.
    d.polygon([(106,328),(254,328),(295,359),(66,359)],fill=edge)
    d.polygon([(108,330),(252,330),(289,355),(73,355)],fill=stone)
    for y in [335,342,350]:d.line((103-(y-330),y,257+(y-330),y),fill=far)
    for x in range(111,260,23):d.line((x,330,x+(x-180)//4,354),fill=far)
    d.line((66,359,295,359),fill=gold,width=3)
    d.line((73,363,288,363),fill=edge,width=3)
    d.rectangle((139,364,220,371),fill=stone);d.line((142,367,217,367),fill=gold)
    # Tufts, cables and subtle atmospheric details.
    for x,y in [(34,312),(315,312),(13,384),(336,381)]:
        d.line((x,y,x-3,y-9),fill=edge);d.line((x,y,x+4,y-12),fill=edge)
    for x in range(0,360,14):d.point((x,473),fill=gold)
    im.save(OUT/f'station{region}.png')
# Original adversaries: 7 readable silhouettes, 6 stepping frames.
im=Image.new('RGBA',(48*6,58*7));d=ImageDraw.Draw(im)
for kind in range(7):
    c=['#a36950','#bc8464','#6d9290','#9e86ad','#aa9562','#996865','#a6ada4'][kind]
    for frame in range(6):
        x=frame*48;y=kind*58;bob=1 if frame in [1,2,4] else 0
        def rect(box,color):d.rectangle(tuple(v+(x if i%2==0 else y+bob) for i,v in enumerate(box)),fill=color)
        def poly(pts,color):d.polygon([(a+x,b+y+bob) for a,b in pts],fill=color)
        dark='#182631';lt='#f1c897'
        rect((14,42,32,47),dark);rect((16+(frame%3),43,21+(frame%3),49),c);rect((26-(frame%3),43,31-(frame%3),49),c)
        poly([(16,22),(31,22),(35,42),(13,42)],dark);rect((18,25,29,40),c)
        rect((16,12,30,24),dark);rect((18,13,29,23),c);rect((19,18,22,19),lt);rect((27,18,30,19),lt)
        rect((13,27,16,36),c);rect((30,27,33,37),c)
        if kind==0:poly([(16,14),(18,5),(21,13),(27,7),(31,15)],c);rect((34,30,36,45),dark);rect((33,26,37,32),lt)
        if kind==1:poly([(13,15),(35,15),(29,9),(20,8)],dark);poly([(12,24),(5,23),(7,28),(17,27)],c);rect((34,26,39,28),lt)
        if kind==2:
            rect((27,22,40,43),dark);rect((29,24,38,41),'#496e70');rect((31,26,36,38),'#b3ba94');rect((33,24,34,41),lt)
        if kind==3:
            poly([(12,25),(17,10),(30,10),(35,25)],dark);rect((18,16,29,22),c);rect((20,19,22,20),lt)
            rect((36,23,38,44),dark);rect((33,30,41,39),c);rect((35,32,39,37),'#f7d28e')
        if kind==4:rect((10,31,34,44),dark);rect((12,32,32,40),c);rect((13,33,31,34),lt);rect((6,25,8,35),lt)
        if kind==5:
            poly([(8,23),(36,23),(41,43),(6,43)],dark);rect((11,25,34,41),c);rect((15,9,32,24),dark);rect((18,13,29,22),c)
            rect((9,9,12,18),lt);rect((34,9,37,18),lt);rect((19,18,22,19),lt);rect((27,18,30,19),lt)
            rect((37,22,40,48),dark);rect((32,20,46,28),dark);rect((33,20,45,25),'#c5b090')
        if kind==6:poly([(26,26),(40,25),(44,40),(33,43)],dark);poly([(28,27),(38,27),(41,39),(34,41)],'#88c9c4');rect((33,28,35,38),lt)
im.save(OUT/'enemies.png')
im=Image.new('RGBA',(48,48));d=ImageDraw.Draw(im);d.polygon([(24,2),(46,24),(24,46),(2,24)],fill='#294751');d.polygon([(24,5),(43,24),(24,43),(5,24)],outline='#75877a',width=1)
d.rectangle((22,10,26,15),fill='#f5cc83');d.polygon([(19,16),(29,16),(32,21),(32,28),(35,31),(35,33),(13,33),(13,31),(16,28),(16,21)],fill='#e9ab61');d.rectangle((18,20,20,28),fill='#ffe5b1');d.rectangle((13,31,35,33),fill='#ffe5b1');d.rectangle((22,35,26,38),fill='#e9ab61')
im.resize((192,192),Image.Resampling.NEAREST).save(OUT/'icon.png');im.resize((432,432),Image.Resampling.NEAREST).save(OUT/'adaptive.png');Image.new('RGB',(432,432),'#101e2b').save(OUT/'iconback.png')
print('Generated four station regions, seven enemies and bell icon.')
