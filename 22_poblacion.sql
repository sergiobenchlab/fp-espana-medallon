-- =============================================================================
-- 22_poblacion.sql
-- Tabla base tipada y normalizada de matriculados.
-- Equivalente a la "Base Maestra" del pipeline anterior.
--
-- Las filas no normalizables van a silver.rechazos, no se descartan.
-- =============================================================================

DROP TABLE IF EXISTS silver.poblacion CASCADE;

CREATE TABLE silver.poblacion AS
SELECT
    silver.normaliza_curso(b.curso_academico)         AS curso_academico,
    coalesce(a.cod_ccaa, '99')                        AS cod_ccaa,
    trim(b.provincia)                                 AS nom_provincia,
    trim(b.familia_profesional)                       AS nom_familia,
    CASE silver.normaliza_texto(b.grado)
        WHEN 'BASICA'          THEN 'Básica'
        WHEN 'FP BASICA'       THEN 'Básica'
        WHEN 'GRADO MEDIO'     THEN 'Grado Medio'
        WHEN 'MEDIO'           THEN 'Grado Medio'
        WHEN 'GRADO SUPERIOR'  THEN 'Grado Superior'
        WHEN 'SUPERIOR'        THEN 'Grado Superior'
        ELSE 'No informado'
    END                                               AS nom_grado,
    trim(b.ciclo_formativo)                           AS nom_ciclo,
    CASE silver.normaliza_texto(b.modalidad)
        WHEN 'PRESENCIAL'      THEN 'Presencial'
        WHEN 'DISTANCIA'       THEN 'Distancia'
        WHEN 'A DISTANCIA'     THEN 'Distancia'
        WHEN 'DUAL'            THEN 'Dual'
        ELSE 'No informado'
    END                                               AS nom_modalidad,
    CASE silver.normaliza_texto(b.titularidad)
        WHEN 'PUBLICA'         THEN 'Pública'
        WHEN 'PRIVADA'         THEN 'Privada'
        WHEN 'PRIVADA CONCERTADA' THEN 'Privada concertada'
        ELSE 'No informado'
    END                                               AS nom_titularidad,
    CASE silver.normaliza_texto(b.sexo)
        WHEN 'HOMBRES'         THEN 'Hombres'
        WHEN 'HOMBRE'          THEN 'Hombres'
        WHEN 'MUJERES'         THEN 'Mujeres'
        WHEN 'MUJER'           THEN 'Mujeres'
        WHEN 'AMBOS SEXOS'     THEN 'Ambos sexos'
        WHEN 'TOTAL'           THEN 'Ambos sexos'
        ELSE 'No informado'
    END                                               AS nom_sexo,
    coalesce(nullif(trim(b.tramo_edad), ''), 'No informado') AS nom_tramo_edad,
    silver.a_numero(b.num_matriculados)::integer      AS num_matriculados,
    b._fuente,
    b._fichero_origen,
    b._fila_origen
FROM   bronze.educabase_matriculados b
LEFT   JOIN silver.alias_territorio a
       ON a.variante_normalizada = silver.normaliza_texto(b.comunidad_autonoma)
WHERE  silver.a_numero(b.num_matriculados) IS NOT NULL
  AND  silver.normaliza_curso(b.curso_academico) IS NOT NULL;

ALTER TABLE silver.poblacion
    ADD CONSTRAINT ck_poblacion_matriculados_no_negativo
    CHECK (num_matriculados >= 0);

CREATE INDEX idx_poblacion_curso    ON silver.poblacion (curso_academico);
CREATE INDEX idx_poblacion_ccaa     ON silver.poblacion (cod_ccaa);
CREATE INDEX idx_poblacion_familia  ON silver.poblacion (nom_familia);

-- -----------------------------------------------------------------------------
-- Registro de rechazos
-- -----------------------------------------------------------------------------
DELETE FROM silver.rechazos WHERE tabla_origen = 'bronze.educabase_matriculados';

INSERT INTO silver.rechazos (tabla_origen, fila_origen, motivo, contenido)
SELECT 'bronze.educabase_matriculados',
       b._fila_origen,
       CASE
           WHEN silver.a_numero(b.num_matriculados) IS NULL
               THEN 'num_matriculados no convertible a número'
           WHEN silver.normaliza_curso(b.curso_academico) IS NULL
               THEN 'curso_academico no interpretable'
           ELSE 'motivo no clasificado'
       END,
       to_jsonb(b)
FROM   bronze.educabase_matriculados b
WHERE  silver.a_numero(b.num_matriculados) IS NULL
   OR  silver.normaliza_curso(b.curso_academico) IS NULL;

-- -----------------------------------------------------------------------------
-- Control
-- -----------------------------------------------------------------------------
SELECT (SELECT count(*) FROM bronze.educabase_matriculados) AS filas_bronze,
       (SELECT count(*) FROM silver.poblacion)              AS filas_silver,
       (SELECT count(*) FROM silver.rechazos
        WHERE tabla_origen = 'bronze.educabase_matriculados') AS filas_rechazadas,
       (SELECT count(*) FROM silver.poblacion
        WHERE cod_ccaa = '99')                              AS ccaa_sin_mapear;
