# ¿Por qué el Perú no termina sus obras?
Análisis de obras públicas paralizadas con SQL Server y Power BI.
**Fuente:** Contraloría General de la República, informes trimestrales de obras paralizadas (set-2025, dic-2025, mar-2026 y jun-2026).

## Contenido
```
data/      4 CSV listos para cargar (convertidos desde los Excel oficiales)
scripts/   excel_a_csv.py  -> convierte un nuevo informe de la CGR a CSV
sql/       01 a 05         -> ejecutar en orden en SSMS
```

## Paso a paso (unos 30 minutos)

### 1. Instala las herramientas (si no las tienes)
- **SQL Server 2022 Express** (gratis): elige la instalación "Básica".
- **SSMS** (SQL Server Management Studio).
- Al abrir SSMS, conéctate con el servidor `localhost\SQLEXPRESS` y "Autenticación de Windows".

### 2. Copia los datos
Crea la carpeta `C:\Users\Public\ObrasParalizadas\data\` y copia ahí los 4 archivos de `data/`.
> Se usa `C:\Users\Public` porque SQL Server puede leer esa carpeta sin configurar permisos.

### 3. Ejecuta los scripts en SSMS, en este orden (abrir → F5)
| Script | Qué hace | Resultado esperado |
|---|---|---|
| `01_crear_bd_y_staging.sql` | Crea la BD `ObrasParalizadas`, los esquemas `stg` y `dw`, y el procedimiento de carga | "Script 01 OK" |
| `02_cargar_cortes.sql` | Carga los 4 CSV | 2215 / 2416 / 2241 / 2262 filas |
| `03_limpieza_y_modelo_estrella.sql` | Limpia los datos y arma el modelo estrella | Las mismas cifras por corte |
| `04_vistas_analisis.sql` | Crea las vistas para Power BI | "Script 04 OK" |
| `05_validaciones.sql` | Controles de calidad | Todo "OK" y las cifras de referencia |

### Si algo falla
- **"Cannot bulk load... Operating system error 3"** → la ruta no existe: revisa la carpeta del paso 2.
- **"Operating system error 5"** → falta de permisos: usa exactamente `C:\Users\Public\...`.
- **Error con `FORMAT = 'CSV'`** → tu SQL Server es anterior a 2017: instala la versión 2022 Express.

## Modelo de datos (esquema estrella)
- **Hechos:** `dw.fact_obra_corte`, con una fila por obra y por trimestre.
- **Dimensiones:** `dim_corte`, `dim_obra`, `dim_ubicacion`, `dim_entidad`, `dim_sector`, `dim_tipo_obra` y `dim_causal`.
- **Vistas:** `vw_resumen_corte`, `vw_movimientos`, `vw_tasa_salida_por_factor` y `vw_indice_priorizacion`.

## Supuestos del analista (editables)
- **`dim_causal.factor_resolucion`:** qué tan destrabable es cada causa, en una escala de 0 a 1.
- **Pesos del índice:** avance 40 %, saldo bajo 25 %, causa resoluble 15 %, presupuesto 15 % y lista priorizada 5 %.
- **"Salió de la lista"** significa que la obra dejó de figurar como paralizada en el siguiente informe. Puede haberse reactivado, culminado o dado de baja: la CGR no indica el motivo.
