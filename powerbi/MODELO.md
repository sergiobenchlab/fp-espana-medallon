# Modelo Power BI — FP España

## Origen de datos

Conexión directa a PostgreSQL, esquema `gold`. Modo **Import** (el volumen lo
permite y evita la latencia de DirectQuery en los visuales de radar).

## Renombrado en M-Query

Los objetos llegan en minúscula desde PostgreSQL. El renombrado a la convención de
presentación se hace en el paso de importación, no en la base:

```
gold.fact_poblacion   →  FACT_POBLACION
gold.dim_tiempo       →  DIM_TIEMPO
gold.dim_territorio   →  DIM_TERRITORIO
gold.dim_programa     →  DIM_PROGRAMA
gold.dim_familia      →  DIM_FAMILIA
gold.dim_modalidad    →  DIM_MODALIDAD
gold.dim_sexo         →  DIM_SEXO
gold.dim_titularidad  →  DIM_TITULARIDAD
gold.dim_edad         →  DIM_EDAD
```

## Relaciones

Todas **uno a muchos**, dirección de filtro **simple** (dimensión → hecho).
Ninguna bidireccional.

| Desde | Hacia | Columnas |
|---|---|---|
| DIM_TIEMPO | FACT_POBLACION | `sk_tiempo` |
| DIM_TERRITORIO | FACT_POBLACION | `sk_territorio` |
| DIM_PROGRAMA | FACT_POBLACION | `sk_programa` |
| DIM_FAMILIA | FACT_POBLACION | `sk_familia` |
| DIM_MODALIDAD | FACT_POBLACION | `sk_modalidad` |
| DIM_SEXO | FACT_POBLACION | `sk_sexo` |
| DIM_TITULARIDAD | FACT_POBLACION | `sk_titularidad` |
| DIM_EDAD | FACT_POBLACION | `sk_edad` |

## Filtros de modelo obligatorios

El hecho contiene filas agregadas de origen. Sin filtrar, los totales se duplican:

- `DIM_TERRITORIO[es_total] = FALSE` cuando se analice por CCAA
- `DIM_SEXO[nom_sexo] <> "Ambos sexos"` cuando se desglose por sexo

Decidir por informe si se aplican como filtro de página o se resuelven en las medidas.

## Ordenación

`DIM_EDAD[nom_tramo_edad]` debe ordenarse por `DIM_EDAD[orden]`, no alfabéticamente
(si no, "<20" queda después de "30-34").

## Medidas

Las medidas DAX se versionan en `medidas_dax/` como ficheros `.dax`, una por
fichero, con el nombre exacto de la medida.
