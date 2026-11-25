/* =====================================================================
   SCRIPT 02: Carga de los 4 cortes trimestrales (CSV -> stg.obras_raw)
   ---------------------------------------------------------------------
   ANTES DE EJECUTAR: copia los 4 CSV a la carpeta indicada en @ruta.
   Se usa C:\Users\Public porque el servicio de SQL Server puede leerla
   sin configurar permisos. Si cambias la carpeta, cambia @ruta.
   ===================================================================== */
USE ObrasParalizadas;
GO

DECLARE @ruta NVARCHAR(300) = N'C:\Users\Public\ObrasParalizadas\data\';

DECLARE @a1 NVARCHAR(400) = @ruta + N'obras_2025_09.csv',
        @a2 NVARCHAR(400) = @ruta + N'obras_2025_12.csv',
        @a3 NVARCHAR(400) = @ruta + N'obras_2026_03.csv',
        @a4 NVARCHAR(400) = @ruta + N'obras_2026_06.csv';

-- corte_id va en orden cronológico (se usa para comparar trimestres)
EXEC stg.usp_cargar_corte @corte_id = 1, @archivo = @a1;   -- Setiembre 2025
EXEC stg.usp_cargar_corte @corte_id = 2, @archivo = @a2;   -- Diciembre 2025
EXEC stg.usp_cargar_corte @corte_id = 3, @archivo = @a3;   -- Marzo 2026
EXEC stg.usp_cargar_corte @corte_id = 4, @archivo = @a4;   -- Junio 2026
GO

-- Control: deben salir 2215 / 2416 / 2241 / 2262 filas
SELECT corte_id, COUNT(*) AS filas
FROM   stg.obras_raw
GROUP  BY corte_id
ORDER  BY corte_id;
