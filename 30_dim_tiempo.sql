-- =============================================================================
-- 30_dim_tiempo.sql
-- Dimensión de curso académico. Se genera desde los datos presentes en silver.
-- =============================================================================

DROP TABLE IF EXISTS gold.dim_tiempo CASCADE;

CREATE TABLE gold.dim_tiempo (
    sk_tiempo       integer PRIMARY KEY,
    curso_academico text    NOT NULL UNIQUE,
    anio_inicio     integer NOT NULL,
    anio_fin        integer NOT NULL,
    curso_corto     text    NOT NULL,
    es_ultimo       boolean NOT NULL DEFAULT false
);

INSERT INTO gold.dim_tiempo (sk_tiempo, curso_academico, anio_inicio, anio_fin, curso_corto)
SELECT DISTINCT
       split_part(curso_academico, '/', 1)::integer               AS sk_tiempo,
       curso_academico,
       split_part(curso_academico, '/', 1)::integer               AS anio_inicio,
       split_part(curso_academico, '/', 2)::integer               AS anio_fin,
       split_part(curso_academico, '/', 1) || '-' ||
           right(split_part(curso_academico, '/', 2), 2)          AS curso_corto
FROM   silver.poblacion
WHERE  curso_academico IS NOT NULL;

-- Miembro "No informado"
INSERT INTO gold.dim_tiempo (sk_tiempo, curso_academico, anio_inicio, anio_fin, curso_corto)
VALUES (-1, 'No informado', -1, -1, 'N/D');

-- Marca del curso más reciente (útil para medidas DAX de "último curso")
UPDATE gold.dim_tiempo
SET    es_ultimo = true
WHERE  sk_tiempo = (SELECT max(sk_tiempo) FROM gold.dim_tiempo WHERE sk_tiempo > 0);

SELECT * FROM gold.dim_tiempo ORDER BY sk_tiempo;
