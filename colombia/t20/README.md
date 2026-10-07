# T20: Estados Financieros de las IES de Colombia

Carga del T20 a la capa gold (schema `colombia`) con su par en `intermediate`,
según la guía medallion.

## Orden de ejecución

```
python3 -I preparar_t20.py --fact t20_fact.csv --cuentas dim_cuentas.csv --salida salida/
psql -v ON_ERROR_STOP=1 -f sql/01_intermediate_t20.sql
psql -v ON_ERROR_STOP=1 -f sql/02_gold_t20.sql
cd salida && psql -v ON_ERROR_STOP=1 -f ../sql/03_carga_t20.sql && cd ..
psql -v ON_ERROR_STOP=1 -f sql/04_qa_t20.sql
```

Todo es idempotente. `02` borra las vistas de control con CASCADE; `04` las vuelve a crear.

| Archivo | Qué hace |
|---|---|
| `preparar_t20.py` | Compuerta de calidad. Quita el BOM y el `;` del catálogo, normaliza el signo de becas, rechaza lo que no cuadra y deja todo en `salida/` |
| `sql/01_intermediate_t20.sql` | `intermediate.co_dim_cuenta_financiera` y `intermediate.co_fact_t20_financiero`, sin constraints |
| `sql/02_gold_t20.sql` | `colombia.dim_cuenta_financiera`, `colombia.fact_t20_financiero` y `colombia.vw_t20_comparativos` |
| `sql/03_carga_t20.sql` | `\copy` a staging, resolución de `id_prd` e `id_cnt`, carga a intermediate y gold en una transacción |
| `sql/04_qa_t20.sql` | Controles de periodos, balance y signo |

## Modelo

- **Fact:** PK `(id_prd, id_ies, id_cnt)`, tres FK enteras. Cada año se registra
  en el periodo del corte al 31 de diciembre (el segundo semestre, el de
  `fch_inc_prd` más reciente del año). `id_prd` se resuelve contra
  `colombia.periodo`, no con una fórmula.
- **Catálogo:** jerarquía como FK entera `id_cnt_padre → id_cnt`, sin
  DEFERRABLE. La carga inserta por niveles: padres antes que hijos.
- **Comparativos:** la vista repite el valor anual en los dos semestres del año
  para cruzarlo con los datos de estudiantes.
- Sin `fuente`, `verificado` ni `fecha_carga`: la fuente va en raw y la
  verificación es la compuerta.

Dependencias que se asumen en `colombia`: `dim_universidades (id_ies, codigo_ies, nombre_ies)`
y `periodo (id_prd, anio, fch_inc_prd)`.

## Compuerta de calidad

| Paso | Regla | Resultado con la entrega del 19-ago-2026 |
|---|---|---|
| 1 | Becas y descuentos (6020-6023) en positivo | 149 filas de 40 IES invertidas |
| 2 | Cuarentena: IES 167 (EAN), cuentas desplazadas en la extracción | 406 filas fuera |
| 3 | Estado vacío: todas las cuentas en NULL o 0 | 103 combinaciones IES-año, 7.210 filas fuera |
| 4 | Balance: diferencia > 1 % del activo se rechaza; entre la tolerancia y 1 % se carga con observación | 4 rechazadas, 4 observadas |
| 5 | Observaciones: estados idénticos entre IES, negativos en activo o capital, 6000 ≠ 6010 − 6020 | 4, 23 y 35 combinaciones |

Salida: 64.400 filas, 170 IES, 920 combinaciones IES-año. El detalle queda en
`salida/t20_rechazos.csv` y `salida/t20_observaciones.csv`.
