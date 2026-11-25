/* =====================================================================
   SCRIPT 03: Limpieza + modelo estrella (dw)
   ---------------------------------------------------------------------
   Reglas de limpieza aplicadas (documentadas para el informe):
    R1  ''/' '/'-'                      -> NULL
    R2  Texto en campos numéricos       -> NULL  (ej. 'No declarado' en año)
    R3  CUI = 0                          -> NULL  (obra sin código de inversión)
    R4  Causal: se separa código y texto, se unifica mayúsculas y espacios
        ('9 EVENTOS CLIMÁTICOS ' = '9 EVENTOS CLIMÁTICOS')
    R5  Modalidad: 'Por Contrata' = 'Contrata'
    R6  Sector: se quitan comas para unificar nombres entre informes
    R7  Costo de referencia = costo actualizado (Invierte.pe); si es 0 o
        nulo, se usa el costo del expediente técnico (Infobras)
    R8  Bandera de calidad: saldo de obra = 0 con avance < 100 %
        (solo existe en jun-2026), o saldo de inversión negativo
    R9  Obra sin código Infobras ("Inventario 4") -> código negativo -4
   Llave de la obra: CODIGO INFOBRAS (único en cada corte; el CUI se repite).
   El script se puede volver a ejecutar: borra y reconstruye el modelo.
   ===================================================================== */
USE ObrasParalizadas;
GO

/* ---------------------------------------------------------------------
   1) Vista de limpieza: tipos correctos + reglas R1-R6
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW stg.vw_obras_limpias
AS
WITH base AS (
    SELECT
        r.corte_id,
        -- R9: una obra figura solo en el inventario MEF ("Inventario 4") -> código -4
        COALESCE(TRY_CONVERT(INT, stg.fn_limpio(r.codigo_infobras)),
                 -TRY_CONVERT(INT, REPLACE(UPPER(stg.fn_limpio(r.codigo_infobras)), N'INVENTARIO', N'')))
                                                                            AS codigo_infobras,
        NULLIF(TRY_CONVERT(BIGINT, stg.fn_limpio(r.cui)), 0)                AS cui,          -- R3
        CAST(UPPER(stg.fn_limpio(r.descripcion_obra)) AS NVARCHAR(500))   AS descripcion_obra,
        CAST(UPPER(stg.fn_limpio(r.entidad)) AS NVARCHAR(300))            AS entidad,
        CAST(stg.fn_limpio(r.evento) AS NVARCHAR(100))                     AS evento,
        CAST(CASE WHEN stg.fn_limpio(r.modalidad_ejecucion) = N'Por Contrata'
             THEN N'Contrata'
             ELSE stg.fn_limpio(r.modalidad_ejecucion) END AS NVARCHAR(100)) AS modalidad,    -- R5
        TRY_CONVERT(DECIMAL(18,2), stg.fn_limpio(r.costo_obra_exp_tec))     AS costo_exp_tec,
        TRY_CONVERT(DECIMAL(18,2), stg.fn_limpio(r.saldo_obra))             AS saldo_obra,
        TRY_CONVERT(DECIMAL(18,2), stg.fn_limpio(r.costo_actualizado))      AS costo_actualizado,
        TRY_CONVERT(DECIMAL(18,2), stg.fn_limpio(r.saldo_inversion))        AS saldo_inversion,
        TRY_CONVERT(DECIMAL(18,2), stg.fn_limpio(r.pim_anio))               AS pim,
        CASE UPPER(stg.fn_limpio(r.tiene_pim)) WHEN N'SI' THEN 1 WHEN N'NO' THEN 0 END
                                                                            AS tiene_pim,
        CAST(ISNULL(stg.fn_limpio(r.tipo_obra_n1), N'NO DECLARADO') AS NVARCHAR(200)) AS tipo_obra_n1,
        CAST(ISNULL(stg.fn_limpio(r.tipo_obra_n2), N'NO DECLARADO') AS NVARCHAR(200)) AS tipo_obra_n2,
        CAST(ISNULL(stg.fn_limpio(r.tipo_obra_n3), N'NO DECLARADO') AS NVARCHAR(200)) AS tipo_obra_n3,
        CAST(ISNULL(UPPER(stg.fn_limpio(r.departamento)), N'NO DECLARADO') AS NVARCHAR(100)) AS departamento,
        CAST(ISNULL(UPPER(stg.fn_limpio(r.provincia)),    N'NO DECLARADO') AS NVARCHAR(100)) AS provincia,
        CAST(ISNULL(UPPER(stg.fn_limpio(r.distrito)),     N'NO DECLARADO') AS NVARCHAR(100)) AS distrito,
        TRY_CONVERT(INT, stg.fn_limpio(r.anio_inicio_obra))                 AS anio_inicio,  -- R2
        TRY_CONVERT(INT, stg.fn_limpio(r.plazo_ejecucion))                  AS plazo_dias,
        TRY_CONVERT(DECIMAL(6,2), stg.fn_limpio(r.avance_fisico))           AS avance_fisico,
        CAST(stg.fn_limpio(r.nivel_gobierno) AS NVARCHAR(50))              AS nivel_gobierno,
        CAST(UPPER(REPLACE(stg.fn_limpio(r.sector), N',', N'')) AS NVARCHAR(200)) AS sector,       -- R6
        CAST(UPPER(stg.fn_limpio(r.causal_paralizacion)) AS NVARCHAR(300)) AS causal_txt,
        CASE UPPER(stg.fn_limpio(r.en_inventario_mef))   WHEN N'SI' THEN 1 WHEN N'NO' THEN 0 END AS en_inventario_mef,
        CASE UPPER(stg.fn_limpio(r.tiene_informe_situacional)) WHEN N'SI' THEN 1 WHEN N'NO' THEN 0 END AS tiene_informe_situacional,
        CASE UPPER(stg.fn_limpio(r.en_lista_priorizada)) WHEN N'SI' THEN 1 WHEN N'NO' THEN 0 END AS en_lista_priorizada,
        TRY_CONVERT(INT, stg.fn_limpio(r.ult_avance_anio))                  AS ult_avance_anio,
        TRY_CONVERT(INT, stg.fn_limpio(r.ult_avance_mes))                   AS ult_avance_mes
    FROM stg.obras_raw AS r
)
SELECT
    b.*,
    -- R4: separar "10 FALTA DE RECURSOS..." en código (10) y descripción
    CASE WHEN b.causal_txt LIKE N'[0-9]%'
         THEN TRY_CONVERT(INT, LEFT(b.causal_txt, CHARINDEX(N' ', b.causal_txt + N' ') - 1)) END
                                                                            AS causal_codigo,
    CAST(LTRIM(RTRIM(CASE WHEN b.causal_txt LIKE N'[0-9]%'
                     THEN SUBSTRING(b.causal_txt, CHARINDEX(N' ', b.causal_txt + N' ') + 1, 300)
                     ELSE b.causal_txt END)) AS NVARCHAR(300))              AS causal_descripcion
FROM base AS b;
GO

/* ---------------------------------------------------------------------
   1b) Materializar la vista limpia en una tabla (se calcula UNA sola vez;
       así las dimensiones y la tabla de hechos se construyen en segundos)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg.obras_limpias;
SELECT * INTO stg.obras_limpias FROM stg.vw_obras_limpias;
CREATE CLUSTERED INDEX cx_obras_limpias ON stg.obras_limpias (codigo_infobras, corte_id);
GO

/* ---------------------------------------------------------------------
   2) Borrar el modelo (orden inverso por las llaves foráneas)
   --------------------------------------------------------------------- */
DROP VIEW  IF EXISTS dw.vw_indice_priorizacion, dw.vw_tasa_salida_por_factor,
                     dw.vw_movimientos, dw.vw_resumen_corte;
DROP TABLE IF EXISTS dw.fact_obra_corte;
DROP TABLE IF EXISTS dw.dim_obra, dw.dim_corte, dw.dim_ubicacion, dw.dim_entidad,
                     dw.dim_sector, dw.dim_tipo_obra, dw.dim_causal;
GO

/* ---------------------------------------------------------------------
   3) Dimensiones
   --------------------------------------------------------------------- */
CREATE TABLE dw.dim_corte (
    corte_id     INT          NOT NULL PRIMARY KEY,
    fecha_corte  DATE         NOT NULL,
    etiqueta     NVARCHAR(20) NOT NULL,
    informe      NVARCHAR(200) NOT NULL
);
INSERT INTO dw.dim_corte VALUES
 (1, '2025-09-30', N'Set-2025', N'Informe de obras paralizadas a setiembre 2025 - CGR'),
 (2, '2025-12-31', N'Dic-2025', N'Informe de obras paralizadas a diciembre 2025 - CGR'),
 (3, '2026-03-31', N'Mar-2026', N'Informe de obras paralizadas a marzo 2026 - CGR'),
 (4, '2026-06-30', N'Jun-2026', N'Informe de obras paralizadas a junio 2026 - CGR');

CREATE TABLE dw.dim_ubicacion (
    ubicacion_id INT IDENTITY(1,1) PRIMARY KEY,
    departamento NVARCHAR(100) NOT NULL,
    provincia    NVARCHAR(100) NOT NULL,
    distrito     NVARCHAR(100) NOT NULL,
    ubicacion_mapa AS (distrito + N', ' + provincia + N', ' + departamento + N', PERU'),  -- para el mapa de Power BI
    CONSTRAINT uq_ubicacion UNIQUE (departamento, provincia, distrito)
);
INSERT INTO dw.dim_ubicacion (departamento, provincia, distrito)
SELECT DISTINCT departamento, provincia, distrito FROM stg.obras_limpias;

CREATE TABLE dw.dim_entidad (
    entidad_id     INT IDENTITY(1,1) PRIMARY KEY,
    entidad        NVARCHAR(300) NOT NULL,
    nivel_gobierno NVARCHAR(50)  NOT NULL,
    CONSTRAINT uq_entidad UNIQUE (entidad, nivel_gobierno)
);
INSERT INTO dw.dim_entidad (entidad, nivel_gobierno)
SELECT DISTINCT ISNULL(entidad, N'NO DECLARADO'), ISNULL(nivel_gobierno, N'NO DECLARADO')
FROM stg.obras_limpias;

CREATE TABLE dw.dim_sector (
    sector_id INT IDENTITY(1,1) PRIMARY KEY,
    sector    NVARCHAR(200) NOT NULL UNIQUE
);
INSERT INTO dw.dim_sector (sector)
SELECT DISTINCT ISNULL(sector, N'NO DECLARADO') FROM stg.obras_limpias;

CREATE TABLE dw.dim_tipo_obra (
    tipo_obra_id INT IDENTITY(1,1) PRIMARY KEY,
    tipo_n1 NVARCHAR(200) NOT NULL,
    tipo_n2 NVARCHAR(200) NOT NULL,
    tipo_n3 NVARCHAR(200) NOT NULL,
    CONSTRAINT uq_tipo UNIQUE (tipo_n1, tipo_n2, tipo_n3)
);
INSERT INTO dw.dim_tipo_obra (tipo_n1, tipo_n2, tipo_n3)
SELECT DISTINCT tipo_obra_n1, tipo_obra_n2, tipo_obra_n3 FROM stg.obras_limpias;

/* Causales + clasificación propia (SUPUESTO DEL ANALISTA, editable):
   grupo_causal agrupa las causas por tipo de solución, y
   factor_resolucion (0-1) estima qué tan "destrabable" es la causa
   con gestión y presupuesto. Se usa en el índice de priorización.     */
CREATE TABLE dw.dim_causal (
    causal_id          INT IDENTITY(1,1) PRIMARY KEY,
    causal_codigo      INT NULL,
    causal_descripcion NVARCHAR(300) NOT NULL UNIQUE,
    grupo_causal       NVARCHAR(30)  NOT NULL,
    factor_resolucion  DECIMAL(3,2)  NOT NULL
);
INSERT INTO dw.dim_causal (causal_codigo, causal_descripcion, grupo_causal, factor_resolucion)
SELECT
    MAX(causal_codigo),
    causal_descripcion,
    CASE
        WHEN MAX(causal_codigo) IN (10, 12)              THEN N'Financiera'
        WHEN MAX(causal_codigo) IN (1, 2, 3)
          OR causal_descripcion LIKE N'NULIDAD%'
          OR causal_descripcion LIKE N'FALTA DE PERSONAL%' THEN N'Contractual'
        WHEN MAX(causal_codigo) IN (5, 6, 7, 8, 11)      THEN N'Técnica / permisos'
        WHEN MAX(causal_codigo) IN (4, 9)
          OR causal_descripcion LIKE N'OTRAS SITUACIONES%' THEN N'Externa'
        ELSE N'Otros'
    END,
    CASE
        WHEN MAX(causal_codigo) IN (10, 12)              THEN 1.00
        WHEN MAX(causal_codigo) IN (5, 6, 7, 8, 11)      THEN 0.60
        WHEN MAX(causal_codigo) = 15                     THEN 0.50
        WHEN MAX(causal_codigo) IN (1, 2, 3)
          OR causal_descripcion LIKE N'NULIDAD%'
          OR causal_descripcion LIKE N'FALTA DE PERSONAL%' THEN 0.40
        ELSE 0.30
    END
FROM stg.obras_limpias
WHERE causal_descripcion IS NOT NULL
GROUP BY causal_descripcion;

/* dim_obra: atributos que describen la obra (se toma su versión más reciente) */
CREATE TABLE dw.dim_obra (
    codigo_infobras  INT            NOT NULL PRIMARY KEY,
    cui              BIGINT         NULL,
    descripcion_obra NVARCHAR(1000) NULL,
    modalidad        NVARCHAR(100)  NULL,
    evento           NVARCHAR(100)  NULL,
    anio_inicio      INT            NULL,
    plazo_dias       INT            NULL,
    primer_corte_id  INT            NOT NULL,
    ultimo_corte_id  INT            NOT NULL,
    cortes_presente  INT            NOT NULL
);
INSERT INTO dw.dim_obra
SELECT x.codigo_infobras, x.cui, x.descripcion_obra, x.modalidad, x.evento,
       x.anio_inicio, x.plazo_dias, x.primer_corte, x.ultimo_corte, x.n_cortes
FROM (
    SELECT l.codigo_infobras, l.cui, l.descripcion_obra, l.modalidad, l.evento,
           l.anio_inicio, l.plazo_dias,
           ROW_NUMBER() OVER (PARTITION BY l.codigo_infobras ORDER BY l.corte_id DESC) AS rn,
           MIN(l.corte_id) OVER (PARTITION BY l.codigo_infobras)  AS primer_corte,
           MAX(l.corte_id) OVER (PARTITION BY l.codigo_infobras)  AS ultimo_corte,
           COUNT(*)        OVER (PARTITION BY l.codigo_infobras)  AS n_cortes
    FROM stg.obras_limpias AS l
    WHERE l.codigo_infobras IS NOT NULL
) AS x
WHERE x.rn = 1;
GO

/* ---------------------------------------------------------------------
   4) Tabla de hechos: una fila por obra y por corte
   --------------------------------------------------------------------- */
CREATE TABLE dw.fact_obra_corte (
    corte_id                  INT NOT NULL REFERENCES dw.dim_corte(corte_id),
    codigo_infobras           INT NOT NULL REFERENCES dw.dim_obra(codigo_infobras),
    ubicacion_id              INT NOT NULL REFERENCES dw.dim_ubicacion(ubicacion_id),
    entidad_id                INT NOT NULL REFERENCES dw.dim_entidad(entidad_id),
    sector_id                 INT NOT NULL REFERENCES dw.dim_sector(sector_id),
    tipo_obra_id              INT NOT NULL REFERENCES dw.dim_tipo_obra(tipo_obra_id),
    causal_id                 INT NULL     REFERENCES dw.dim_causal(causal_id),
    costo_exp_tec             DECIMAL(18,2) NULL,
    costo_actualizado         DECIMAL(18,2) NULL,
    costo_referencia          AS (CASE WHEN costo_actualizado > 0 THEN costo_actualizado
                                       ELSE costo_exp_tec END) PERSISTED,          -- R7
    saldo_inversion           DECIMAL(18,2) NULL,
    saldo_obra                DECIMAL(18,2) NULL,
    pim                       DECIMAL(18,2) NULL,
    tiene_pim                 BIT NULL,
    avance_fisico             DECIMAL(6,2)  NULL,
    rango_avance              AS (CASE WHEN avance_fisico IS NULL THEN N'Sin dato'
                                       WHEN avance_fisico >= 80 THEN N'80-100 %'
                                       WHEN avance_fisico >= 50 THEN N'50-80 %'
                                       WHEN avance_fisico >= 20 THEN N'20-50 %'
                                       ELSE N'0-20 %' END),
    en_inventario_mef         BIT NULL,
    tiene_informe_situacional BIT NULL,
    en_lista_priorizada       BIT NULL,
    ult_avance_anio           INT NULL,
    ult_avance_mes            INT NULL,
    flag_dato_sospechoso      BIT NOT NULL,                                          -- R8
    CONSTRAINT pk_fact_obra_corte PRIMARY KEY (corte_id, codigo_infobras)
);

INSERT INTO dw.fact_obra_corte (
    corte_id, codigo_infobras, ubicacion_id, entidad_id, sector_id, tipo_obra_id, causal_id,
    costo_exp_tec, costo_actualizado, saldo_inversion, saldo_obra, pim, tiene_pim,
    avance_fisico, en_inventario_mef, tiene_informe_situacional, en_lista_priorizada,
    ult_avance_anio, ult_avance_mes, flag_dato_sospechoso)
SELECT
    l.corte_id, l.codigo_infobras, u.ubicacion_id, e.entidad_id, s.sector_id, t.tipo_obra_id, c.causal_id,
    l.costo_exp_tec, l.costo_actualizado, l.saldo_inversion, l.saldo_obra, l.pim, l.tiene_pim,
    l.avance_fisico, l.en_inventario_mef, l.tiene_informe_situacional, l.en_lista_priorizada,
    l.ult_avance_anio, l.ult_avance_mes,
    CASE WHEN (l.saldo_obra = 0 AND l.avance_fisico < 100) OR l.saldo_inversion < 0
         THEN 1 ELSE 0 END
FROM stg.obras_limpias AS l
JOIN dw.dim_ubicacion AS u ON u.departamento = l.departamento AND u.provincia = l.provincia AND u.distrito = l.distrito
JOIN dw.dim_entidad   AS e ON e.entidad = ISNULL(l.entidad, N'NO DECLARADO') AND e.nivel_gobierno = ISNULL(l.nivel_gobierno, N'NO DECLARADO')
JOIN dw.dim_sector    AS s ON s.sector  = ISNULL(l.sector, N'NO DECLARADO')
JOIN dw.dim_tipo_obra AS t ON t.tipo_n1 = l.tipo_obra_n1 AND t.tipo_n2 = l.tipo_obra_n2 AND t.tipo_n3 = l.tipo_obra_n3
LEFT JOIN dw.dim_causal AS c ON c.causal_descripcion = l.causal_descripcion
WHERE l.codigo_infobras IS NOT NULL;
GO

SELECT c.etiqueta, COUNT(*) AS obras
FROM dw.fact_obra_corte f JOIN dw.dim_corte c ON c.corte_id = f.corte_id
GROUP BY c.etiqueta, c.corte_id ORDER BY c.corte_id;

PRINT N'Script 03 OK: modelo estrella construido.';
