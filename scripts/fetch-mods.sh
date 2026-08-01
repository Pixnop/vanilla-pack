#!/usr/bin/env bash
# Recupere les mods du pack depuis le Mod DB, d'apres mods.manifest.
# Le depot ne redistribue pas les binaires : ils appartiennent a leurs auteurs.
set -euo pipefail

cd "$(dirname "$0")/.."
MANIFEST=mods.manifest
DEST=mods

command -v python3 >/dev/null || { echo "python3 est requis" >&2; exit 1; }
command -v curl    >/dev/null || { echo "curl est requis" >&2; exit 1; }
mkdir -p "$DEST"

ok=0; skip=0; fail=0
while IFS=$'\t' read -r modid version filename; do
  case "$modid" in ''|\#*) continue ;; esac

  if [ -f "$DEST/$filename" ]; then
    skip=$((skip+1)); continue
  fi

  url=$(curl -sS --fail --max-time 30 "https://mods.vintagestory.at/api/mod/$modid" 2>/dev/null \
        | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
want = sys.argv[1]
for r in (d.get("mod") or {}).get("releases") or []:
    if r.get("modversion") == want:
        print(r.get("mainfile") or "")
        break
' "$version") || true

  if [ -z "$url" ]; then
    echo "  ECHEC  $modid $version : version introuvable sur le Mod DB" >&2
    fail=$((fail+1)); continue
  fi

  if curl -sS --fail --location --max-time 300 -o "$DEST/$filename.part" "$url"; then
    mv "$DEST/$filename.part" "$DEST/$filename"
    echo "  ok     $filename"
    ok=$((ok+1))
  else
    rm -f "$DEST/$filename.part"
    echo "  ECHEC  $modid $version : telechargement" >&2
    fail=$((fail+1))
  fi
done < "$MANIFEST"

echo
echo "$ok telecharge(s), $skip deja present(s), $fail echec(s)"
[ "$fail" -eq 0 ]
