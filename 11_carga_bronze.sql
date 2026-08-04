-- =============================================================================
-- 11_carga_bronze.sql
-- Carga de ficheros a bronze.
--
-- Los XLSX de EDUCAbase/Dualiza deben convertirse antes a CSV UTF-8 con los
-- scripts de ingest/ (los encabezados multinivel de las tablas dinámicas no se
-- pueden leer directamente con COPY).
--
-- TRUNCATE antes de cargar: bronze se reconstruye completa, nunca se acumula.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Opción A — \copy desde cliente (DBeaver / psql local)
-- Ajustar las rutas a la ubicación local de data/raw
-- -----------------------------------------------------------------------------

TRUNCATE TABLE bronze.educabase_matriculados;

-- \copy bronze.educabase_matriculados (
--     curso_academico, comunidad_autonoma, provincia, familia_profesional,
--     grado, ciclo_formativo, modalidad, titularidad, sexo, tramo_edad,
--     num_matriculados, _fichero_origen, _fila_origen
-- )
-- FROM './data/raw/educabase_matriculados.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8', NULL '');


TRUNCATE TABLE bronze.dualiza_series;

-- \copy bronze.dualiza_series (
--     curso_academico, comunidad_autonoma, familia_profesional, grado,
--     indicador, valor, _fichero_origen, _fila_origen
-- )
-- FROM './data/raw/dualiza_series.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8', NULL '');


TRUNCATE TABLE bronze.cat_territorio_ine;

-- \copy bronze.cat_territorio_ine (
--     cod_ccaa, nom_ccaa, cod_provincia, nom_provincia, _fichero_origen
-- )
-- FROM './data/samples/cat_territorio_ine.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ';', ENCODING 'UTF8', NULL '');


-- -----------------------------------------------------------------------------
-- Nota sobre encoding
-- Los ficheros del Ministerio suelen venir en Windows-1252. Si aparecen
-- caracteres corruptos en 'Cataluña', 'Castilla y León', etc., convertir antes:
--     iconv -f WINDOWS-1252 -t UTF-8 entrada.csv > salida.csv
-- o usar ENCODING 'WIN1252' en el COPY.
-- -----------------------------------------------------------------------------


-- -----------------------------------------------------------------------------
-- Control de carga
-- -----------------------------------------------------------------------------
SELECT '_educabase_matriculados' AS tabla,
       count(*)                  AS filas,
       count(DISTINCT curso_academico) AS cursos,
       min(_fecha_carga)         AS cargado
FROM   bronze.educabase_matriculados

UNION ALL

SELECT 'dualiza_series',
       count(*),
       count(DISTINCT curso_academico),
       min(_fecha_carga)
FROM   bronze.dualiza_series

UNION ALL

SELECT 'cat_territorio_ine',
       count(*),
       NULL,
       min(_fecha_carga)
FROM   bronze.cat_territorio_ine;
