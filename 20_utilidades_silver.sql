-- =============================================================================
-- 20_utilidades_silver.sql
-- Funciones de limpieza reutilizables y tabla de rechazos.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Convierte texto numérico de las fuentes españolas a numeric.
-- Maneja: separador de miles con punto, decimal con coma, marcadores de
-- ausencia ('..', '-', 'n.d.', ':', ''), espacios duros.
-- Devuelve NULL cuando no es convertible (no lanza excepción).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION silver.a_numero(p_texto text)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_limpio text;
BEGIN
    IF p_texto IS NULL THEN
        RETURN NULL;
    END IF;

    v_limpio := trim(replace(p_texto, chr(160), ' '));  -- espacio duro

    IF v_limpio IN ('', '..', '.', '-', ':', 'n.d.', 'N.D.', 'nd', 'ND') THEN
        RETURN NULL;
    END IF;

    -- Quita separador de miles (punto) y convierte decimal (coma) a punto
    v_limpio := replace(v_limpio, '.', '');
    v_limpio := replace(v_limpio, ',', '.');
    v_limpio := regexp_replace(v_limpio, '[^0-9\.\-]', '', 'g');

    IF v_limpio = '' OR v_limpio = '-' THEN
        RETURN NULL;
    END IF;

    RETURN v_limpio::numeric;
EXCEPTION
    WHEN others THEN
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION silver.a_numero(text) IS
    'Convierte texto numérico español a numeric. Devuelve NULL si no es convertible.';


-- -----------------------------------------------------------------------------
-- Normaliza texto para comparaciones: quita tildes, pasa a mayúscula,
-- colapsa espacios. Usada en los joins contra catálogos.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION silver.normaliza_texto(p_texto text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT upper(
             regexp_replace(
               translate(
                 trim(coalesce(p_texto, '')),
                 'áàäâéèëêíìïîóòöôúùüûñçÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑÇ',
                 'aaaaeeeeiiiioooouuuuncAAAAEEEEIIIIOOOOUUUUNC'
               ),
               '\s+', ' ', 'g'
             )
           );
$$;

COMMENT ON FUNCTION silver.normaliza_texto(text) IS
    'Quita tildes, mayúsculas, colapsa espacios. Para joins contra catálogos.';


-- -----------------------------------------------------------------------------
-- Normaliza curso académico a formato canónico AAAA/AAAA
-- Acepta: '2023-24', '2023/2024', '2023-2024', '2023_24'
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION silver.normaliza_curso(p_texto text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_anio integer;
BEGIN
    IF p_texto IS NULL OR trim(p_texto) = '' THEN
        RETURN NULL;
    END IF;

    v_anio := (regexp_match(p_texto, '(\d{4})'))[1]::integer;

    IF v_anio IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN v_anio::text || '/' || (v_anio + 1)::text;
EXCEPTION
    WHEN others THEN
        RETURN NULL;
END;
$$;


-- -----------------------------------------------------------------------------
-- Tabla única de rechazos. Toda fila no normalizable acaba aquí.
-- Nunca se descarta una fila en silencio.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS silver.rechazos CASCADE;

CREATE TABLE silver.rechazos (
    id              bigserial PRIMARY KEY,
    tabla_origen    text        NOT NULL,
    fila_origen     integer,
    motivo          text        NOT NULL,
    contenido       jsonb,
    fecha_registro  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_rechazos_tabla ON silver.rechazos (tabla_origen);
