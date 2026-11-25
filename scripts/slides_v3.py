"""Carrusel LinkedIn v3 · informe ejecutivo · paleta azul institucional + dorado (1080x1350)."""
import io, contextlib, os, json
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from PIL import Image

FD = "/usr/share/fonts/opentype/inter/"
for f in ["Regular", "Medium", "SemiBold", "Bold", "ExtraBold"]:
    fm.fontManager.addfont(f"{FD}Inter-{f}.otf")
plt.rcParams["font.family"] = "Inter"

BG, CARD, LINE = "#0A1A33", "#10264A", "#1E3A66"
TXT, TXT2, MUT = "#F8FAFC", "#C9D6EA", "#9FB3D1"
BLUE, GOLD, GRAY = "#3B82F6", "#EAB308", "#4A5F82"
OUT = "/home/claude/obras/linkedin_v3"; os.makedirs(OUT, exist_ok=True)
CAP = "/home/claude/obras/capturas_v3"
TOTAL = 13
FUENTE = "Fuente: Contraloría General de la República, 4 informes (set-2025 a jun-2026). Análisis propio."

# ---------------- datos (misma lógica que el SQL) ----------------
os.chdir("/home/claude/obras")
with contextlib.redirect_stdout(io.StringIO()):
    exec(open("/tmp/replica.py").read().split("# indice")[0])
U = L[L.corte_id == 4].copy()
N_REG, N_OBRAS = len(L), len(U)
SALDO_TOTAL = U.saldo_inv.sum() / 1e9
COSTO_TOTAL = U.costo_ref.sum() / 1e9
PCT50 = 100 * (U.avance > 50).sum() / U.avance.notna().sum()
SIN_PIM = int((U.pim == 0).sum())
MEDIANA = U.saldo_inv.median() / 1e6
MEDIA = U.saldo_inv.mean() / 1e6
pim_rate = M.groupby("pim").salio.mean() * 100
av_rate = M.groupby("rango").salio.mean().drop("Sin dato") * 100
grp_rate = M.groupby("grupo").salio.mean() * 100
d6 = pd.read_csv("data/obras_2026_06.csv", dtype=str, keep_default_na=False)
deptos = d6.departamento.str.upper().value_counts().head(6)
caus = U.groupby("cdesc").size().sort_values(ascending=False).head(5)
cortes = L.groupby("corte_id").size().to_dict()
# índice + simulador (S/ 40 M)
U["saldo_p"] = np.where(U.saldo_obra.isna() | (U.flag == 1), U.saldo_inv, U.saldo_obra)
U["p_saldo"] = 100 * (1 - U.saldo_p.fillna(0).rank(method="min").sub(1).div(len(U) - 1))
U["idx"] = 0.4*U.avance.fillna(0) + 0.25*U.p_saldo + 0.15*100*U.fac + 0.15*100*U.pim.fillna(0) + 0.05*100*U.lista.fillna(0)
t = U.sort_values("idx", ascending=False); t = t[t.saldo_p > 0].copy(); t["acum"] = t.saldo_p.cumsum()
PRES = 40
sim = t[t.acum <= PRES * 1e6]
SIM_N, SIM_COSTO, SIM_AV = len(sim), sim.costo_ref.sum() / 1e6, sim.avance.mean()
IMPACTO = [("444", "obras de agua y\nsaneamiento"), ("341", "de educación y cultura\n(149 de educación básica)"),
           ("82", "de salud\n(58 de atención médica)"), ("438", "de transporte terrestre:\npistas, caminos, puentes")]
FACTS = dict(N_REG=N_REG, N_OBRAS=N_OBRAS, SALDO_TOTAL=SALDO_TOTAL, COSTO_TOTAL=COSTO_TOTAL, PCT50=PCT50,
             SIN_PIM=SIN_PIM, MEDIANA=MEDIANA, MEDIA=MEDIA, pim=pim_rate.to_dict(), av=av_rate.to_dict(),
             grupo=grp_rate.to_dict(), cortes=cortes, SIM=dict(pres=PRES, n=SIM_N, costo=SIM_COSTO, av=SIM_AV))

# ---------------- helpers ----------------
def base(n, kicker=None):
    fig = plt.figure(figsize=(10.8, 13.5), dpi=100, facecolor=BG)
    ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, 1080); ax.set_ylim(1350, 0); ax.axis("off")
    ax.add_patch(plt.Rectangle((0, 0), 1080, 10, color=GOLD))
    if kicker:
        ax.text(70, 95, kicker.upper(), color=GOLD, fontsize=19, fontweight="bold")
    ax.plot([70, 1010], [1262, 1262], color=LINE, lw=1.2)
    ax.text(70, 1300, "Oscar Zarate  ·  Ingeniería Industrial", color=MUT, fontsize=17, va="center")
    ax.text(1010, 1300, f"{n} / {TOTAL}", color=MUT, fontsize=17, ha="right", va="center")
    return fig, ax

def title(ax, text, y=140, size=42, color=TXT, gap=1.32):
    for i, line in enumerate(text.split("\n")):
        ax.text(70, y + i * size * gap * 1.389, line, color=color, fontsize=size, fontweight="bold", va="top")

def para(ax, x, y, text, size=22, color=TXT2, ls=1.45, weight="normal", ha="left"):
    ax.text(x, y, text, color=color, fontsize=size, va="top", linespacing=ls, fontweight=weight, ha=ha)

def card(ax, x, y, w, h, fc=CARD, ec=LINE, lw=1.4):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0,rounding_size=20", fc=fc, ec=ec, lw=lw))

def foot(ax, text=FUENTE, y=1222):
    ax.text(70, y, text, color=MUT, fontsize=14.5, va="center")

def image(fig, path, x, y, w, border=True):
    im = Image.open(path); h = w * im.size[1] / im.size[0]
    a = fig.add_axes([x / 1080, 1 - (y + h) / 1350, w / 1080, h / 1350]); a.imshow(im); a.axis("off")
    if border:
        for s in a.spines.values(): s.set_visible(True)
    return h

def hbar(fig, rect, labels, values, hi=(), fmt="{:,.0f}", size=20):
    a = fig.add_axes(rect, facecolor=BG)
    y = np.arange(len(labels))[::-1]
    a.barh(y, values, color=[GOLD if i in hi else BLUE for i in range(len(labels))], height=0.6)
    a.set_yticks(y); a.set_yticklabels(labels, color=TXT2, fontsize=size)
    mx = max(values)
    for yi, v in zip(y, values):
        a.text(v + mx * 0.02, yi, fmt.format(v), va="center", color=TXT, fontsize=size, fontweight="bold")
    a.set_xlim(0, mx * 1.2); a.set_xticks([])
    for s in a.spines.values(): s.set_visible(False)
    a.tick_params(axis="y", length=0)
    return a

def save(fig, name):
    p = f"{OUT}/{name}.png"; fig.savefig(p, dpi=100, facecolor=BG); plt.close(fig); return p

files = []

# 1 · Portada
fig, ax = base(1)
ax.text(70, 95, "PROYECTO DE DATOS  ·  SQL SERVER + POWER BI", color=GOLD, fontsize=19, fontweight="bold")
title(ax, "¿Por qué el Perú\nno termina sus obras?", y=145, size=58, gap=1.22)
para(ax, 70, 375, f"{N_OBRAS:,} obras públicas están paralizadas.\nAnalicé por qué, y qué haría para destrabarlas.", size=25, ls=1.5)
image(fig, f"{CAP}/dashboard_p1.png", 40, 530, 1000)
card(ax, 70, 1110, 940, 92, fc="#0E2246", ec=GOLD, lw=1.6)
ax.text(540, 1156, f"Datos oficiales de la Contraloría  ·  4 informes trimestrales  ·  {N_REG:,} registros",
        color=TXT, fontsize=17, ha="center", va="center", fontweight="semibold")
files.append(save(fig, "01_portada"))

# 2 · Resumen ejecutivo
fig, ax = base(2, "Resumen ejecutivo")
title(ax, "Lo esencial en 30 segundos", size=42)
items = [("1", f"El dinero destraba", f"Con presupuesto asignado, una obra sale {pim_rate[1]/pim_rate[0]:.1f} veces más\nde la lista de paralizadas ({pim_rate[1]:.1f} % vs {pim_rate[0]:.1f} %)."),
         ("2", "El avance no salva a una obra", f"Una obra al 90 % se reactiva casi igual que una al 10 %\n(entre {av_rate.min():.1f} % y {av_rate.max():.1f} % según el tramo)."),
         ("3", "Dos de cada tres no tienen presupuesto", f"{SIN_PIM:,} de {N_OBRAS:,} obras ({SIN_PIM/N_OBRAS*100:.0f} %) no tienen presupuesto\nasignado para 2026."),
         ("→", "Recomendación", f"Según el índice, con S/ {PRES} millones se terminan {SIM_N} obras ({SIM_AV:.0f} % de\navance) y se aprovechan S/ {SIM_COSTO:,.0f} millones ya invertidos.")]
for i, (num, head, body) in enumerate(items):
    y = 270 + i * 225; rec = num == "→"
    card(ax, 70, y, 940, 200, fc="#13305C" if rec else CARD, ec=GOLD if rec else LINE, lw=1.8 if rec else 1.4)
    ax.text(120, y + 100, num, color=GOLD, fontsize=46, fontweight="bold", ha="center", va="center")
    ax.text(180, y + 38, head, color=TXT, fontsize=25, fontweight="bold", va="top")
    para(ax, 180, y + 92, body, size=18, ls=1.45)
foot(ax)
files.append(save(fig, "02_resumen"))

# 3 · Contexto en simple (impacto humano)
fig, ax = base(3, "¿Por qué importa?")
title(ax, "Detrás de cada número\nhay un servicio que no llega", size=42)
para(ax, 70, 330, "Obras paralizadas a junio de 2026, por tipo:", size=22, color=MUT)
for i, (big, small) in enumerate(IMPACTO):
    x = 70 + (i % 2) * 480; y = 400 + (i // 2) * 360
    card(ax, x, y, 460, 330)
    ax.add_patch(plt.Rectangle((x, y + 45), 7, 100, color=GOLD))
    ax.text(x + 45, y + 45, big, color=TXT, fontsize=64, fontweight="bold", va="top")
    para(ax, x + 45, y + 190, small, size=22, ls=1.4)
para(ax, 70, 1125, "Colegios sin terminar, postas sin abrir, agua que no llega a las casas.", size=21, color=TXT, weight="semibold")
foot(ax)
files.append(save(fig, "03_impacto"))

# 4 · Tamaño del problema
fig, ax = base(4, "El tamaño del problema")
title(ax, f"S/ {SALDO_TOTAL:,.1f} mil millones\ndetenidos", size=46)
k = [(f"{N_OBRAS:,}", "obras paralizadas\na junio de 2026"),
     (f"S/ {COSTO_TOTAL:,.1f} mil M", "costo total de\nesas obras"),
     (f"{PCT50:.1f} %", "ya tenía más de la\nmitad de avance"),
     (f"{SIN_PIM/N_OBRAS*100:.0f} %", "no tiene presupuesto\nasignado en 2026")]
for i, (big, small) in enumerate(k):
    x = 70 + (i % 2) * 480; y = 335 + (i // 2) * 270
    card(ax, x, y, 460, 245)
    ax.text(x + 40, y + 40, big, color=TXT, fontsize=40 if len(big) < 9 else 33, fontweight="bold", va="top")
    para(ax, x + 40, y + 140, small, size=20, ls=1.4)
card(ax, 70, 890, 940, 280, fc="#13305C", ec=GOLD, lw=1.8)
ax.text(110, 925, "DATO CLAVE", color=GOLD, fontsize=17, fontweight="bold", va="top")
ax.text(110, 970, f"La mitad de las obras necesita menos de S/ {MEDIANA*1000:,.0f} mil", color=TXT, fontsize=23, fontweight="bold", va="top")
para(ax, 110, 1030, f"para terminarse (mediana). El promedio, S/ {MEDIA:,.1f} millones, lo inflan\nunas pocas megaobras. No siempre faltan montos grandes.", size=18)
foot(ax)
files.append(save(fig, "04_tamano"))

# 5 · Dónde y por qué
fig, ax = base(5, "Dónde y por qué")
title(ax, "Cusco tiene 1 de cada 6 obras.\nDinero y contratos explican\nmás de la mitad de los casos.", size=34)
para(ax, 70, 385, "Obras paralizadas por departamento (top 6)", size=20, color=MUT)
hbar(fig, [0.25, 0.48, 0.65, 0.20], [s.title().replace("Cusco", "Cusco") for s in deptos.index], deptos.values, hi={0})
lab = {"FALTA DE RECURSOS FINANCIEROS Y LIQUIDEZ": "Falta de recursos", "INCUMPLIMIENTO DE CONTRATO": "Incumplimiento de contrato",
       "DISCREPANCIAS, CONTROVERSIAS Y ARBITRAJE": "Controversias y arbitraje", "DEFICIENCIA EN EL EXPEDIENTE TÉCNICO": "Expediente deficiente",
       "OTROS": "Otros"}
para(ax, 70, 790, "Obras paralizadas por causa principal (top 5)", size=20, color=MUT)
hbar(fig, [0.37, 0.13, 0.53, 0.25], [lab.get(c, c.title()) for c in caus.index], caus.values, hi={0, 1})
foot(ax)
files.append(save(fig, "05_donde_porque"))

# 6 · Hallazgo 1
fig, ax = base(6, "Hallazgo 1 · el dinero destraba")
r = pim_rate[1] / pim_rate[0]
title(ax, f"Con presupuesto, una obra\nsale {r:.1f} veces más\nde la lista de paralizadas", size=42)
a = fig.add_axes([0.12, 0.33, 0.76, 0.34], facecolor=BG)
v = [pim_rate[1], pim_rate[0]]
a.bar([0, 1], v, color=[GOLD, GRAY], width=0.56)
for xi, vi in zip([0, 1], v):
    a.text(xi, vi + 0.5, f"{vi:.1f} %", ha="center", color=TXT, fontsize=34, fontweight="bold")
a.set_xticks([0, 1]); a.set_xticklabels(["Con presupuesto 2026", "Sin presupuesto 2026"], color=TXT2, fontsize=21)
a.set_ylim(0, 21); a.set_yticks([])
for s in a.spines.values(): s.set_visible(False)
a.tick_params(axis="x", length=0, pad=12)
para(ax, 70, 985, "Tasa de salida: % de obras que dejan la lista de paralizadas\nde un trimestre al siguiente (set-2025 → jun-2026).", size=18, color=MUT)
para(ax, 70, 1065, "Se cumple en las 5 familias de causas, en los 3 niveles de gobierno\ny en los 4 tramos de avance: siempre entre 2 y 3 veces más.", size=19, color=TXT2)
para(ax, 70, 1150, f"Y hoy {SIN_PIM:,} obras ({SIN_PIM/N_OBRAS*100:.0f} %) no tienen presupuesto asignado.", size=22, color=TXT, weight="semibold")
foot(ax)
files.append(save(fig, "06_hallazgo_presupuesto"))

# 7 · Hallazgo 2
fig, ax = base(7, "Hallazgo 2 · el avance no salva")
title(ax, "Una obra al 90 % se reactiva\ncasi igual que una al 10 %", size=42)
order = ["0-20 %", "20-50 %", "50-80 %", "80-100 %"]
a = fig.add_axes([0.12, 0.33, 0.76, 0.36], facecolor=BG)
vals = [av_rate[o] for o in order]
a.bar(range(4), vals, color=BLUE, width=0.6)
for xi, vi in enumerate(vals):
    a.text(xi, vi + 0.4, f"{vi:.1f} %", ha="center", color=TXT, fontsize=28, fontweight="bold")
a.set_xticks(range(4)); a.set_xticklabels(order, color=TXT2, fontsize=21)
a.set_ylim(0, 21); a.set_yticks([])
for s in a.spines.values(): s.set_visible(False)
a.tick_params(axis="x", length=0, pad=12)
para(ax, 70, 360, "Tasa de salida según el avance físico de la obra", size=20, color=MUT)
card(ax, 70, 965, 940, 210, fc="#13305C", ec=GOLD, lw=1.8)
ax.text(110, 1000, "QUÉ SIGNIFICA", color=GOLD, fontsize=17, fontweight="bold", va="top")
para(ax, 110, 1045, "Avanzar más no destraba una obra. Lo que la destraba es\nresolver su causa: el dinero o el contrato.", size=22, color=TXT)
foot(ax)
files.append(save(fig, "07_hallazgo_avance"))

# 8 · Recomendación + simulador
fig, ax = base(8, "Recomendación · priorizar")
title(ax, f"Con S/ {PRES} millones, el índice\nprioriza {SIM_N} obras casi listas", size=42)
para(ax, 70, 300, f"Construí un índice de priorización (0-100) y un simulador en Power BI:\neliges el presupuesto y te dice qué obras se terminan primero.", size=20, ls=1.45)
image(fig, f"{CAP}/dashboard_p3.png", 40, 420, 1000)
k = [(f"{SIM_N}", "obras se terminan"), (f"{SIM_AV:.0f} %", "de avance promedio"), (f"S/ {SIM_COSTO:,.0f} M", "ya invertidos se\naprovechan")]
for i, (big, small) in enumerate(k):
    x = 70 + i * 318
    card(ax, x, 1000, 298, 190)
    ax.text(x + 30, 1025, big, color=GOLD, fontsize=34, fontweight="bold", va="top")
    para(ax, x + 30, 1100, small, size=18.5, ls=1.3)
files.append(save(fig, "08_recomendacion"))

# 9 · Tres estrategias
V = U[U.saldo_p > 0]
def strat(df):
    df = df.assign(a=df.saldo_p.cumsum()); r = df[df.a <= PRES * 1e6]
    return len(r), r.avance.mean(), r.costo_ref.sum() / 1e6, 100 * r.pim.mean()
ST = [("Más cantidad", "Menor saldo primero", strat(V.sort_values("saldo_p")), BLUE),
      ("Índice equilibrado", "Criterio combinado", strat(V.sort_values("idx", ascending=False)), GOLD),
      ("Más avanzadas", "Mayor avance primero", strat(V.sort_values(["avance", "saldo_p"], ascending=[False, True])), GRAY)]
FACTS["ESTRATEGIAS"] = {n: dict(obras=v[0], avance=v[1], invertido=v[2], con_pim=v[3]) for n, _, v, _ in ST}
fig, ax = base(9, "Gestión de portafolio")
title(ax, f"Mismo presupuesto (S/ {PRES} M),\ntres estrategias distintas", size=40)
para(ax, 70, 300, "¿Qué obras financiar primero? Depende del objetivo.", size=21)
heads = ["Obras que\nse terminan", "Avance\npromedio", "Inversión que\nse aprovecha", "Con\npresupuesto"]
for j, h in enumerate(heads):
    para(ax, [455, 595, 730, 885][j], 375, h, size=14.5, color=MUT, ls=1.25)
for i, (n, d, (ob, av, inv, pim), col) in enumerate(ST):
    y = 460 + i * 200; hi = col == GOLD
    card(ax, 70, y, 940, 180, fc="#13305C" if hi else CARD, ec=GOLD if hi else LINE, lw=1.8 if hi else 1.4)
    ax.add_patch(plt.Rectangle((70, y + 30), 7, 120, color=col))
    ax.text(105, y + 45, n, color=TXT, fontsize=21, fontweight="bold", va="top")
    para(ax, 105, y + 92, d, size=15, color=MUT)
    for j, v in enumerate([f"{ob:,}", f"{av:.0f} %", f"S/ {inv:,.0f} M", f"{pim:.0f} %"]):
        ax.text([455, 595, 730, 885][j], y + 90, v, color=GOLD if hi else TXT, fontsize=24 if j != 2 else 20, fontweight="bold", va="center")
para(ax, 70, 1080, "Más cantidad suma más obras, pero con menos avance y casi sin presupuesto\nasignado. El índice busca obras que de verdad se puedan terminar.", size=18.5, color=TXT2)
foot(ax)
files.append(save(fig, "09_estrategias"))

# 9 · Dashboard
fig, ax = base(10, "El dashboard")
title(ax, "3 páginas: problema → causas → decisión", size=34)
image(fig, f"{CAP}/dashboard_p1.png", 100, 220, 880)
image(fig, f"{CAP}/dashboard_p2.png", 100, 220 + 495 + 22, 880)
files.append(save(fig, "10_dashboard"))

# 10 · Método
fig, ax = base(11, "Cómo lo hice")
title(ax, "De 4 Excel de la Contraloría\na un modelo de datos", size=40)
steps = [("1", "Datos", f"4 informes\n{N_REG:,} filas"), ("2", "SQL Server", "Limpieza con\n9 reglas"),
         ("3", "Modelo", "Estrella: 1 hecho\n+ 7 dimensiones"), ("4", "Power BI", "DAX, índice y\nsimulador")]
for i, (n, h, b) in enumerate(steps):
    x = 70 + i * 238
    card(ax, x, 320, 220, 250)
    ax.text(x + 25, 345, n, color=GOLD, fontsize=30, fontweight="bold", va="top")
    ax.text(x + 25, 410, h, color=TXT, fontsize=21, fontweight="bold", va="top")
    para(ax, x + 25, 465, b, size=17, ls=1.35)
# diagrama estrella
cx, cy = 540, 870
dims = ["dim_obra", "dim_ubicacion", "dim_entidad", "dim_sector", "dim_tipo_obra", "dim_causal", "dim_corte"]
for i, d in enumerate(dims):
    ang = -np.pi / 2 + i * 2 * np.pi / len(dims)
    x, y = cx + 360 * np.cos(ang), cy + 245 * np.sin(ang)
    ax.plot([cx, x], [cy, y], color=LINE, lw=2.5, zorder=1)
    card(ax, x - 115, y - 32, 230, 64)
    ax.text(x, y, d, color=TXT2, fontsize=17, ha="center", va="center", fontweight="medium")
card(ax, cx - 160, cy - 52, 320, 104, fc="#13305C", ec=GOLD, lw=2)
ax.text(cx, cy - 12, "fact_obra_corte", color=TXT, fontsize=22, fontweight="bold", ha="center", va="center")
ax.text(cx, cy + 24, "1 fila por obra y trimestre", color=MUT, fontsize=15, ha="center", va="center")
foot(ax, "Código SQL, modelo y documentación en GitHub.")
files.append(save(fig, "11_metodo"))

# 11 · Plan de acción + limitaciones
fig, ax = base(12, "Plan de acción")
title(ax, "Cómo lo gestionaría\ncomo proyecto", size=42)
fases = [("FASE 1 · 0-3 meses", "Terminar lo casi listo", f"Financiar las {SIM_N} obras del índice con S/ {PRES} millones."),
         ("FASE 2 · 3-9 meses", "Destrabar contratos", "Mesa de solución de controversias para los\nincumplimientos y arbitrajes."),
         ("FASE 3 · continuo", "Alerta temprana", "Revisar el dashboard cada trimestre y actuar\nantes de que una obra se paralice.")]
for i, (f, h, b) in enumerate(fases):
    y = 330 + i * 215
    card(ax, 70, y, 940, 195)
    ax.add_patch(plt.Rectangle((70, y + 30), 7, 135, color=GOLD))
    ax.text(110, y + 30, f, color=GOLD, fontsize=16.5, fontweight="bold", va="top")
    ax.text(110, y + 68, h, color=TXT, fontsize=24, fontweight="bold", va="top")
    para(ax, 110, y + 110, b, size=17.5, ls=1.3)
ax.text(70, 1000, "LIMITACIONES", color=MUT, fontsize=16.5, fontweight="bold", va="top")
para(ax, 70, 1038, "• \"Salir de la lista\" puede ser reactivación, culminación o baja: la CGR no lo distingue.\n"
                   "• Es una asociación, no una causa probada. • Solo 4 trimestres de datos.\n• El saldo de la CGR no incluye reajustes ni arbitrajes: S/ 40 M es un orden de magnitud.", size=16.5, ls=1.5)
foot(ax)
files.append(save(fig, "12_plan"))

# 12 · Cierre
fig, ax = base(13, "Resultados")
title(ax, "Lo que entregó\neste proyecto", size=44)
res = [(f"{N_REG:,}", "registros oficiales limpiados\ne integrados en SQL Server"),
       ("2.2×", "más reactivación con presupuesto:\nel hallazgo central"),
       (f"{SIM_N}", f"obras priorizadas que se terminan\ncon S/ {PRES} millones"),
       ("3", "páginas de dashboard con\nsimulador de presupuesto")]
for i, (b, s) in enumerate(res):
    y = 345 + i * 165
    card(ax, 70, y, 940, 145)
    ax.text(110, y + 72, b, color=GOLD, fontsize=38, fontweight="bold", va="center")
    para(ax, 330, y + 30, s, size=20, color=TXT2, ls=1.35)
para(ax, 70, 1040, "Datos públicos + SQL + Power BI + gestión de proyectos\npara convertir un problema país en decisiones concretas.", size=22, color=TXT, weight="semibold")
foot(ax, "Código, modelo y dashboard: enlace en el post.")
files.append(save(fig, "13_cierre"))

# PDF
ims = [Image.open(f).convert("RGB") for f in files]
ims[0].save(f"{OUT}/Carrusel_LinkedIn_ObrasParalizadas.pdf", save_all=True, append_images=ims[1:], resolution=100)
json.dump(FACTS, open(f"{OUT}/facts.json", "w"), indent=1, ensure_ascii=False, default=float)
print(json.dumps(FACTS, indent=1, ensure_ascii=False, default=float))
