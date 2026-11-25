"""
Convierte el Excel de obras paralizadas de la Contraloría a un CSV listo para
BULK INSERT en SQL Server.

- No limpia datos (la limpieza se hace en SQL, a propósito).
- Solo estandariza los nombres de columnas (snake_case) para que todos los
  trimestres tengan el mismo encabezado, aunque la Contraloría cambie
  detalles como "PIM 2026" -> "PIM 2025".

Uso:
    python excel_a_csv.py <archivo.xlsx> <salida.csv>
"""
import sys
import unicodedata
import pandas as pd

# Columnas estándar, en el orden en que se cargan en SQL (stg.carga)
COLUMNAS = [
    "n", "codigo_infobras", "cui", "descripcion_inversion", "snip",
    "descripcion_obra", "entidad", "evento", "modalidad_ejecucion",
    "costo_obra_exp_tec", "saldo_obra", "costo_actualizado", "rango_inversion",
    "saldo_inversion", "pim_anio", "tiene_pim", "tipo_obra_n1", "tipo_obra_n2",
    "tipo_obra_n3", "departamento", "provincia", "distrito", "anio_inicio_obra",
    "plazo_ejecucion", "avance_fisico", "rango_avance_fisico", "nivel_gobierno",
    "sector", "causal_paralizacion", "unidad_organica", "en_inventario_mef",
    "fecha_registro_inventario", "tiene_informe_situacional",
    "fecha_informe_situacional", "url_informe", "en_lista_priorizada",
    "fecha_resolucion_priorizada", "url_resolucion",
    # Solo existen en los informes de set-2025 a mar-2026 (quedan vacías en jun-2026)
    "ult_avance_mes", "ult_avance_anio", "aplica_ley_31589",
]

# Palabras clave para reconocer cada columna en el encabezado original
CLAVES = {
    "n": ["N°"], "codigo_infobras": ["CODIGO INFOBRAS"], "cui": ["CUI"],
    "descripcion_inversion": ["DESCRIPCION DE INVERSION"], "snip": ["SNIP"],
    "descripcion_obra": ["DESCRIPCION OBRA"], "entidad": ["ENTIDAD"],
    "evento": ["EVENTO"], "modalidad_ejecucion": ["MODALIDAD"],
    "costo_obra_exp_tec": ["COSTO DE OBRA"], "saldo_obra": ["SALDO DE OBRA"],
    "costo_actualizado": ["COSTO ACTUALIZADO"],
    "rango_inversion": ["RANGO DE INVERSION"],
    # jun-2026: "SALDO DE LA INVERSIÓN"; informes anteriores: "SALDO DE INVERSION (Costo Act. - Dev. Acum.)"
    "saldo_inversion": ["SALDO DE LA INVERSION", "SALDO DE INVERSION"], "pim_anio": ["PIM "],
    "ult_avance_mes": ["ULT. AVANCE REPORTADO (MES)"],
    "ult_avance_anio": ["ULT. AVANCE REPORTADO"],
    "aplica_ley_31589": ["APLICACION PARA LEY 31589"],
    "tiene_pim": ["TIENE PIM"], "tipo_obra_n1": ["TIPO DE OBRA"],
    "tipo_obra_n2": ["TIPO DE OBRA (NIVEL 2)"],
    "tipo_obra_n3": ["TIPO DE OBRA (NIVEL 3)"], "departamento": ["DEPARTAMENTO"],
    "provincia": ["PROVINCIA"], "distrito": ["DISTRITO"],
    "anio_inicio_obra": ["ANO INICIO"], "plazo_ejecucion": ["PLAZO"],
    "avance_fisico": ["AVANCE FISICO"],
    "rango_avance_fisico": ["RANGO AVANCE"], "nivel_gobierno": ["NIVEL DE GOBIERNO"],
    "sector": ["SECTOR"], "causal_paralizacion": ["CAUSAL"],
    "unidad_organica": ["UNIDAD ORGANICA"], "en_inventario_mef": ["ESTA EN EL INVENTARIO"],
    "fecha_registro_inventario": ["FECHA DE REGISTRO"],
    "tiene_informe_situacional": ["CUENTA CON INFORME"],
    "fecha_informe_situacional": ["FECHA INFORME"], "url_informe": ["URL INFORME"],
    "en_lista_priorizada": ["DENTRO DE LA LISTA"],
    "fecha_resolucion_priorizada": ["FECHA RESOLUCION"],
    "url_resolucion": ["URL RESOLUCION"],
}


def normalizar(texto):
    texto = str(texto).split("\n")[0].strip().upper()
    texto = unicodedata.normalize("NFKD", texto)
    return "".join(c for c in texto if not unicodedata.combining(c))


def mapear(encabezados):
    norm = {h: normalizar(h) for h in encabezados}
    mapa = {}
    # primero las claves más largas, para que "TIPO DE OBRA (NIVEL 2)" gane a "TIPO DE OBRA"
    pares = sorted(((c, k) for c, ks in CLAVES.items() for k in ks),
                   key=lambda x: -len(x[1]))
    usados = set()
    for col, clave in pares:
        if col in mapa:
            continue
        for h, n in norm.items():
            if h in usados:
                continue
            exacto = col in ("n", "cui", "snip", "entidad", "sector", "tipo_obra_n1")
            if (n == clave) if exacto else n.startswith(clave):
                mapa[col] = h
                usados.add(h)
                break
    faltan = [c for c in COLUMNAS if c not in mapa]
    return mapa, faltan


def main(entrada, salida):
    hojas = pd.ExcelFile(entrada).sheet_names
    hoja = "BD_OP" if "BD_OP" in hojas else hojas[0]   # BD_OP = base oficial del informe
    df = pd.read_excel(entrada, sheet_name=hoja, dtype=object)
    df = df[df.iloc[:, 1].notna()]                      # descarta filas vacías al final
    mapa, faltan = mapear(df.columns)
    if faltan:
        print("AVISO - columnas no encontradas (quedarán vacías):", faltan)
    out = pd.DataFrame({c: df[mapa[c]] if c in mapa else None for c in COLUMNAS})

    def a_texto(v):
        if v is None or (isinstance(v, float) and pd.isna(v)):
            return ""
        if isinstance(v, pd.Timestamp) or hasattr(v, "strftime"):
            return v.strftime("%Y-%m-%d")
        if isinstance(v, float):
            return f"{v:.2f}".rstrip("0").rstrip(".")
        return str(v)

    out = out.map(a_texto)
    out.to_csv(salida, index=False, encoding="utf-8", quoting=1, lineterminator="\r\n")
    print(f"OK: {len(out)} filas -> {salida}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
