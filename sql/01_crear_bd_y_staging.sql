/* =====================================================================
   PROYECTO : ¿Por qué el Perú no termina sus obras?
              Análisis de obras públicas paralizadas (Contraloría General)
   SCRIPT 01: Base de datos, esquemas y tablas de staging
   MOTOR    : SQL Server 2017 o superior (probado para Express 2019/2022)
   AUTOR    : Oscar Zarate
   ---------------------------------------------------------------------
   Esquemas:
     stg -> datos crudos tal como vienen del Excel (todo texto)
     dw  -> modelo estrella limpio, listo para Power BI
   ===================================================================== */

IF DB_ID(N'ObrasParalizadas') IS NULL
    CREATE DATABASE ObrasParalizadas;
GO

USE ObrasParalizadas;
GO

IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dw')  IS NULL EXEC(N'CREATE SCHEMA dw');
GO

/* ---------------------------------------------------------------------
   stg.carga : tabla "puente" que recibe un CSV a la vez (BULK INSERT).
   Todas las columnas son texto para que la carga NUNCA falle por un
   valor raro (ej. "No declarado" en el año). La limpieza se hace después.
   El orden de columnas debe coincidir EXACTAMENTE con el CSV.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg.carga;
CREATE TABLE stg.carga (
    n                            NVARCHAR(50),
    codigo_infobras              NVARCHAR(50),
    cui                          NVARCHAR(50),
    descripcion_inversion        NVARCHAR(1000),
    snip                         NVARCHAR(50),
    descripcion_obra             NVARCHAR(1000),
    entidad                      NVARCHAR(300),
    evento                       NVARCHAR(100),
    modalidad_ejecucion          NVARCHAR(100),
    costo_obra_exp_tec           NVARCHAR(50),
    saldo_obra                   NVARCHAR(50),
    costo_actualizado            NVARCHAR(50),
    rango_inversion              NVARCHAR(100),
    saldo_inversion              NVARCHAR(50),
    pim_anio                     NVARCHAR(50),
    tiene_pim                    NVARCHAR(20),
    tipo_obra_n1                 NVARCHAR(200),
    tipo_obra_n2                 NVARCHAR(200),
    tipo_obra_n3                 NVARCHAR(200),
    departamento                 NVARCHAR(100),
    provincia                    NVARCHAR(100),
    distrito                     NVARCHAR(100),
    anio_inicio_obra             NVARCHAR(50),
    plazo_ejecucion              NVARCHAR(50),
    avance_fisico                NVARCHAR(50),
    rango_avance_fisico          NVARCHAR(50),
    nivel_gobierno               NVARCHAR(50),
    sector                       NVARCHAR(200),
    causal_paralizacion          NVARCHAR(300),
    unidad_organica              NVARCHAR(300),
    en_inventario_mef            NVARCHAR(20),
    fecha_registro_inventario    NVARCHAR(50),
    tiene_informe_situacional    NVARCHAR(20),
    fecha_informe_situacional    NVARCHAR(50),
    url_informe                  NVARCHAR(500),
    en_lista_priorizada          NVARCHAR(20),
    fecha_resolucion_priorizada  NVARCHAR(50),
    url_resolucion               NVARCHAR(500),
    ult_avance_mes               NVARCHAR(20),
    ult_avance_anio              NVARCHAR(20),
    aplica_ley_31589             NVARCHAR(20)
);
GO

/* ---------------------------------------------------------------------
   stg.obras_raw : histórico de todos los cortes cargados.
   Misma estructura que stg.carga + el corte al que pertenece cada fila.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS stg.obras_raw;
SELECT TOP (0)
       CAST(NULL AS INT) AS corte_id,
       c.*,
       CAST(NULL AS DATETIME2(0)) AS fecha_carga
INTO   stg.obras_raw
FROM   stg.carga AS c;
GO
ALTER TABLE stg.obras_raw ALTER COLUMN corte_id INT NOT NULL;
GO

/* ---------------------------------------------------------------------
   Función de limpieza básica: quita espacios y convierte en NULL los
   valores "vacíos" que usa la Contraloría ('', ' ', '-').
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION stg.fn_limpio (@valor NVARCHAR(1000))
RETURNS NVARCHAR(1000)
WITH INLINE = OFF   -- evita que SQL Server 2019+ la "incruste" y genere planes enormes
AS
BEGIN
    DECLARE @v NVARCHAR(1000) = LTRIM(RTRIM(REPLACE(@valor, NCHAR(160), N' ')));
    RETURN CASE WHEN @v IN (N'', N'-') THEN NULL ELSE @v END;
END;
GO

/* ---------------------------------------------------------------------
   Procedimiento de carga de un corte.
   Uso: EXEC stg.usp_cargar_corte @corte_id = 4,
             @archivo = N'C:\Users\Public\ObrasParalizadas\data\obras_2026_06.csv';
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_cargar_corte
    @corte_id INT,
    @archivo  NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE stg.carga;

    DECLARE @sql NVARCHAR(MAX) =
        N'BULK INSERT stg.carga FROM ''' + REPLACE(@archivo, N'''', N'''''') + N'''
          WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'',
                FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0d0a'',
                CODEPAGE = ''65001'', TABLOCK);';
    EXEC sys.sp_executesql @sql;

    BEGIN TRANSACTION;
        DELETE FROM stg.obras_raw WHERE corte_id = @corte_id;   -- recarga idempotente

        INSERT INTO stg.obras_raw
        SELECT @corte_id, c.*, SYSDATETIME()
        FROM   stg.carga AS c;

        DECLARE @filas INT = @@ROWCOUNT;
    COMMIT TRANSACTION;

    SELECT @corte_id AS corte_id, @archivo AS archivo, @filas AS filas_cargadas;
END;
GO

PRINT N'Script 01 OK: base de datos, staging, función y procedimiento creados.';
