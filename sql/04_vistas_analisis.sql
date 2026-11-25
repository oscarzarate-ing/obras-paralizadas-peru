/* =====================================================================
   SCRIPT 04: Vistas de análisis (las que se conectan a Power BI)
   ---------------------------------------------------------------------
   dw.vw_resumen_corte          KPIs por trimestre
   dw.vw_movimientos            Qué obras salen, entran o siguen en la lista
   dw.vw_tasa_salida_por_factor Qué características tienen las obras que SÍ
                                salen de la lista (el hallazgo central)
   dw.vw_indice_priorizacion    Ranking de obras a reactivar (último corte)
   ===================================================================== */
USE ObrasParalizadas;
GO

/* ---------------------------------------------------------------------
   1) Resumen por corte
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dw.vw_resumen_corte
AS
SELECT
    c.corte_id,
    c.etiqueta,
    c.fecha_corte,
    COUNT(*)                                                     AS obras_paralizadas,
    SUM(f.costo_referencia)                                      AS inversion_total,
    SUM(f.saldo_inversion)                                       AS saldo_inversion,
    AVG(f.avance_fisico)                                         AS avance_promedio,
    SUM(CASE WHEN f.avance_fisico > 50  THEN 1 ELSE 0 END)       AS obras_avance_mayor_50,
    SUM(CASE WHEN f.avance_fisico >= 80 THEN 1 ELSE 0 END)       AS obras_avance_80_mas,
    SUM(CASE WHEN f.tiene_pim = 1       THEN 1 ELSE 0 END)       AS obras_con_pim,
    CAST(100.0 * SUM(CASE WHEN f.avance_fisico > 50 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(f.avance_fisico), 0) AS DECIMAL(5,1))    AS pct_avance_mayor_50
FROM dw.fact_obra_corte AS f
JOIN dw.dim_corte       AS c ON c.corte_id = f.corte_id
GROUP BY c.corte_id, c.etiqueta, c.fecha_corte;
GO

/* ---------------------------------------------------------------------
   2) Movimientos entre cortes consecutivos
   OJO al interpretar: "Salió de la lista" significa que la obra dejó de
   figurar como paralizada (se reactivó, se culminó o se dio de baja).
   El informe de la CGR no distingue el motivo.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dw.vw_movimientos
AS
WITH pares AS (
    SELECT corte_id AS corte_desde,
           LEAD(corte_id) OVER (ORDER BY fecha_corte) AS corte_hasta
    FROM dw.dim_corte
)
SELECT
    p.corte_desde,
    p.corte_hasta,
    x.codigo_infobras,
    x.movimiento,
    x.avance_desde,
    x.avance_hasta,
    x.tenia_pim,
    x.causal_id_desde,
    x.saldo_inversion_desde
FROM pares AS p
CROSS APPLY (
    SELECT
        COALESCE(a.codigo_infobras, b.codigo_infobras) AS codigo_infobras,
        CASE WHEN b.codigo_infobras IS NULL THEN N'Salió de la lista'
             WHEN a.codigo_infobras IS NULL THEN N'Ingresó a la lista'
             ELSE N'Sigue paralizada' END              AS movimiento,
        a.avance_fisico   AS avance_desde,
        b.avance_fisico   AS avance_hasta,
        a.tiene_pim       AS tenia_pim,
        a.causal_id       AS causal_id_desde,
        a.saldo_inversion AS saldo_inversion_desde
    FROM      (SELECT * FROM dw.fact_obra_corte WHERE corte_id = p.corte_desde) AS a
    FULL JOIN (SELECT * FROM dw.fact_obra_corte WHERE corte_id = p.corte_hasta) AS b
           ON a.codigo_infobras = b.codigo_infobras
) AS x
WHERE p.corte_hasta IS NOT NULL;
GO

/* ---------------------------------------------------------------------
   3) Tasa de salida por factor: de las obras paralizadas en un corte,
   ¿qué % ya no figura en el siguiente? Se compara por factor.
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dw.vw_tasa_salida_por_factor
AS
WITH m AS (
    SELECT mv.*, f.rango_avance, dc.grupo_causal, de.nivel_gobierno, o.modalidad
    FROM dw.vw_movimientos  AS mv
    JOIN dw.fact_obra_corte AS f  ON f.corte_id = mv.corte_desde AND f.codigo_infobras = mv.codigo_infobras
    JOIN dw.dim_entidad     AS de ON de.entidad_id = f.entidad_id
    JOIN dw.dim_obra        AS o  ON o.codigo_infobras = mv.codigo_infobras
    LEFT JOIN dw.dim_causal AS dc ON dc.causal_id = f.causal_id
    WHERE mv.movimiento <> N'Ingresó a la lista'
),
largo AS (
    SELECT N'Tiene presupuesto (PIM)' AS factor,
           CASE tenia_pim WHEN 1 THEN N'Sí' WHEN 0 THEN N'No' ELSE N'Sin dato' END AS valor,
           movimiento FROM m
    UNION ALL SELECT N'Avance físico',    rango_avance,                     movimiento FROM m
    UNION ALL SELECT N'Grupo de causal',  ISNULL(grupo_causal, N'Sin dato'), movimiento FROM m
    UNION ALL SELECT N'Nivel de gobierno', nivel_gobierno,                   movimiento FROM m
    UNION ALL SELECT N'Modalidad',        ISNULL(modalidad, N'Sin dato'),   movimiento FROM m
)
SELECT
    factor,
    valor,
    COUNT(*)                                                           AS obras_evaluadas,
    SUM(CASE WHEN movimiento = N'Salió de la lista' THEN 1 ELSE 0 END) AS salieron,
    CAST(100.0 * SUM(CASE WHEN movimiento = N'Salió de la lista' THEN 1 ELSE 0 END)
         / COUNT(*) AS DECIMAL(5,1))                                   AS tasa_salida_pct
FROM largo
GROUP BY factor, valor;
GO

/* ---------------------------------------------------------------------
   4) Índice de priorización (último corte disponible)
   Puntaje 0-100 = ponderación de 5 criterios (pesos = SUPUESTO editable):
     40 %  Avance físico            (más avanzada = más cerca de servir)
     25 %  Saldo pendiente bajo     (percentil inverso: menos plata para terminar)
     15 %  Causa resoluble          (dim_causal.factor_resolucion)
     15 %  Ya tiene presupuesto     (PIM del año)
      5 %  Está en lista priorizada oficial (Ley 31589)
   Saldo pendiente = saldo de obra (Infobras); si no existe o es dudoso,
   saldo de inversión (Invierte.pe).
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dw.vw_indice_priorizacion
AS
WITH ultimo AS (
    SELECT MAX(corte_id) AS corte_id FROM dw.fact_obra_corte
),
base AS (
    SELECT
        f.*,
        CASE WHEN f.saldo_obra IS NULL OR f.flag_dato_sospechoso = 1
             THEN f.saldo_inversion ELSE f.saldo_obra END AS saldo_pendiente,
        ISNULL(dc.factor_resolucion, 0.30)              AS factor_resolucion
    FROM dw.fact_obra_corte AS f
    JOIN ultimo             AS u  ON u.corte_id = f.corte_id
    LEFT JOIN dw.dim_causal AS dc ON dc.causal_id = f.causal_id
),
puntajes AS (
    SELECT
        b.*,
        ISNULL(b.avance_fisico, 0)                                        AS p_avance,
        100.0 * (1 - PERCENT_RANK() OVER (ORDER BY ISNULL(b.saldo_pendiente, 0))) AS p_saldo,
        100.0 * b.factor_resolucion                                       AS p_causal,
        100.0 * ISNULL(CAST(b.tiene_pim AS INT), 0)                       AS p_pim,
        100.0 * ISNULL(CAST(b.en_lista_priorizada AS INT), 0)             AS p_lista
    FROM base AS b
)
SELECT
    p.corte_id,
    p.codigo_infobras,
    o.cui,
    o.descripcion_obra,
    du.departamento, du.provincia, du.distrito, du.ubicacion_mapa,
    de.entidad, de.nivel_gobierno,
    dc.grupo_causal, dc.causal_descripcion,
    p.avance_fisico,
    p.saldo_pendiente,
    p.costo_referencia,
    p.tiene_pim,
    p.en_lista_priorizada,
    p.flag_dato_sospechoso,
    CAST(0.40 * p.p_avance + 0.25 * p.p_saldo + 0.15 * p.p_causal
       + 0.15 * p.p_pim    + 0.05 * p.p_lista AS DECIMAL(5,1))             AS indice_prioridad,
    RANK() OVER (ORDER BY 0.40 * p.p_avance + 0.25 * p.p_saldo + 0.15 * p.p_causal
                        + 0.15 * p.p_pim    + 0.05 * p.p_lista DESC)        AS ranking
FROM puntajes            AS p
JOIN dw.dim_obra         AS o  ON o.codigo_infobras = p.codigo_infobras
JOIN dw.dim_ubicacion    AS du ON du.ubicacion_id   = p.ubicacion_id
JOIN dw.dim_entidad      AS de ON de.entidad_id     = p.entidad_id
LEFT JOIN dw.dim_causal  AS dc ON dc.causal_id      = p.causal_id;
GO

PRINT N'Script 04 OK: vistas de análisis creadas.';
