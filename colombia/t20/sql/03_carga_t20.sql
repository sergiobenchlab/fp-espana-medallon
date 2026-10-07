-- =============================================================================
-- 03_carga_t20.sql
-- Carga del T20 en intermediate y gold, en una sola transaccion.
--
-- Entrada: los CSV que deja preparar_t20.py (UTF-8 sin BOM, separador coma).
-- Ejecutar desde la carpeta de salida para que \copy encuentre los archivos:
--
--     cd salida
--     psql -v ON_ERROR_STOP=1 -f ../sql/03_carga_t20.sql
--
-- Idempotente: vacia intermediate y gold antes de insertar.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Staging en tablas temporales, con la forma de los CSV
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE tmp_cuentas (
    id_cnt integer, codigo_cuenta text, nombre_cuenta text,
    grp_1 text, grp_2 text, tipo text, codigo_padre text
) ON COMMIT DROP;

CREATE TEMP TABLE tmp_fact (
    id_ies integer, anio integer, codigo_cuenta text, valor numeric(20,2)
) ON COMMIT DROP;

\copy tmp_cuentas FROM 'cuentas_carga.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy tmp_fact    FROM 't20_fact_carga.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- -----------------------------------------------------------------------------
-- 2. Intermediate: resolver claves enteras
-- -----------------------------------------------------------------------------
TRUNCATE intermediate.co_dim_cuenta_financiera, intermediate.co_fact_t20_financiero;

INSERT INTO intermediate.co_dim_cuenta_financiera
SELECT c.id_cnt, c.codigo_cuenta, c.nombre_cuenta, c.grp_1, c.grp_2, c.tipo,
       pa.id_cnt
FROM   tmp_cuentas c
LEFT   JOIN tmp_cuentas pa ON pa.codigo_cuenta = c.codigo_padre;

-- Cada anio va al periodo que contiene el corte del 31 de diciembre: el de
-- fecha de inicio mas reciente dentro del anio (el segundo semestre).
INSERT INTO intermediate.co_fact_t20_financiero
SELECT p.id_prd, t.id_ies, c.id_cnt, t.valor
FROM   tmp_fact t
JOIN   intermediate.co_dim_cuenta_financiera c ON c.codigo_cuenta = t.codigo_cuenta
JOIN  (SELECT DISTINCT ON (anio) anio, id_prd
       FROM   colombia.periodo
       ORDER  BY anio, fch_inc_prd DESC) p ON p.anio = t.anio;

-- Ninguna fila se pierde al resolver claves
DO $$
DECLARE
    n_csv  bigint := (SELECT count(*) FROM tmp_fact);
    n_int  bigint := (SELECT count(*) FROM intermediate.co_fact_t20_financiero);
    padres bigint := (SELECT count(*) FROM tmp_cuentas c
                      WHERE c.codigo_padre IS NOT NULL
                        AND NOT EXISTS (SELECT 1 FROM tmp_cuentas p
                                        WHERE p.codigo_cuenta = c.codigo_padre));
BEGIN
    IF padres > 0 THEN
        RAISE EXCEPTION 'Cuentas con codigo_padre inexistente: %', padres;
    END IF;
    IF n_csv <> n_int THEN
        RAISE EXCEPTION 'Filas sin periodo o sin cuenta: CSV %, intermediate %', n_csv, n_int;
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 3. Gold. Catalogo por niveles de jerarquia: padres antes que hijos.
-- -----------------------------------------------------------------------------
TRUNCATE colombia.fact_t20_financiero, colombia.dim_cuenta_financiera;

INSERT INTO colombia.dim_cuenta_financiera
WITH RECURSIVE nivel AS (
    SELECT id_cnt, 0 AS n
    FROM   intermediate.co_dim_cuenta_financiera
    WHERE  id_cnt_padre IS NULL
    UNION ALL
    SELECT h.id_cnt, nivel.n + 1
    FROM   intermediate.co_dim_cuenta_financiera h
    JOIN   nivel ON h.id_cnt_padre = nivel.id_cnt
)
SELECT c.id_cnt, c.codigo_cuenta, c.nombre_cuenta, c.grp_1, c.grp_2, c.tipo, c.id_cnt_padre
FROM   intermediate.co_dim_cuenta_financiera c
JOIN   nivel USING (id_cnt)
ORDER  BY nivel.n, c.id_cnt;

INSERT INTO colombia.fact_t20_financiero (id_prd, id_ies, id_cnt, valor)
SELECT id_prd, id_ies, id_cnt, valor
FROM   intermediate.co_fact_t20_financiero;

COMMIT;

-- Resumen de la carga
SELECT 'dim_cuenta_financiera' AS tabla, count(*) AS filas FROM colombia.dim_cuenta_financiera
UNION ALL
SELECT 'fact_t20_financiero', count(*) FROM colombia.fact_t20_financiero
UNION ALL
SELECT 'vw_t20_comparativos', count(*) FROM colombia.vw_t20_comparativos;
