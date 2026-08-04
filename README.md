# FP España — Arquitectura Medallón

Pipeline de datos para el sistema de **Formación Profesional de España**, siguiendo
la arquitectura medallón (bronze → silver → gold) sobre PostgreSQL, con salida a un
modelo en estrella consumido desde Power BI.

Réplica metodológica de los pipelines ya operativos de México, Chile, Perú y Argentina.

---

## Fuentes

| Fuente | Organismo | Contenido |
|---|---|---|
| EDUCAbase | Ministerio de Educación, FP y Deportes | Matriculados, centros, modalidad, sexo, edad, familia profesional |
| CaixaBank Dualiza / Observatorio FP | CaixaBank | Series agregadas por CCAA y familia profesional |

Ver detalle de descarga y periodicidad en [`docs/FUENTES.md`](docs/FUENTES.md).

---

## Arquitectura

```
        EDUCAbase (.xlsx/.csv)          Dualiza (.xlsx)
                 │                            │
                 ▼                            ▼
        ┌─────────────────────────────────────────────┐
        │  BRONZE   ingesta cruda, todo TEXT,         │
        │           sin castear, inmutable            │
        └─────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │  SILVER   tipado, normalización de          │
        │           territorio / familia / programa,  │
        │           deduplicación, reglas de negocio  │
        └─────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │  GOLD     modelo en estrella                │
        │           fact_poblacion + dimensiones      │
        └─────────────────────────────────────────────┘
                              │
                              ▼
                        Power BI
```

Detalle de contratos por capa en [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).

---

## Modelo en estrella (capa gold)

| Tabla | Tipo | Grano |
|---|---|---|
| `fact_poblacion` | Hecho | curso × territorio × programa × modalidad × sexo × tramo de edad |
| `dim_tiempo` | Dimensión | curso académico |
| `dim_territorio` | Dimensión | CCAA / provincia |
| `dim_familia` | Dimensión | familia profesional |
| `dim_programa` | Dimensión | ciclo formativo |
| `dim_modalidad` | Dimensión | presencial / distancia / dual |
| `dim_sexo` | Dimensión | hombre / mujer |
| `dim_edad` | Dimensión | tramo de edad |

---

## Orden de ejecución

Los scripts están numerados y se ejecutan **en orden estricto**. Cada bloque es
idempotente: se puede relanzar sin duplicar datos.

```
sql/00_setup/   →  esquemas y roles
sql/10_bronze/  →  DDL + carga de crudos
sql/20_silver/  →  limpieza y normalización
sql/30_gold/    →  dimensiones y hecho
sql/90_qa/      →  reconciliación contra cifras oficiales
```

Desde DBeaver: abrir cada script y ejecutar completo (Alt+X), respetando el orden.

Desde línea de comandos:

```bash
for f in $(find sql -name '*.sql' | sort); do
  echo ">>> $f"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done
```

---

## Puesta en marcha

1. Copiar `.env.example` a `.env` y rellenar la conexión.
2. Descargar los ficheros fuente a `data/raw/` (ver `docs/FUENTES.md`).
3. Ejecutar los scripts en orden.
4. Validar con `sql/90_qa/90_reconciliacion.sql` antes de refrescar Power BI.

---

## Convenciones

- Objetos de base de datos en **español, minúscula, snake_case**. Nunca comillas dobles.
- Prefijos: `fact_` para hechos, `dim_` para dimensiones, `stg_` para intermedias en silver.
- `data/raw/` **no se versiona**. El repo guarda el código que reconstruye los datos,
  no los datos.
- Toda desviación respecto a cifras oficiales se documenta en `docs/ARQUITECTURA.md`,
  no se corrige silenciosamente.

---

## Estado

| Componente | Estado |
|---|---|
| Estructura del repo | Inicial |
| Bronze | Pendiente |
| Silver | Pendiente |
| Gold | Pendiente |
| QA / reconciliación | Pendiente |
| Migración a organización Benchlab | Pendiente |
