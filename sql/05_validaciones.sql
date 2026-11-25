/* =====================================================================
   SCRIPT 05: Validaciones de calidad (ejecutar al final)
   Cada consulta indica el resultado esperado.
   ===================================================================== */
USE ObrasParalizadas;
GO

-- V1. Filas por corte: staging vs. hechos (deben ser iguales)
--     Esperado: 2215 / 2416 / 2241 / 2262
SELECT r.corte_id, r.filas_stg, f.filas_dw,
       CASE WHEN r.filas_stg = f.filas_dw THEN 'OK' ELSE 'REVISAR' END AS estado
FROM (SELECT corte_id, COUNT(*) AS filas_stg FROM stg.obras_raw GROUP BY corte_id) r
LEFT JOIN (SELECT corte_id, COUNT(*) AS filas_dw FROM dw.fact_obra_corte GROUP BY corte_id) f
       ON f.corte_id = r.corte_id
ORDER BY r.corte_id;

-- V2. Obras sin causal reconocida (esperado: 0)
SELECT COUNT(*) AS obras_sin_causal FROM dw.fact_obra_corte WHERE causal_id IS NULL;

-- V3. Catálogo de causales limpio (esperado: 16 filas, sin duplicados por espacios)
SELECT * FROM dw.dim_causal ORDER BY causal_codigo;

-- V4. Valores fuera de rango (esperado: 0 en ambas columnas)
SELECT SUM(CASE WHEN avance_fisico NOT BETWEEN 0 AND 100 THEN 1 ELSE 0 END) AS avance_fuera_rango,
       SUM(CASE WHEN costo_referencia < 0 THEN 1 ELSE 0 END)                AS costo_negativo
FROM dw.fact_obra_corte;

-- V5. Datos que la limpieza convirtió en NULL (para documentar en el informe)
SELECT corte_id,
       SUM(CASE WHEN avance_fisico   IS NULL THEN 1 ELSE 0 END) AS sin_avance,
       SUM(CASE WHEN saldo_inversion IS NULL THEN 1 ELSE 0 END) AS sin_saldo_inversion,
       SUM(CAST(flag_dato_sospechoso AS INT))                    AS datos_sospechosos
FROM dw.fact_obra_corte GROUP BY corte_id ORDER BY corte_id;

SELECT COUNT(*) AS obras_sin_anio_inicio FROM dw.dim_obra WHERE anio_inicio IS NULL;
SELECT COUNT(*) AS obras_sin_cui         FROM dw.dim_obra WHERE cui IS NULL;

-- V6. Cuadre con la fuente: inversión total jun-2026 (costo actualizado)
--     Esperado: ~62,828.6 millones de soles
SELECT CAST(SUM(costo_actualizado) / 1e6 AS DECIMAL(12,1)) AS costo_actualizado_millones
FROM dw.fact_obra_corte WHERE corte_id = 4;

-- V7. Resultados principales
--     Referencia (calculado en paralelo con Python para verificar el SQL):
--     % obras con avance > 50 %: 55.9 / 56.6 / 57.0 / 57.5
--     Tasa de salida con PIM = 16.9 %  vs  sin PIM = 7.6 %
SELECT * FROM dw.vw_resumen_corte ORDER BY corte_id;
SELECT * FROM dw.vw_tasa_salida_por_factor ORDER BY factor, tasa_salida_pct DESC;
SELECT TOP (20) * FROM dw.vw_indice_priorizacion ORDER BY ranking;
