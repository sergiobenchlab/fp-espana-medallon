Hola equipo de Data,

Gracias por la revisión. Van las respuestas a los cuatro puntos de datos y el DDL corregido.
En el camino encontré tres problemas que no estaban en su lista, así que la carga cambia un poco
respecto de los CSV que les mandé.

## Puntos de datos

**1. Caída de 2024-2025.** [CONFIRMAR: carga incompleta o dato real.] Lo que muestra el archivo:
las 87 IES que tienen 2023 y no 2024 no tienen ninguna fila en 2024, ni siquiera en NULL. Es decir,
esos estados no se extrajeron, no es que la IES haya reportado vacío. Las IES de 2025 son un
subconjunto de las de 2024.

**2. IES 167.** Es la EAN, la misma que tiene G7010. La extracción le desplazó las cuentas: hay
valores repetidos entre balance y resultados (por ejemplo 4030 y G7032 valen lo mismo en 2021,
2022 y 2023), le faltan 13 cuentas, entre ellas UN, y de 2018 a 2020 solo tiene ceros. No es
recuperable desde el archivo. La dejo en cuarentena (406 filas, todos los años) hasta volver a
extraerla desde los PDF.

**3. Balance.** Reviso las 10 que encontraron, más una que no salió en su lista:

| IES | Año | Diferencia | Causa | Decisión |
|---|---|---|---|---|
| 167 | 2021-2023 | 40-51 % | Cuentas desplazadas (punto 2) | Cuarentena |
| 165 | 2024 | 11,6 % | La diferencia es exactamente el valor de 3010: la cuenta quedó contada dos veces | Se rechaza |
| 124 | 2024 | 100 % | Activo y pasivo en 0, patrimonio de 201.108 millones: extracción incompleta | Se rechaza |
| 275 | 2019, 2020 | 1,9 % y 3,6 % | 4040 idéntica en los dos años y 5010 de 2020 igual al 5000 de 2019: arrastre entre años | Se rechazan |
| 53 | 2023 | 0,96 % | 43.669 millones; por tamaño no es redondeo | Se carga con observación |
| 228 | 2019, 2020 | 0,2 % | | Se carga con observación |
| 322 | 2022 | 0,05 % | Redondeo | Se carga con observación |

Ojo: 275 no está por debajo del 1 %. Regla que propongo para la compuerta: por encima de 1 % del
activo se rechaza; entre la tolerancia de redondeo y 1 % se carga y queda listado para revisión.

**4. Negativos.** De los 948, la mayoría son esperados: 8040 (resultado financiero neto, 337),
5020, 5030, UN y 5000 (pérdidas y patrimonio negativo), 9010 (impuesto diferido) y reversiones de
deterioro. Por eso no hay CHECK de signo en la tabla.

La excepción son becas y descuentos: 149 filas de 40 IES venían en negativo, y en la mitad de esos
casos el 6000 se había armado sumándolas en vez de restarlas. Dos convenciones mezcladas hacen que
cualquier suma entre IES salga mal. La compuerta las pasa a positivo (la convención que siguen 885
de 953 estados) y `vw_t20_control_signo` verifica que no vuelvan a entrar en negativo.

Quedan como observación, sin bloquear la carga, 23 negativos en cuentas de activo o en capital
social (IES 13 y 118 en 5010, IES 127 en 1040, entre otras).

## Lo que encontré además

- **103 estados vacíos.** Hay combinaciones IES-año con todas las cuentas en NULL o en 0 (63 en
  2018). Son 7.210 filas que inflan el conteo de IES con dato y meten ceros falsos en promedios.
  No se cargan.
- **IES 20 y 26 tienen estados idénticos en 2024 y 2025.** Puede ser una misma entidad con dos
  códigos o un error de asignación. [CONFIRMAR.] Se cargan con observación.
- **Ingresos netos en 2024-2025.** En 33 de los 124 estados de esos años no se cumple
  6000 = 6010 − 6020; en 24 de ellos 6000 es igual a 6010, o sea que no se restaron las becas.
  En 2018-2023 eso pasa en solo 2 casos. Se cargan con observación y lo corrijo en el pipeline
  para la próxima entrega.

Con todo esto la carga queda en **64.400 filas, 170 IES y 920 combinaciones IES-año**. Les
mando el detalle en `t20_rechazos.csv` y `t20_observaciones.csv`.

## DDL corregido

Los 8 puntos están aplicados:

1. **FK enteras.** PK del fact `(id_prd, id_ies, id_cnt)`: tres enteros y tres FK. La jerarquía
   del catálogo también pasa a FK entera: `id_cnt_padre → id_cnt`.
2. **Periodo como FK.** El estado es anual con corte al 31 de diciembre, así que cada año se
   registra una sola vez, en el periodo del segundo semestre. `id_prd` se resuelve en la carga
   contra `colombia.periodo`, no con una fórmula. La vista de comparativos lo repite en los dos
   semestres del año.
3. **Schema `colombia`** para las tablas y las vistas.
4. **Nombres:** `pk_`, `fk_`, `chk_`, `uq_`, `idx_co_`.
5. **Idempotente:** `DROP ... IF EXISTS ... CASCADE` en orden inverso de dependencias. Lo corrí
   dos veces seguidas sobre una base de prueba sin errores.
6. **Sin `fuente`, `verificado` ni `fecha_carga`.** La verificación vive en la compuerta.
7. **Sin DEFERRABLE.** La carga inserta el catálogo por niveles de jerarquía, padres primero, en
   una sola transacción.
8. **Intermediate:** `intermediate.co_dim_cuenta_financiera` e
   `intermediate.co_fact_t20_financiero`, sin constraints.

**BOM y separador:** la compuerta reescribe el catálogo en UTF-8 sin BOM y con coma, así que los
dos archivos de carga tienen el mismo formato. El `\copy` declara `ENCODING 'UTF8'`.

**Para confirmar de su lado:** asumí `colombia.dim_universidades (id_ies, codigo_ies, nombre_ies)`
y `colombia.periodo (id_prd, anio, fch_inc_prd)`. Si las columnas se llaman distinto lo ajusto.

Orden de ejecución: `01_intermediate_t20.sql`, `02_gold_t20.sql`, `03_carga_t20.sql` (desde la
carpeta de los CSV) y `04_qa_t20.sql`. Después de la carga, los controles de periodos, balance
mayor a 1 % y becas negativas devuelven 0 filas.

Quedo atento para coordinar la carga.

Saludos,
Sergio
