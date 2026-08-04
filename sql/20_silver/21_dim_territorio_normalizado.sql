-- =============================================================================
-- 21_dim_territorio_normalizado.sql
-- Normaliza los nombres de CCAA y provincia contra el catálogo INE.
-- Las variantes de nombre de las fuentes se resuelven con una tabla de alias.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Alias conocidos: variantes de escritura → nombre canónico INE
-- Ampliar según aparezcan nuevas variantes en las cargas
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.alias_territorio CASCADE;

CREATE TABLE silver.alias_territorio (
    variante_normalizada text PRIMARY KEY,
    cod_ccaa             text NOT NULL
);

INSERT INTO silver.alias_territorio (variante_normalizada, cod_ccaa) VALUES
    ('ANDALUCIA',                    '01'),
    ('ARAGON',                       '02'),
    ('ASTURIAS',                     '03'),
    ('ASTURIAS PRINCIPADO DE',       '03'),
    ('PRINCIPADO DE ASTURIAS',       '03'),
    ('BALEARS ILLES',                '04'),
    ('ILLES BALEARS',                '04'),
    ('BALEARES',                     '04'),
    ('CANARIAS',                     '05'),
    ('CANTABRIA',                    '06'),
    ('CASTILLA Y LEON',              '07'),
    ('CASTILLA - LA MANCHA',         '08'),
    ('CASTILLA-LA MANCHA',           '08'),
    ('CATALUNA',                     '09'),
    ('CATALUNYA',                    '09'),
    ('COMUNITAT VALENCIANA',         '10'),
    ('COMUNIDAD VALENCIANA',         '10'),
    ('EXTREMADURA',                  '11'),
    ('GALICIA',                      '12'),
    ('MADRID',                       '13'),
    ('MADRID COMUNIDAD DE',          '13'),
    ('COMUNIDAD DE MADRID',          '13'),
    ('MURCIA',                       '14'),
    ('MURCIA REGION DE',             '14'),
    ('REGION DE MURCIA',             '14'),
    ('NAVARRA',                      '15'),
    ('NAVARRA COMUNIDAD FORAL DE',   '15'),
    ('COMUNIDAD FORAL DE NAVARRA',   '15'),
    ('PAIS VASCO',                   '16'),
    ('EUSKADI',                      '16'),
    ('RIOJA LA',                     '17'),
    ('LA RIOJA',                     '17'),
    ('CEUTA',                        '18'),
    ('MELILLA',                      '19'),
    ('TOTAL',                        '00'),
    ('TOTAL NACIONAL',               '00'),
    ('ESPANA',                       '00');

-- -----------------------------------------------------------------------------
-- Catálogo canónico de CCAA
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.territorio CASCADE;

CREATE TABLE silver.territorio (
    cod_ccaa  text PRIMARY KEY,
    nom_ccaa  text NOT NULL
);

INSERT INTO silver.territorio (cod_ccaa, nom_ccaa) VALUES
    ('00', 'Total Nacional'),
    ('01', 'Andalucía'),
    ('02', 'Aragón'),
    ('03', 'Asturias, Principado de'),
    ('04', 'Balears, Illes'),
    ('05', 'Canarias'),
    ('06', 'Cantabria'),
    ('07', 'Castilla y León'),
    ('08', 'Castilla - La Mancha'),
    ('09', 'Cataluña'),
    ('10', 'Comunitat Valenciana'),
    ('11', 'Extremadura'),
    ('12', 'Galicia'),
    ('13', 'Madrid, Comunidad de'),
    ('14', 'Murcia, Región de'),
    ('15', 'Navarra, Comunidad Foral de'),
    ('16', 'País Vasco'),
    ('17', 'Rioja, La'),
    ('18', 'Ceuta'),
    ('19', 'Melilla');

-- -----------------------------------------------------------------------------
-- Control: variantes presentes en bronze que NO están en la tabla de alias.
-- Si esta consulta devuelve filas, hay que añadirlas arriba antes de seguir.
-- -----------------------------------------------------------------------------
SELECT DISTINCT
       b.comunidad_autonoma                        AS variante_original,
       silver.normaliza_texto(b.comunidad_autonoma) AS variante_normalizada,
       count(*) OVER (PARTITION BY b.comunidad_autonoma) AS filas_afectadas
FROM   bronze.educabase_matriculados b
LEFT   JOIN silver.alias_territorio a
       ON a.variante_normalizada = silver.normaliza_texto(b.comunidad_autonoma)
WHERE  a.cod_ccaa IS NULL
  AND  b.comunidad_autonoma IS NOT NULL
ORDER  BY filas_afectadas DESC;
