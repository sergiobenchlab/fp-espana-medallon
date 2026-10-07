"""
preparar_t20.py
Compuerta de calidad del T20 (Estados Financieros de las IES de Colombia).

Lee los dos CSV que salen del pipeline de extraccion y deja en la carpeta de
salida lo que se carga y lo que no:

    cuentas_carga.csv     catalogo, UTF-8 sin BOM, separador coma
    t20_fact_carga.csv    hechos que pasan la compuerta (id_ies, anio, codigo_cuenta, valor)
    t20_rechazos.csv      combinaciones IES-anio que no se cargan, con motivo
    t20_observaciones.csv combinaciones que se cargan pero hay que revisar
    t20_reporte.txt       resumen de cada paso

La resolucion de claves (anio -> id_prd, codigo_cuenta -> id_cnt) no se hace
aqui sino en 03_carga_t20.sql, contra colombia.periodo y el propio catalogo,
para no depender de una formula.

Uso:
    python3 -I preparar_t20.py --fact t20_fact.csv --cuentas dim_cuentas.csv --salida salida/
"""

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

# IES excluidas completas, con el motivo. Se revisan a mano antes de volver a cargarlas.
CUARENTENA = {
    167: "EAN: cuentas desplazadas en la extraccion (valores repetidos entre balance "
         "y resultados, faltan 13 cuentas incluida UN, balance descuadrado 40-50%)",
}

# Por encima de esta diferencia relativa el balance se rechaza. Entre la
# tolerancia de redondeo y este umbral se carga y queda como observacion.
UMBRAL_RECHAZO_BALANCE = 0.01

# Becas y descuentos: la convencion es valor positivo que se resta de 6010.
CUENTAS_BECAS = ["6020", "6021", "6022", "6023"]

# Cuentas que por naturaleza no deberian ser negativas (activos y capital).
CUENTAS_NO_NEGATIVAS = ["1010", "1020", "1030", "1040", "2010", "2020", "2030",
                        "2040", "5010"]


def tolerancia(activo):
    """La misma tolerancia que el control de balance en SQL."""
    return np.maximum(3, activo.abs() * 0.0001)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fact", required=True)
    ap.add_argument("--cuentas", required=True)
    ap.add_argument("--salida", required=True)
    args = ap.parse_args()

    salida = Path(args.salida)
    salida.mkdir(parents=True, exist_ok=True)
    reporte = []

    def log(msg):
        print(msg)
        reporte.append(msg)

    # ---- Catalogo: quitar BOM y pasar a coma --------------------------------
    cuentas = pd.read_csv(args.cuentas, sep=";", dtype=str, encoding="utf-8-sig")
    cuentas.columns = ["id_cnt", "codigo_cuenta", "nombre_cuenta", "grp_1",
                       "grp_2", "tipo", "codigo_padre"]
    cuentas.to_csv(salida / "cuentas_carga.csv", index=False, encoding="utf-8")
    log(f"Catalogo: {len(cuentas)} cuentas "
        f"({cuentas.tipo.value_counts().to_dict()})")

    # ---- Hechos -------------------------------------------------------------
    f = pd.read_csv(args.fact, dtype={"codigo_cuenta": str})
    log(f"Hechos de entrada: {len(f)} filas, {f.id_ies.nunique()} IES, "
        f"{f.groupby(['id_ies', 'anio']).ngroups} combinaciones IES-anio")

    huerfanas = set(f.codigo_cuenta) - set(cuentas.codigo_cuenta)
    if huerfanas:
        raise SystemExit(f"Cuentas sin catalogo: {sorted(huerfanas)}")

    # 1. Signo de becas y descuentos
    m = f.codigo_cuenta.isin(CUENTAS_BECAS) & (f.valor < 0)
    log(f"Paso 1. Becas y descuentos con signo invertido normalizados a positivo: "
        f"{m.sum()} filas en {f[m].id_ies.nunique()} IES")
    f.loc[m, "valor"] = f.loc[m, "valor"].abs()

    rechazos = []

    # 2. Cuarentena
    m = f.id_ies.isin(CUARENTENA)
    for (ies, anio), g in f[m].groupby(["id_ies", "anio"]):
        rechazos.append((ies, anio, "cuarentena", CUARENTENA[ies], len(g)))
    log(f"Paso 2. Cuarentena: {m.sum()} filas de las IES {sorted(CUARENTENA)}")
    f = f[~m]

    # 3. Estados vacios: todas las cuentas en NULL o en 0
    con_dato = (f.valor.fillna(0) != 0).groupby([f.id_ies, f.anio]).sum()
    vacios = con_dato[con_dato == 0].index
    m = pd.MultiIndex.from_frame(f[["id_ies", "anio"]]).isin(vacios)
    for (ies, anio), g in f[m].groupby(["id_ies", "anio"]):
        rechazos.append((ies, anio, "estado_vacio",
                         "todas las cuentas en NULL o 0", len(g)))
    log(f"Paso 3. Estados vacios: {len(vacios)} combinaciones, {m.sum()} filas")
    f = f[~m]

    # 4. Identidad de balance (pivot y no pivot_table: la PK es unica y asi un
    #    NULL sigue siendo NULL en vez de convertirse en 0 al sumar)
    p = f.pivot(index=["id_ies", "anio"], columns="codigo_cuenta", values="valor")
    activo = p[["1000", "2000"]].sum(axis=1, min_count=1)
    pasivo = p[["3000", "4000"]].sum(axis=1, min_count=1).fillna(0)
    patrimonio = p["5000"].fillna(0)
    dif = activo - pasivo - patrimonio
    base = activo.where(activo != 0)
    rel = (dif / base).abs()
    evaluable = activo.notna()
    falla = evaluable & (dif.abs() > tolerancia(activo.fillna(0)))
    grave = falla & (rel.isna() | (rel > UMBRAL_RECHAZO_BALANCE))
    leve = falla & ~grave

    observaciones = []
    for ies, anio in p.index[grave]:
        r = rel.get((ies, anio))
        detalle = ("activo total en 0 con patrimonio distinto de 0" if pd.isna(r)
                   else f"diferencia {r:.1%} del activo ({dif[(ies, anio)]:,.0f})")
        n = ((f.id_ies == ies) & (f.anio == anio)).sum()
        rechazos.append((ies, anio, "balance", detalle, n))
    for ies, anio in p.index[leve]:
        observaciones.append((ies, anio, "balance_leve",
                              f"diferencia {rel[(ies, anio)]:.2%} del activo "
                              f"({dif[(ies, anio)]:,.0f})"))
    m = pd.MultiIndex.from_frame(f[["id_ies", "anio"]]).isin(p.index[grave])
    log(f"Paso 4. Balance: {evaluable.sum()} combinaciones evaluables, "
        f"{grave.sum()} rechazadas (> {UMBRAL_RECHAZO_BALANCE:.0%}), "
        f"{leve.sum()} cargadas con observacion")
    f = f[~m]

    # 5. Observaciones que no bloquean
    # 5a. Estados identicos en dos IES el mismo anio
    q = f.pivot(index=["anio", "id_ies"], columns="codigo_cuenta",
                values="valor").fillna(-1)
    dup = q[q.duplicated(keep=False)].reset_index()
    for anio, g in dup.groupby("anio"):
        ids = sorted(g.id_ies)
        for ies in ids:
            observaciones.append((ies, anio, "estado_duplicado",
                                  f"estado identico al de las IES {ids}"))
    # 5b. Negativos en cuentas que no deberian serlo
    neg = f[f.codigo_cuenta.isin(CUENTAS_NO_NEGATIVAS) & (f.valor < 0)]
    for (ies, anio), g in neg.groupby(["id_ies", "anio"]):
        observaciones.append((ies, anio, "signo",
                              "negativo en " + ", ".join(sorted(g.codigo_cuenta))))
    # 5c. Ingresos netos = ingresos operativos - becas y descuentos
    r = f.pivot(index=["id_ies", "anio"], columns="codigo_cuenta",
                values="valor")[["6000", "6010", "6020"]].dropna()
    dif_ing = r["6010"] - r["6020"] - r["6000"]
    mal = r[dif_ing.abs() > tolerancia(r["6000"])]
    for (ies, anio), x in mal.iterrows():
        detalle = ("6000 igual a 6010: las becas no se restaron"
                   if abs(x["6000"] - x["6010"]) <= max(3, abs(x["6000"]) * 0.0001)
                   else f"6010 - 6020 - 6000 = {dif_ing[(ies, anio)]:,.0f}")
        observaciones.append((ies, anio, "ingresos", detalle))
    log(f"Paso 5. Observaciones: {len(dup)} estados duplicados, "
        f"{len(neg)} negativos en cuentas de activo o capital, "
        f"{len(mal)} de {len(r)} combinaciones no cumplen 6000 = 6010 - 6020")

    # ---- Escritura ----------------------------------------------------------
    f[["id_ies", "anio", "codigo_cuenta", "valor"]].to_csv(
        salida / "t20_fact_carga.csv", index=False, encoding="utf-8")
    pd.DataFrame(rechazos, columns=["id_ies", "anio", "motivo", "detalle", "filas"]) \
        .sort_values(["motivo", "id_ies", "anio"]) \
        .to_csv(salida / "t20_rechazos.csv", index=False, encoding="utf-8")
    pd.DataFrame(observaciones, columns=["id_ies", "anio", "tipo", "detalle"]) \
        .sort_values(["tipo", "id_ies", "anio"]) \
        .to_csv(salida / "t20_observaciones.csv", index=False, encoding="utf-8")

    log(f"Salida: {len(f)} filas, {f.id_ies.nunique()} IES, "
        f"{f.groupby(['id_ies', 'anio']).ngroups} combinaciones IES-anio")
    log("IES con estado cargado por anio: "
        + ", ".join(f"{a}: {n}" for a, n in f.groupby("anio").id_ies.nunique().items()))
    (salida / "t20_reporte.txt").write_text("\n".join(reporte) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
