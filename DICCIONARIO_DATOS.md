# Diccionario de datos — capa gold

## `fact_poblacion`

Tabla de hechos. Grano: curso × territorio × programa × modalidad × titularidad ×
sexo × tramo de edad.

| Columna | Tipo | Descripción |
|---|---|---|
| `sk_tiempo` | integer | FK → `dim_tiempo` |
| `sk_territorio` | integer | FK → `dim_territorio` |
| `sk_programa` | integer | FK → `dim_programa` |
| `sk_familia` | integer | FK → `dim_familia` |
| `sk_modalidad` | integer | FK → `dim_modalidad` |
| `sk_titularidad` | integer | FK → `dim_titularidad` |
| `sk_sexo` | integer | FK → `dim_sexo` |
| `sk_edad` | integer | FK → `dim_edad` |
| `num_matriculados` | integer | Medida aditiva |

> **Aviso de doble conteo.** El hecho contiene filas agregadas de origen
> (`Total Nacional` en territorio, `Ambos sexos` en sexo). Sumar sin filtrar
> duplica los totales. En Power BI deben excluirse mediante filtro de modelo o
> tratarse en las medidas DAX. Ver control 5 en `sql/90_qa/90_reconciliacion.sql`.

---

## Dimensiones

### `dim_tiempo`
| Columna | Tipo | Descripción |
|---|---|---|
| `sk_tiempo` | integer | PK. Año de inicio del curso (ej. 2024) |
| `curso_academico` | text | Formato canónico `AAAA/AAAA` |
| `anio_inicio` / `anio_fin` | integer | Años del curso |
| `curso_corto` | text | Formato `2024-25` para visuales |
| `es_ultimo` | boolean | Marca el curso más reciente cargado |

### `dim_territorio`
| Columna | Tipo | Descripción |
|---|---|---|
| `sk_territorio` | integer | PK. Código INE numérico |
| `cod_ccaa` | text | Código INE de 2 dígitos |
| `nom_ccaa` | text | Denominación oficial INE |
| `es_total` | boolean | `true` para la fila agregada nacional |

### `dim_programa`
| Columna | Tipo | Descripción |
|---|---|---|
| `sk_programa` | integer | PK subrogada |
| `nom_ciclo` | text | Denominación del ciclo formativo |
| `nom_grado` | text | Básica / Grado Medio / Grado Superior |
| `sk_familia` | integer | FK → `dim_familia` |

### `dim_familia`
| Columna | Tipo | Descripción |
|---|---|---|
| `sk_familia` | integer | PK subrogada |
| `nom_familia` | text | Familia profesional |

### `dim_modalidad` / `dim_sexo` / `dim_titularidad` / `dim_edad`
Dimensiones pequeñas con clave subrogada, denominación única y miembro
`No informado` en `sk = -1`.

---

## Convención de claves

- Toda dimensión incluye un miembro `No informado` con `sk = -1`.
- El hecho nunca tiene `NULL` en una clave foránea.
- Los códigos naturales (`cod_ccaa`) se conservan junto a la clave subrogada
  para poder cruzar con fuentes externas.

---

## Relaciones en Power BI

Todas de tipo **uno a muchos**, dirección de filtro **simple** desde la dimensión
hacia el hecho. Ninguna bidireccional: la ambigüedad de filtro es la causa habitual
de los problemas de fan-out en las medidas.

`dim_familia` se relaciona con el hecho **directamente** (no a través de
`dim_programa`) para evitar una cadena de filtrado innecesaria.
