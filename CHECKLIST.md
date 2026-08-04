# Checklist de trabajo

## Al empezar una sesión

- [ ] `git pull` para traer los últimos cambios
- [ ] Revisar `docs/FUENTES.md` → registro de descargas

## Al añadir datos de un curso nuevo

- [ ] Descargar de EDUCAbase y anotar la fila en el registro de `docs/FUENTES.md`
- [ ] Convertir XLSX → CSV UTF-8 y dejar en `data/raw/`
- [ ] Ejecutar `sql/10_bronze/11_carga_bronze.sql`
- [ ] Ejecutar `sql/20_silver/21_dim_territorio_normalizado.sql` y revisar la
      consulta final: si devuelve variantes de CCAA nuevas, **ampliar la tabla
      de alias antes de continuar**
- [ ] Ejecutar el resto de silver y gold en orden
- [ ] Ejecutar `sql/90_qa/90_reconciliacion.sql`
- [ ] Contrastar el total del control 6 contra la cifra publicada por el Ministerio
- [ ] Solo entonces, refrescar Power BI

## Antes de hacer commit

- [ ] Ningún `.csv` o `.xlsx` de datos crudos en el commit (`git status`)
- [ ] Ningún `.env` ni credencial
- [ ] Ningún `.pbix`
- [ ] Actualizar la tabla de estado del `README.md` si cambió algo

## Al subir a GitHub por la web

1. En el repo → **Add file** → **Upload files**
2. Arrastrar la **carpeta completa** (el navegador conserva la estructura)
3. Escribir el mensaje de commit
4. **Commit changes**
