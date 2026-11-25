/* =====================================================================
   PARCHE DE RENDIMIENTO (ejecutar una sola vez, antes de repetir el 03)
   Desactiva el "inlining" de la función de limpieza en SQL Server 2019+.
   ===================================================================== */
USE ObrasParalizadas;
GO

CREATE OR ALTER FUNCTION stg.fn_limpio (@valor NVARCHAR(1000))
RETURNS NVARCHAR(1000)
WITH INLINE = OFF
AS
BEGIN
    DECLARE @v NVARCHAR(1000) = LTRIM(RTRIM(REPLACE(@valor, NCHAR(160), N' ')));
    RETURN CASE WHEN @v IN (N'', N'-') THEN NULL ELSE @v END;
END;
GO

PRINT N'Parche OK: ahora ejecuta el script 03 corregido.';
