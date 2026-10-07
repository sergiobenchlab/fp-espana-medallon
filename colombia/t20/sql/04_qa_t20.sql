-- =============================================================================
-- 04_qa_t20.sql
-- Controles posteriores a la carga. Replican en SQL la compuerta de
-- preparar_t20.py: despues de una carga limpia, los tres primeros devuelven 0
-- filas y el ultimo solo las observaciones ya conocidas.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Todo anio con datos tiene sus dos semestres en colombia.periodo. Si no,
--    la vista de comparativos devolveria filas de menos sin avisar.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW colombia.vw_t20_control_periodos AS
SELECT   pf.anio, count(DISTINCT p.id_prd) AS periodos_en_dimension
FROM     (SELECT DISTINCT id_prd FROM colombia.fact_t20_financiero) f
JOIN     colombia.periodo pf ON pf.id_prd = f.id_prd
LEFT JOIN colombia.periodo p ON p.anio = pf.anio
GROUP BY pf.anio
HAVING   count(DISTINCT p.id_prd) <> 2;

-- -----------------------------------------------------------------------------
-- 2. Identidad de balance por institucion y anio: Activo = Pasivo + Patrimonio.
--    Tolerancia relativa: los estados se publican en miles o millones, y la
--    reexpresion a pesos deja diferencias proporcionales al tamano.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW colombia.vw_t20_control_balance AS
WITH v AS (
    SELECT f.id_ies, p.anio,
           SUM(f.valor) FILTER (WHERE c.codigo_cuenta IN ('1000','2000')) AS activo,
           SUM(f.valor) FILTER (WHERE c.codigo_cuenta IN ('3000','4000')) AS pasivo,
           SUM(f.valor) FILTER (WHERE c.codigo_cuenta = '5000')           AS patrimonio
    FROM   colombia.fact_t20_financiero   f
    JOIN   colombia.dim_cuenta_financiera c ON c.id_cnt = f.id_cnt
    JOIN   colombia.periodo               p ON p.id_prd = f.id_prd
    GROUP  BY f.id_ies, p.anio
)
SELECT v.*,
       u.codigo_ies, u.nombre_ies,
       v.activo - coalesce(v.pasivo, 0) - coalesce(v.patrimonio, 0) AS diferencia,
       abs(v.activo - coalesce(v.pasivo, 0) - coalesce(v.patrimonio, 0))
           <= greatest(3, abs(v.activo) * 0.0001)                   AS balance_ok
FROM   v
JOIN   colombia.dim_universidades u ON u.id_ies = v.id_ies
WHERE  v.activo IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3. Signo. No hay CHECK de signo en la tabla porque varias cuentas son
--    negativas por naturaleza (8040, 5020, 5030, UN, 9010, reversiones de
--    deterioro). Becas y descuentos si tienen convencion fija: positivo, y se
--    restan de 6010. La compuerta lo normaliza; esto verifica que siga asi.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW colombia.vw_t20_control_signo AS
SELECT f.id_ies, p.anio, c.codigo_cuenta, c.nombre_cuenta, f.valor
FROM   colombia.fact_t20_financiero   f
JOIN   colombia.dim_cuenta_financiera c ON c.id_cnt = f.id_cnt
JOIN   colombia.periodo               p ON p.id_prd = f.id_prd
WHERE  f.valor < 0
  AND  c.codigo_cuenta IN ('6020','6021','6022','6023');

-- -----------------------------------------------------------------------------
-- Ejecucion
-- -----------------------------------------------------------------------------
SELECT 'periodos incompletos' AS control, count(*) AS filas FROM colombia.vw_t20_control_periodos
UNION ALL
SELECT 'balance > 1%',  count(*) FROM colombia.vw_t20_control_balance
WHERE  NOT balance_ok AND abs(diferencia) > abs(activo) * 0.01
UNION ALL
SELECT 'becas negativas', count(*) FROM colombia.vw_t20_control_signo
UNION ALL
SELECT 'balance fuera de tolerancia (observacion)', count(*) FROM colombia.vw_t20_control_balance
WHERE  NOT balance_ok;
