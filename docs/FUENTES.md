# Fuentes de datos

## EDUCAbase — Ministerio de Educación, FP y Deportes

Portal estadístico oficial. Fuente **autoritativa** para totales de matriculados.

- Navegación: Estadísticas → Enseñanzas no universitarias → Formación Profesional
- Formato de descarga: XLSX (tablas dinámicas configurables)
- Periodicidad: anual, por curso académico
- Publicación: la estadística definitiva del curso *n/n+1* suele aparecer a lo largo
  del curso siguiente

### Consultas a descargar

| Fichero destino | Desglose |
|---|---|
| `educabase_matriculados_ccaa_familia.xlsx` | CCAA × familia profesional × grado |
| `educabase_matriculados_sexo.xlsx` | CCAA × grado × sexo |
| `educabase_matriculados_edad.xlsx` | CCAA × grado × tramo de edad |
| `educabase_matriculados_modalidad.xlsx` | CCAA × grado × modalidad (presencial/distancia) |
| `educabase_centros.xlsx` | CCAA × provincia × titularidad |

### Pendiente

Estadísticas de inserción laboral — necesarias para las tablas `ml_insercion` y
`ml_laborales`. Aún no descargadas.

---

## CaixaBank Dualiza / Observatorio de la FP

Series agregadas y análisis sobre FP dual. Fuente **complementaria**.

- Formato: XLSX
- Uso: desgloses que EDUCAbase no publica, especialmente FP dual
- **Advertencia:** presenta inconsistencias internas (<1%) entre agregados por CCAA
  y totales nacionales del mismo fichero. Ver `ARQUITECTURA.md` → Desviaciones
  conocidas. No se usa para totales.

---

## Registro de descargas

Cada vez que se descargue un fichero, añadir una fila. Esto es lo que permite
reproducir un resultado meses después.

| Fecha descarga | Fichero | Fuente | Curso(s) | Notas |
|---|---|---|---|---|
| | | | | |

---

## Catálogos de referencia

| Catálogo | Origen | Uso |
|---|---|---|
| Códigos CCAA y provincias | INE | Normalización de `dim_territorio` |
| Familias profesionales | Catálogo Nacional de Cualificaciones Profesionales | `dim_familia` |
| Ciclos formativos | TodoFP / Ministerio | `dim_programa` |

Los catálogos se versionan en `data/samples/` por ser tablas pequeñas y estables.
