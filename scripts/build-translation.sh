#!/usr/bin/env bash
# Empaquette translation-fr/ en un mod installable.
#
# Le zip est produit avec des separateurs "/" et modinfo.json a la racine. Ces
# deux details ne sont pas cosmetiques: le French Translation Pack du Mod DB
# utilise des antislashes, et comme Vintage Story extrait les mods de contenu
# avec Path.Combine, l'arborescence n'est pas recreee sous Linux. Ses fichiers
# de langue ne sont alors jamais trouves.
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=translation-fr
OUT=dist

command -v python3 >/dev/null || { echo "python3 est requis pour empaqueter" >&2; exit 1; }
[ -f "$SRC/modinfo.json" ] || { echo "$SRC/modinfo.json introuvable" >&2; exit 1; }

mkdir -p "$OUT"
python3 - "$SRC" "$OUT" <<'PY'
import json, os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
info = json.load(open(os.path.join(src, 'modinfo.json'), encoding='utf-8-sig'))
name = f"{info['modid']}-{info['version']}.zip"
path = os.path.join(out, name)
count = 0
with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            full = os.path.join(root, f)
            rel = os.path.relpath(full, src).replace(os.sep, '/')
            if rel.startswith('.todo/'):
                continue
            z.write(full, rel)
            if rel.endswith('fr.json'):
                count += 1
strings = 0
for root, _, files in os.walk(os.path.join(src, 'assets')):
    for f in files:
        if f == 'fr.json':
            strings += len(json.load(open(os.path.join(root, f), encoding='utf-8')))
print(f"{path}")
print(f"  {count} fichiers de langue, {strings} chaines")
PY
