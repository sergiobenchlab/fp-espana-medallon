-- =============================================================================
-- 35_fact_poblacion.sql
-- Tabla de hechos. Grano:
--   curso × territorio × programa × modalidad × titularidad × sexo × edad
--
-- Toda clave foránea resuelve: si no hay match, va a -1 ('No informado').
-- Nunca hay NULL en una FK, porque Power BI descartaría esas filas en silencio.
-- =============================================================================

DROP TABLE IF EXISTS gold.fact_poblacion CASCADE;

CREATE TABLE gold.fact_poblacion AS
SELECT
    coalesce(t.sk_tiempo,       -1) AS sk_tiempo,
    coalesce(te.sk_territorio,  -1) AS sk_territorio,
    coalesce(pr.sk_programa,    -1) AS sk_programa,
    coalesce(fa.sk_familia,     -1) AS sk_familia,
    coalesce(mo.sk_modalidad,   -1) AS sk_modalidad,
    coalesce(ti.sk_titularidad, -1) AS sk_titularidad,
    coalesce(se.sk_sexo,        -1) AS sk_sexo,
    coalesce(ed.sk_edad,        -1) AS sk_edad,
    p.num_matriculados
FROM   silver.poblacion p
LEFT   JOIN gold.dim_tiempo      t  ON t.curso_academico   = p.curso_academico
LEFT   JOIN gold.dim_territorio  te ON te.cod_ccaa         = p.cod_ccaa
LEFT   JOIN gold.dim_familia     fa ON fa.nom_familia      = p.nom_familia
LEFT   JOIN gold.dim_programa    pr ON pr.nom_ciclo        = coalesce(nullif(trim(p.nom_ciclo), ''), 'No informado')
                                   AND pr.nom_grado        = p.nom_grado
                                   AND pr.sk_familia       = coalesce(fa.sk_familia, -1)
LEFT   JOIN gold.dim_modalidad   mo ON mo.nom_modalidad    = p.nom_modalidad
LEFT   JOIN gold.dim_titularidad ti ON ti.nom_titularidad  = p.nom_titularidad
LEFT   JOIN gold.dim_sexo        se ON se.nom_sexo         = p.nom_sexo
LEFT   JOIN gold.dim_edad        ed ON ed.nom_tramo_edad   = p.nom_tramo_edad;

-- Claves foráneas
ALTER TABLE gold.fact_poblacion
    ADD CONSTRAINT fk_fact_tiempo      FOREIGN KEY (sk_tiempo)      REFERENCES gold.dim_tiempo,
    ADD CONSTRAINT fk_fact_territorio  FOREIGN KEY (sk_territorio)  REFERENCES gold.dim_territorio,
    ADD CONSTRAINT fk_fact_programa    FOREIGN KEY (sk_programa)    REFERENCES gold.dim_programa,
    ADD CONSTRAINT fk_fact_familia     FOREIGN KEY (sk_familia)     REFERENCES gold.dim_familia,
    ADD CONSTRAINT fk_fact_modalidad   FOREIGN KEY (sk_modalidad)   REFERENCES gold.dim_modalidad,
    ADD CONSTRAINT fk_fact_titularidad FOREIGN KEY (sk_titularidad) REFERENCES gold.dim_titularidad,
    ADD CONSTRAINT fk_fact_sexo        FOREIGN KEY (sk_sexo)        REFERENCES gold.dim_sexo,
    ADD CONSTRAINT fk_fact_edad        FOREIGN KEY (sk_edad)        REFERENCES gold.dim_edad;

CREATE INDEX idx_fact_tiempo     ON gold.fact_poblacion (sk_tiempo);
CREATE INDEX idx_fact_territorio ON gold.fact_poblacion (sk_territorio);
CREATE INDEX idx_fact_programa   ON gold.fact_poblacion (sk_programa);
CREATE INDEX idx_fact_familia    ON gold.fact_poblacion (sk_familia);

SELECT count(*)                AS filas_hecho,
       sum(num_matriculados)   AS total_matriculados
FROM   gold.fact_poblacion;
