-- =============================================================================
-- 02_gold_t20.sql
-- T20 Estados Financieros de las IES de Colombia, capa gold (schema colombia).
-- Idempotente: borra en orden inverso de dependencias y vuelve a crear.
--
-- Depende de dos tablas que ya existen en colombia:
--   colombia.dim_universidades (id_ies, codigo_ies, nombre_ies)
--   colombia.periodo           (id_prd, anio, fch_inc_prd)
-- =============================================================================

DROP VIEW  IF EXISTS colombia.vw_t20_comparativos CASCADE;
DROP TABLE IF EXISTS colombia.fact_t20_financiero CASCADE;
DROP TABLE IF EXISTS colombia.dim_cuenta_financiera CASCADE;

-- -----------------------------------------------------------------------------
-- 1. Catalogo de cuentas. Es el M20_CUENTAS de SharePoint, extendido.
--
--    Las 58 cuentas de detalle conservan id, nombre y grupos. Se agregan las 12
--    agregadas (1000, 5000, 6010...) y UN con ID_CNT 59 a 70, porque el estado
--    financiero publicado trae el total y hay instituciones que reportan solo el
--    total. G7010 (ID_CNT 71) es la unica cuenta fuera de plan.
--
--    GRP_1 y GRP_2 de las agregadas valen 'Agregado', no el grupo de sus hijas:
--    asi agrupar por GRP_1 y sumar no cuenta el total y sus componentes a la vez.
--
--    La jerarquia es una FK entera a la propia PK. No es DEFERRABLE: la carga
--    inserta los padres antes que los hijos (03_carga_t20.sql).
-- -----------------------------------------------------------------------------
CREATE TABLE colombia.dim_cuenta_financiera (
    id_cnt          integer      NOT NULL,
    codigo_cuenta   varchar(10)  NOT NULL,             -- CNT: 1010, C7080, UN
    nombre_cuenta   varchar(120) NOT NULL,
    grp_1           varchar(60)  NOT NULL,
    grp_2           varchar(40)  NOT NULL,
    tipo            varchar(20)  NOT NULL,
    id_cnt_padre    integer,
    CONSTRAINT pk_dim_cuenta_financiera        PRIMARY KEY (id_cnt),
    CONSTRAINT uq_dim_cuenta_financiera_codigo UNIQUE (codigo_cuenta),
    CONSTRAINT chk_dim_cuenta_financiera_tipo
        CHECK (tipo IN ('Detalle', 'Agregado', 'Fuera de plan')),
    CONSTRAINT fk_dim_cuenta_financiera_padre
        FOREIGN KEY (id_cnt_padre) REFERENCES colombia.dim_cuenta_financiera (id_cnt)
);

COMMENT ON COLUMN colombia.dim_cuenta_financiera.tipo IS
  'Detalle suma sin duplicar. Agregado es el total publicado. Al sumar, filtrar por tipo.';

-- -----------------------------------------------------------------------------
-- 2. Tabla de hechos.
--    Grano: institucion x periodo x cuenta. La PK son las tres FK enteras.
--
--    El estado financiero es anual con corte al 31 de diciembre, asi que cada
--    anio se registra una sola vez, en el periodo que contiene esa fecha (el
--    segundo semestre). La duplicacion por semestre la hace la vista.
--
--    Sin columnas de trazabilidad: la fuente va en raw y la verificacion
--    contable es la compuerta de calidad (preparar_t20.py), no un atributo
--    del hecho.
-- -----------------------------------------------------------------------------
CREATE TABLE colombia.fact_t20_financiero (
    id_prd          integer       NOT NULL,
    id_ies          integer       NOT NULL,
    id_cnt          integer       NOT NULL,
    valor           numeric(20,2),                    -- NULL = la institucion no reporta la cuenta
    CONSTRAINT pk_fact_t20_financiero PRIMARY KEY (id_prd, id_ies, id_cnt),
    CONSTRAINT fk_fact_t20_financiero_periodo
        FOREIGN KEY (id_prd) REFERENCES colombia.periodo (id_prd),
    CONSTRAINT fk_fact_t20_financiero_ies
        FOREIGN KEY (id_ies) REFERENCES colombia.dim_universidades (id_ies),
    CONSTRAINT fk_fact_t20_financiero_cuenta
        FOREIGN KEY (id_cnt) REFERENCES colombia.dim_cuenta_financiera (id_cnt)
);

-- La PK ya cubre las consultas que empiezan por periodo.
CREATE INDEX idx_co_fact_t20_financiero_ies    ON colombia.fact_t20_financiero (id_ies, id_prd);
CREATE INDEX idx_co_fact_t20_financiero_cuenta ON colombia.fact_t20_financiero (id_cnt, id_prd);

-- -----------------------------------------------------------------------------
-- 3. Vista de compatibilidad: reproduce el Comparativos que consume Power BI.
--
--    Los informes cruzan este dato con estudiantes, que son semestrales, asi
--    que el valor anual tiene que aparecer en los dos periodos del anio. Se
--    genera aqui en vez de escribirlo dos veces: el Comparativos anterior tenia
--    3.361 combinaciones de 2024 con un solo semestre cargado.
-- -----------------------------------------------------------------------------
CREATE VIEW colombia.vw_t20_comparativos AS
SELECT  f.id_ies,
        p.id_prd,
        u.codigo_ies        AS cdg_ies_pdr,
        p.anio              AS an,
        c.codigo_cuenta     AS cnt,
        f.valor             AS amnt,
        p.fch_inc_prd
FROM    colombia.fact_t20_financiero   f
JOIN    colombia.periodo               pf ON pf.id_prd = f.id_prd      -- periodo de registro
JOIN    colombia.periodo               p  ON p.anio    = pf.anio       -- los dos semestres del anio
JOIN    colombia.dim_universidades     u  ON u.id_ies  = f.id_ies
JOIN    colombia.dim_cuenta_financiera c  ON c.id_cnt  = f.id_cnt;
