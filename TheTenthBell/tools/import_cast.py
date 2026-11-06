"""Prepare gameplay-only sprite atlases. Local mode uses the player's six CraftPix ZIPs."""
import argparse, hashlib, json, math, re, time
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path
from statistics import median
from urllib.parse import quote
from urllib.request import urlopen
from zipfile import ZipFile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'tools'
CELL = (136,84)
FOOT = (62,72)
def download(url):
    for attempt in range(3):
        try:
            with urlopen(url,timeout=45) as r:return r.read()
        except OSError:
            if attempt==2:raise
            time.sleep(1+attempt)
def img(data):
    return Image.open(BytesIO(data)).convert('RGBA')
def strips(data):
    sheet=img(data);side=sheet.height
    if sheet.width%side:raise ValueError('Non-square frame strip')
    return [sheet.crop((x,0,x+side,side)) for x in range(0,sheet.width,side)]
def make_actor(index,pack,folder,files,read,out):
    names={Path(n).stem:n for n in files}
    if pack=='622999':
        for k,v in list(names.items()):names[re.sub(r'_\d+$','',k.split('_Monster_')[-1])]=v
    def first(*keys):return next((names[k] for k in keys if k in names),None)
    actions={'idle':first('Idle'),'walk':first('Walk','Run'),'attack':first('Shot','Attack_1','Attack','Attack1'),'alt':first('Attack_2','Attack2','Attack'),'special':first('Special_Blow_2','Attack_3','Throw','Attack','Shot'),'guard':first('Protection','Protect','Shield','Push'),'hurt':first('Hurt','Hurt_1'),'down':first('Dead','Death','K.O.')}
    if index==8:actions['special']=first('Push')
    if index==1:actions['special']=first('Shot')
    effect=first('Arrow','Book','Charge','Rock2')
    wanted=sorted(set(v for v in [*actions.values(),effect] if v))
    data={k:read(k) for k in wanted}
    boxes=[f.getbbox() for f in strips(data[actions['idle']]) if f.getbbox()]
    ox=median((b[0]+b[2])/2 for b in boxes);oy=median(b[3] for b in boxes)
    scale=(38 if pack=='622999' else 52)/median(b[3]-b[1] for b in boxes)
    tiles=[];info={};seen={}
    for state,file in actions.items():
        if not file:continue
        if file in seen:info[state]=seen[file];continue
        frames=strips(data[file]);info[state]=[len(tiles),len(frames)];seen[file]=info[state]
        for frame in frames:
            tile=Image.new('RGBA',CELL);box=frame.getbbox()
            if box:
                crop=frame.crop(box)
                crop=crop.resize((max(1,round(crop.width*scale)),max(1,round(crop.height*scale))),Image.Resampling.NEAREST)
                tile.paste(crop,(round(FOOT[0]+(box[0]-ox)*scale),round(FOOT[1]+(box[1]-oy)*scale)))
            tiles.append(tile)
    atlas=Image.new('RGBA',(CELL[0]*8,CELL[1]*math.ceil(len(tiles)/8)))
    for i,t in enumerate(tiles):atlas.paste(t,(i%8*CELL[0],i//8*CELL[1]))
    atlas.save(out/f'h{index:02}.png',optimize=True)
    if effect:
        frames=strips(data[effect]);page=Image.new('RGBA',(len(frames)*36,36))
        for i,f in enumerate(frames):
            if not f.getbbox():continue
            c=f.crop(f.getbbox());sc=min(29/c.width,26/c.height);c=c.resize((max(1,round(c.width*sc)),max(1,round(c.height*sc))),Image.Resampling.NEAREST)
            page.paste(c,(i*36+(36-c.width)//2,(36-c.height)//2))
        page.save(out/f'p{index:02}.png');info['projectile']=len(frames)
    print(f'{pack} / {folder}: {len(tiles)} character frames',flush=True)
    return info
def run(zip_dir):
    out=ROOT/'cast';out.mkdir(exist_ok=True)
    sources={p:(repo,path,ref) for p,repo,path,ref in json.loads((TOOLS/'asset_sources.json').read_text())}
    manifest=json.loads((TOOLS/'cast_manifest.json').read_text())
    def process(entry):
        i,(pack,folder,files)=entry
        if zip_dir:
            matches=list(zip_dir.glob('*'+pack+'*.zip'))
            if len(matches)!=1:raise SystemExit('Missing ZIP with ID '+pack)
            with ZipFile(matches[0]) as z:
                return make_actor(i,pack,folder,files,lambda n:z.read(folder+'/'+n),out)
        repo,path,ref=sources[pack]
        def read(name):
            url=f'https://raw.githubusercontent.com/{repo}/{ref}/'+quote(path+'/'+folder+'/'+name,safe='/')
            b=download(url)
            digest=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
            if digest!=files[name]:raise ValueError(f'Unexpected {folder}/{name}')
            return b
        return make_actor(i,pack,folder,files,read,out)
    with ThreadPoolExecutor(max_workers=6) as pool:result=list(pool.map(process,enumerate(manifest)))
    assert len(result)==18 and all('attack' in o and 'idle' in o for o in result)
    (out/'frames.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--zips',type=Path,help='Directory containing the six provided CraftPix archives.');args=p.parse_args();run(args.zips)
