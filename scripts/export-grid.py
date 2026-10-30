from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import argparse, json, subprocess
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--font',default='/System/Library/Fonts/STHeiti Light.ttc');args=p.parse_args();args.sky=False
font=None
sky=Image.open(ROOT/'assets/lavender-clouds-portrait.png').convert('RGB')
assert sky.size==(768,1024)
BG=(253,239,218);atlas=Image.open(ROOT/'assets/spritesheet.png').convert('RGBA')
spec=[('南瓜待机','Pumpkin idle',[280,110,110,140,140,320]),('木乃伊向右','Mummy right',[120]*7+[220]),('木乃伊向左','Mummy left',[120]*7+[220]),('南瓜招手','Pumpkin wave',[140]*3+[280]),('吸血鬼跳跃','Vampire hop',[140]*4+[280]),('木乃伊小失误','Mummy mishap',[140]*7+[240]),('南瓜等待','Pumpkin waiting',[150]*5+[260]),('女巫搅锅','Witch brewing',[120]*5+[220]),('女巫检查','Witch checking',[150]*5+[280]),('十六方向环视','Look around',[200]*16)]
spec=[(zh,en,[ms*2 for ms in ds]) for zh,en,ds in spec]
spec[1]=(spec[1][0],spec[1][1],[220]*8)
spec[2]=(spec[2][0],spec[2][1],[220]*8)
spec[0]=(spec[0][0],spec[0][1],[370,150,150,190,190,420])
frames=[]
for r,(_,_,ds) in enumerate(spec):
 frames.append([atlas.crop(((i%8)*192,(r+i//8)*208,(i%8+1)*192,(r+i//8+1)*208)) for i in range(len(ds))])
length=12800;step=40
out=ROOT/'previews';out.mkdir(exist_ok=True)
def frame_at(t,lang):
 c=sky.copy();draw=ImageDraw.Draw(c)
 for r,(zh,en,ds) in enumerate(spec):
  period=sum(ds);local=t%period
  i=0
  while local>=ds[i] and i<len(ds)-1:local-=ds[i];i+=1
  x=48+(r%3)*240 if r<9 else 288;y=176+(r//3)*208
  c.paste(frames[r][i],(x,y),frames[r][i])

 return c
for lang in ['all']:
 palette=frame_at(0,lang).quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
 indexed=[frame_at(t,lang).quantize(palette=palette,dither=Image.Dither.NONE) for t in range(0,length,step)]
 gif=out/f'grid-{lang}.gif'
 indexed[0].save(gif,save_all=True,append_images=indexed[1:],duration=step,loop=0,disposal=1,optimize=False)
 frame_at(500,lang).save(out/f'grid-{lang}.png')
 subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-v','error','-y','-i',str(gif),'-vf','fps=50,format=yuv420p','-c:v','libx264','-crf','16','-movflags','+faststart',str(out/f'grid-{lang}.mp4')],check=True)
 print(gif, gif.stat().st_size)
(out/('timing-sky.json' if args.sky else 'timing.json')).write_text(json.dumps({'duration_ms':length,'frame_step_ms':step,'layout':'portrait 3:4, three columns plus centered look group','actions':[{'zh':zh,'en':en,'frame_durations_ms':ds,'cycle_ms':sum(ds)} for zh,en,ds in spec]},ensure_ascii=False,indent=2))
