-- =============================================================================
-- 01_intermediate_t20.sql
-- Par en intermediate de las dos tablas gold del T20 (Estados Financieros).
-- Misma forma que gold, ya con claves enteras resueltas, sin constraints.
-- Idempotente.
-- =============================================================================

DROP TABLE IF EXISTS intermediate.co_fact_t20_financiero CASCADE;
DROP TABLE IF EXISTS intermediate.co_dim_cuenta_financiera CASCADE;

CREATE TABLE intermediate.co_dim_cuenta_financiera (
    id_cnt          integer,
    codigo_cuenta   varchar(10),
    nombre_cuenta   varchar(120),
    grp_1           varchar(60),
    grp_2           varchar(40),
    tipo            varchar(20),
    id_cnt_padre    integer
);

CREATE TABLE intermediate.co_fact_t20_financiero (
    id_prd          integer,
    id_ies          integer,
    id_cnt          integer,
    valor           numeric(20,2)
);
