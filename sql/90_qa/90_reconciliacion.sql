-- =============================================================================
-- 90_reconciliacion.sql
-- Controles de calidad. Ejecutar SIEMPRE antes de refrescar Power BI.
--
-- Cada bloque devuelve una fila con el resultado y un semáforo.
-- Si alguno sale en FALLO, no publicar.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Trazabilidad de filas: bronze → silver → gold
-- -----------------------------------------------------------------------------
SELECT '1. Trazabilidad de filas' AS control,
       (SELECT count(*) FROM bronze.educabase_matriculados) AS bronze,
       (SELECT count(*) FROM silver.poblacion)              AS silver,
       (SELECT count(*) FROM gold.fact_poblacion)           AS gold,
       (SELECT count(*) FROM silver.rechazos)               AS rechazos,
       CASE WHEN (SELECT count(*) FROM silver.poblacion)
                 = (SELECT count(*) FROM gold.fact_poblacion)
            THEN 'OK' ELSE 'FALLO: silver y gold no coinciden' END AS resultado;

-- -----------------------------------------------------------------------------
-- 2. La suma de la medida se conserva entre capas
-- -----------------------------------------------------------------------------
SELECT '2. Suma de matriculados' AS control,
       (SELECT sum(num_matriculados) FROM silver.poblacion)    AS silver,
       (SELECT sum(num_matriculados) FROM gold.fact_poblacion) AS gold,
       CASE WHEN (SELECT sum(num_matriculados) FROM silver.poblacion)
                 = (SELECT sum(num_matriculados) FROM gold.fact_poblacion)
            THEN 'OK' ELSE 'FALLO: la medida no se conserva' END AS resultado;

-- -----------------------------------------------------------------------------
-- 3. Claves foráneas huérfanas (no debería haber ninguna)
-- -----------------------------------------------------------------------------
SELECT '3. FK a No informado (-1)' AS control,
       count(*) FILTER (WHERE sk_tiempo      = -1) AS tiempo,
       count(*) FILTER (WHERE sk_territorio  = -1) AS territorio,
       count(*) FILTER (WHERE sk_programa    = -1) AS programa,
       count(*) FILTER (WHERE sk_familia     = -1) AS familia,
       count(*) FILTER (WHERE sk_modalidad   = -1) AS modalidad,
       count(*) FILTER (WHERE sk_sexo        = -1) AS sexo,
       count(*) FILTER (WHERE sk_edad        = -1) AS edad
FROM   gold.fact_poblacion;

-- -----------------------------------------------------------------------------
-- 4. CCAA sin mapear (si sale > 0, ampliar silver.alias_territorio)
-- -----------------------------------------------------------------------------
SELECT '4. CCAA sin mapear' AS control,
       count(*) AS filas,
       CASE WHEN count(*) = 0 THEN 'OK'
            ELSE 'REVISAR: ampliar silver.alias_territorio' END AS resultado
FROM   silver.poblacion
WHERE  cod_ccaa = '99';

-- -----------------------------------------------------------------------------
-- 5. Doble conteo: las filas 'Total Nacional' y 'Ambos sexos' NO deben sumarse
--    junto a los desgloses. Este control las aísla para verificar el criterio.
-- -----------------------------------------------------------------------------
SELECT '5. Filas agregadas (riesgo de doble conteo)' AS control,
       count(*) FILTER (WHERE te.es_total)            AS filas_total_nacional,
       count(*) FILTER (WHERE se.nom_sexo = 'Ambos sexos') AS filas_ambos_sexos
FROM   gold.fact_poblacion f
JOIN   gold.dim_territorio te ON te.sk_territorio = f.sk_territorio
JOIN   gold.dim_sexo       se ON se.sk_sexo       = f.sk_sexo;

-- -----------------------------------------------------------------------------
-- 6. Total por curso — contrastar manualmente contra la cifra publicada
--    por el Ministerio antes de dar por bueno el refresco.
-- -----------------------------------------------------------------------------
SELECT t.curso_academico,
       sum(f.num_matriculados) AS total_matriculados
FROM   gold.fact_poblacion f
JOIN   gold.dim_tiempo t ON t.sk_tiempo = f.sk_tiempo
JOIN   gold.dim_territorio te ON te.sk_territorio = f.sk_territorio
WHERE  NOT te.es_total
GROUP  BY t.curso_academico
ORDER  BY t.curso_academico;

-- -----------------------------------------------------------------------------
-- 7. Detalle de rechazos por motivo
-- -----------------------------------------------------------------------------
SELECT tabla_origen, motivo, count(*) AS filas
FROM   silver.rechazos
GROUP  BY tabla_origen, motivo
ORDER  BY filas DESC;
