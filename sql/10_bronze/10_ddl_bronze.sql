-- =============================================================================
-- 10_ddl_bronze.sql
-- Estructuras de la capa bronze.
--
-- REGLA: todas las columnas de negocio son TEXT. No se castea en la ingesta.
-- Las celdas con '..', '-', 'n.d.', separadores de miles, etc. se conservan
-- literales y se traducen en silver dejando constancia.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- EDUCAbase — matriculados por CCAA, familia profesional y grado
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.educabase_matriculados CASCADE;

CREATE TABLE bronze.educabase_matriculados (
    curso_academico     text,
    comunidad_autonoma  text,
    provincia           text,
    familia_profesional text,
    grado               text,   -- Básica / Grado Medio / Grado Superior
    ciclo_formativo     text,
    modalidad           text,
    titularidad         text,
    sexo                text,
    tramo_edad          text,
    num_matriculados    text,   -- TEXT a propósito

    -- Columnas de control
    _fuente             text NOT NULL DEFAULT 'EDUCABASE',
    _fichero_origen     text NOT NULL,
    _fecha_carga        timestamptz NOT NULL DEFAULT now(),
    _fila_origen        integer
);

COMMENT ON TABLE bronze.educabase_matriculados IS
    'Ingesta cruda EDUCAbase. Fuente autoritativa para totales de matriculados.';

-- -----------------------------------------------------------------------------
-- EDUCAbase — centros
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.educabase_centros CASCADE;

CREATE TABLE bronze.educabase_centros (
    curso_academico     text,
    comunidad_autonoma  text,
    provincia           text,
    titularidad         text,
    num_centros         text,

    _fuente             text NOT NULL DEFAULT 'EDUCABASE',
    _fichero_origen     text NOT NULL,
    _fecha_carga        timestamptz NOT NULL DEFAULT now(),
    _fila_origen        integer
);

-- -----------------------------------------------------------------------------
-- CaixaBank Dualiza — series agregadas
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.dualiza_series CASCADE;

CREATE TABLE bronze.dualiza_series (
    curso_academico     text,
    comunidad_autonoma  text,
    familia_profesional text,
    grado               text,
    indicador           text,
    valor               text,

    _fuente             text NOT NULL DEFAULT 'DUALIZA',
    _fichero_origen     text NOT NULL,
    _fecha_carga        timestamptz NOT NULL DEFAULT now(),
    _fila_origen        integer
);

COMMENT ON TABLE bronze.dualiza_series IS
    'Ingesta cruda CaixaBank Dualiza. Fuente COMPLEMENTARIA. Presenta inconsistencias '
    'internas <1% entre agregados CCAA y totales nacionales. No usar para totales.';

-- -----------------------------------------------------------------------------
-- Catálogo INE de territorios (referencia estable)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS bronze.cat_territorio_ine CASCADE;

CREATE TABLE bronze.cat_territorio_ine (
    cod_ccaa            text,
    nom_ccaa            text,
    cod_provincia       text,
    nom_provincia       text,

    _fichero_origen     text,
    _fecha_carga        timestamptz NOT NULL DEFAULT now()
);

-- Verificación
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'bronze'
ORDER  BY table_name;
