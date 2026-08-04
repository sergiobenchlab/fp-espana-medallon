# Arquitectura

## Principio general

Cada capa tiene un **contrato**: un conjunto de garantías que ofrece a la capa
siguiente. Si una capa incumple su contrato, el problema se corrige en esa capa,
nunca aguas abajo.

---

## Bronze — ingesta cruda

**Esquema:** `bronze`

### Contrato

- Refleja el fichero de origen **tal cual**. Una fila del fichero = una fila en bronze.
- **Todas las columnas son `text`.** No se castea nada en la ingesta.
- No se filtra, no se deduplica, no se corrige.
- Es **inmutable**: se recarga completa, nunca se hace `UPDATE`.

### Columnas de control (en todas las tablas bronze)

| Columna | Descripción |
|---|---|
| `_fuente` | `EDUCABASE` o `DUALIZA` |
| `_fichero_origen` | Nombre del fichero descargado |
| `_fecha_carga` | Timestamp de la ingesta |
| `_fila_origen` | Número de fila en el fichero original |

### Por qué todo en texto

Las fuentes traen celdas con `..`, `-`, `n.d.`, separadores de miles con punto y
decimales con coma. Castear en la ingesta convierte esos casos en `NULL` de forma
silenciosa y se pierde la evidencia. En bronze se conservan como texto y en silver
se traducen explícitamente, dejando constancia de cuántos casos hubo.

---

## Silver — limpieza y normalización

**Esquema:** `silver`

### Contrato

- Tipos correctos: enteros como `integer`, importes como `numeric`.
- Territorio normalizado contra el catálogo oficial de CCAA y provincias (códigos INE).
- Familia profesional y ciclo formativo normalizados contra catálogo propio.
- Sin duplicados en la clave natural.
- Toda fila que no se puede normalizar va a una tabla de rechazos, **no se descarta**.

### Tablas de rechazo

Cada transformación silver escribe sus filas no normalizables en
`silver.rechazos_<origen>` con el motivo. El script de QA cuenta esas filas y falla
si superan el umbral definido.

### Desviaciones conocidas

> **Dualiza — inconsistencias internas (<1%)**
>
> El fichero de CaixaBank Dualiza presenta inconsistencias internas: los agregados
> por CCAA no siempre suman el total nacional publicado en el mismo fichero. La
> desviación residual es inferior al 1%.
>
> **Decisión:** no se corrige. EDUCAbase es la fuente autoritativa para totales;
> Dualiza se usa para dimensiones que EDUCAbase no desglosa. La desviación se
> documenta y se reporta en el script de QA, no se ajusta a mano.

---

## Gold — modelo en estrella

**Esquema:** `gold`

### Contrato

- Un único hecho: `fact_poblacion`.
- Todas las claves foráneas resuelven contra su dimensión. Cero huérfanos.
- Las dimensiones tienen clave subrogada (`sk_*`) y conservan el código natural.
- Cada dimensión incluye un miembro **"No informado"** con `sk = -1`, para que el
  hecho nunca tenga `NULL` en una clave foránea.

### Grano de `fact_poblacion`

```
curso académico × territorio × programa × modalidad × sexo × tramo de edad
```

Una fila por combinación, con `num_matriculados` como medida aditiva.

### Por qué el miembro "No informado"

En Power BI, una clave foránea nula rompe la relación y las filas desaparecen del
modelo sin aviso. Redirigir esos casos a `sk = -1` los mantiene visibles y hace que
los totales cuadren siempre con el conteo de filas del hecho.

---

## Nomenclatura y Power BI

Los objetos en PostgreSQL van en **minúscula snake_case** (`fact_poblacion`).
PostgreSQL plegaría a minúscula cualquier identificador sin comillas, y usar
mayúsculas obligaría a entrecomillar en cada consulta de DBeaver — fricción
permanente y una fuente constante de errores.

El renombrado a la convención de presentación se hace en la **M-Query de Power BI**,
en el paso de importación. Es un único punto de cambio y no contamina la base.

---

## Idempotencia

Todos los scripts se pueden relanzar sin efectos secundarios:

- Bronze: `TRUNCATE` antes de cargar.
- Silver y gold: `CREATE TABLE ... AS` precedido de `DROP TABLE IF EXISTS`, o
  `TRUNCATE` + `INSERT` cuando la tabla tiene dependencias.

Nunca hay `INSERT` acumulativo sin limpieza previa. Relanzar el pipeline completo
debe producir exactamente el mismo resultado.
