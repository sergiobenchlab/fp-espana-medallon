-- =============================================================================
-- 31_dim_territorio.sql
-- Dimensión territorial (CCAA). Clave subrogada + código natural INE.
-- =============================================================================

DROP TABLE IF EXISTS gold.dim_territorio CASCADE;

CREATE TABLE gold.dim_territorio (
    sk_territorio integer PRIMARY KEY,
    cod_ccaa      text    NOT NULL UNIQUE,
    nom_ccaa      text    NOT NULL,
    es_total      boolean NOT NULL DEFAULT false
);

INSERT INTO gold.dim_territorio (sk_territorio, cod_ccaa, nom_ccaa, es_total)
SELECT cod_ccaa::integer,
       cod_ccaa,
       nom_ccaa,
       (cod_ccaa = '00')
FROM   silver.territorio;

-- Miembro "No informado" para las filas cuyo territorio no se pudo mapear
INSERT INTO gold.dim_territorio (sk_territorio, cod_ccaa, nom_ccaa)
VALUES (-1, '99', 'No informado');

SELECT * FROM gold.dim_territorio ORDER BY sk_territorio;
