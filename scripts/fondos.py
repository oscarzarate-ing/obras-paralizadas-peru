from PIL import Image, ImageDraw, ImageFont
F="/usr/share/fonts/opentype/inter/"
def f(n,s): return ImageFont.truetype(F+n,s)
S=2  # supersampling: 2560x1440 para que se vea nítido
W,H=1280*S,720*S
BG=(10,26,51); SIDE=(8,20,41); LINE=(30,58,102); TXT=(248,250,252); MUT=(159,179,209); AMB=(234,179,8); BLUE=(59,130,246)
pages=[("1. El problema","Obras públicas paralizadas en el Perú","2,262 obras detenidas a junio 2026 · S/ 27.5 mil millones por ejecutar"),
       ("2. Por qué","¿Qué destraba una obra paralizada?","Tasa de salida de la lista de paralizadas entre trimestres consecutivos (set-25 → jun-26)"),
       ("3. Qué hacer","¿Qué obras reactivar primero?","Simulador: elige un presupuesto y mira cuántas obras se terminan, siguiendo el índice de priorización 0-100")]
for i,(nav,title,sub) in enumerate(pages):
    im=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(im)
    # sidebar
    d.rectangle([0,0,200*S,H],fill=SIDE); d.line([200*S,0,200*S,H],fill=LINE,width=S)
    d.rectangle([0,0,200*S,4*S],fill=AMB)
    d.text((20*S,24*S),"OBRAS",font=f("Inter-ExtraBold.otf",22*S),fill=TXT)
    d.text((20*S,50*S),"PARALIZADAS",font=f("Inter-ExtraBold.otf",22*S),fill=AMB)
    d.text((20*S,80*S),"Perú · 2025-2026",font=f("Inter-Medium.otf",11*S),fill=MUT)
    # nav
    d.text((20*S,366*S),"PÁGINAS",font=f("Inter-Bold.otf",10*S),fill=MUT)
    d.text((20*S,118*S),"FILTROS",font=f("Inter-Bold.otf",10*S),fill=MUT)
    d.text((20*S,660*S),"Oscar Zarate",font=f("Inter-SemiBold.otf",12*S),fill=TXT)
    d.text((20*S,678*S),"Ingeniería Industrial",font=f("Inter-Regular.otf",10*S),fill=MUT)
    # header
    d.text((216*S,16*S),title,font=f("Inter-Bold.otf",26*S),fill=TXT)
    d.text((216*S,52*S),sub,font=f("Inter-Regular.otf",13*S),fill=MUT)
    d.text((1264*S,22*S),"SQL Server · Power BI",font=f("Inter-SemiBold.otf",11*S),fill=AMB,anchor="ra")
    # footer
    d.text((216*S,700*S),"Fuente: Contraloría General de la República — informes de obras paralizadas (set-2025 a jun-2026).",font=f("Inter-Regular.otf",10*S),fill=MUT)
    im.save(f"/home/claude/obras/rediseno/Fondo_pagina_{i+1}.png")
print("ok")
