#!/usr/bin/env bash
# Sube la estructura correcta al repo, reemplazando los archivos sueltos de la raíz.
# Ejecutar desde dentro de esta carpeta.
set -e

REPO="https://github.com/sergioroar/fp-espana-medallon.git"

git init
git remote add origin "$REPO" 2>/dev/null || git remote set-url origin "$REPO"
git fetch origin main
git reset --soft origin/main       # hereda el historial existente
git rm -r --cached . > /dev/null   # limpia el índice
git add -A                         # añade la estructura correcta
git commit -m "Reorganiza en estructura de carpetas y corrige .gitignore"
git branch -M main
git push origin main
