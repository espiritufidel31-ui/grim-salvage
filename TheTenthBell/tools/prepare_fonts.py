from pathlib import Path
import urllib.request,time
root=Path(__file__).resolve().parents[1]/'art/fonts';root.mkdir(parents=True,exist_ok=True)
for name,url in [('Jersey10.ttf','jersey10/Jersey10-Regular.ttf'),('Pixelify.ttf','pixelifysans/PixelifySans%5Bwght%5D.ttf'),('Jersey10-OFL.txt','jersey10/OFL.txt'),('Pixelify-OFL.txt','pixelifysans/OFL.txt')]:
    if (root/name).exists():continue
    for attempt in range(3):
        try:
            data=urllib.request.urlopen('https://raw.githubusercontent.com/google/fonts/main/ofl/'+url,timeout=45).read();(root/name).write_bytes(data);break
        except Exception:
            if attempt==2:raise
            time.sleep(1+attempt)
print('Fonts and OFL licenses ready.')
