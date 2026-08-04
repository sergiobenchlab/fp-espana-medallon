-- =============================================================================
-- 00_crear_esquemas.sql
-- Crea los tres esquemas de la arquitectura medallón.
-- Idempotente: se puede relanzar sin efecto.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

COMMENT ON SCHEMA bronze IS
    'Ingesta cruda. Todas las columnas TEXT. Inmutable. Refleja el fichero origen tal cual.';

COMMENT ON SCHEMA silver IS
    'Datos tipados, normalizados y deduplicados. Incluye tablas de rechazos.';

COMMENT ON SCHEMA gold IS
    'Modelo en estrella para Power BI. fact_poblacion + dimensiones.';

-- Orden de búsqueda por defecto para sesiones de DBeaver
-- (ajustar el nombre de la base si difiere)
-- ALTER DATABASE benchlab_fp_es SET search_path TO gold, silver, bronze, public;

-- Verificación
SELECT nspname AS esquema
FROM   pg_namespace
WHERE  nspname IN ('bronze', 'silver', 'gold')
ORDER  BY nspname;
