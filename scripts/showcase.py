from PIL import Image, ImageDraw, ImageFont
import os
BG=(10,26,51); TXT=(248,250,252); MUT=(159,179,209); AMB=(234,179,8)
F="/usr/share/fonts/opentype/inter/"
def f(n,s): return ImageFont.truetype(F+n,s)
OUT="/home/claude/obras/showcase"; os.makedirs(OUT,exist_ok=True)
W,H=1200,627
def frame(shot, kicker, title, name, footer="Oscar Zarate · Ingeniería Industrial · Datos: Contraloría General de la República"):
    im=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(im)
    d.rectangle([0,0,W,6],fill=AMB)
    d.text((48,30),kicker.upper(),font=f("Inter-Bold.otf",15),fill=AMB)
    d.text((48,54),title,font=f("Inter-Bold.otf",30),fill=TXT)
    s=Image.open(shot).convert("RGB")
    maxw,maxh=W-96,H-110-52
    r=min(maxw/s.width,maxh/s.height); s=s.resize((int(s.width*r),int(s.height*r)),Image.LANCZOS)
    x=(W-s.width)//2; y=110
    d.rounded_rectangle([x-4,y-4,x+s.width+4,y+s.height+4],radius=10,outline=(30,58,102),width=2)
    im.paste(s,(x,y))
    d.text((48,H-34),footer,font=f("Inter-Regular.otf",13),fill=MUT)
    im.save(f"{OUT}/{name}.png"); return f"{OUT}/{name}.png"
C="/home/claude/obras/capturas_v3/"
frame(C+"dashboard_p1.png","Dashboard Power BI · Página 1","¿Por qué el Perú no termina sus obras?","A_portada_proyecto")
frame(C+"dashboard_p2.png","Dashboard Power BI · Página 2","Con presupuesto, una obra sale 2.2× más de la lista","B_hallazgo_presupuesto")
frame(C+"dashboard_p3.png","Dashboard Power BI · Página 3","Simulador: con S/ 40 millones se terminan 106 obras","C_simulador_priorizacion")
frame("/home/claude/obras/linkedin_v3/10_metodo.png","SQL Server + Power BI","Modelo estrella: 1 tabla de hechos + 7 dimensiones","D_modelo_de_datos_carrusel")
frame("/home/claude/obras/capturas/pbi_modelo.jpg","SQL Server + Power BI","Modelo estrella: 1 tabla de hechos + 7 dimensiones","D_modelo_de_datos")
print(os.listdir(OUT))
