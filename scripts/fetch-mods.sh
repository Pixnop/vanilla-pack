#!/usr/bin/env bash
# Recupere les mods du pack depuis le Mod DB, d'apres mods.manifest.
# Le depot ne redistribue pas les binaires: ils appartiennent a leurs auteurs.
#
# N'utilise que curl et sed, disponibles y compris dans Git Bash sous Windows.
# Surtout pas python ni jq: sous Windows, "python3" tombe sur le raccourci
# Microsoft Store, qui affiche un message d'aide et ne renvoie rien.
set -euo pipefail

cd "$(dirname "$0")/.."
MANIFEST=mods.manifest
DEST=mods
MODDB=https://mods.vintagestory.at
# Le Mod DB veut une version de jeu, mais quand la spec porte "@version" il sert
# la version demandee sans filtrer dessus. On reste donc reproductible.
GV="${VS_VERSION:-1.22.6}"

command -v curl >/dev/null || { echo "curl est requis" >&2; exit 1; }
command -v sed  >/dev/null || { echo "sed est requis" >&2; exit 1; }
mkdir -p "$DEST"

ok=0; skip=0; fail=0
while IFS=$'\t' read -r modid version filename || [ -n "${modid:-}" ]; do
  # Tolere les fins de ligne CRLF si le fichier a transite par Windows.
  modid=$(printf '%s' "${modid:-}"    | tr -d '\r')
  version=$(printf '%s' "${version:-}" | tr -d '\r')
  filename=$(printf '%s' "${filename:-}" | tr -d '\r')
  case "$modid" in ''|\#*) continue ;; esac
  [ -n "$version" ] && [ -n "$filename" ] || { echo "  IGNORE ligne mal formee: $modid" >&2; continue; }

  if [ -f "$DEST/$filename" ]; then
    skip=$((skip+1)); continue
  fi

  resp=$(curl -sS --fail --max-time 30 \
    "${MODDB}/api/v2/mods/install-information?gv=${GV}&ids=${modid}%40${version}" 2>/dev/null) || resp=''

  # {"data":{"<modid>":{"fileName":"...","fileUrl":"\/download\/123\/x.zip"}}}
  url=$(printf '%s' "$resp" | sed -n 's/.*"fileUrl":"\([^"]*\)".*/\1/p' | sed 's|\\/|/|g')

  if [ -z "$url" ]; then
    code=$(printf '%s' "$resp" | sed -n 's/.*"errorCode":\([0-9]*\).*/\1/p' | head -1)
    echo "  ECHEC  $modid $version : ${code:+erreur Mod DB $code}${code:-pas de reponse exploitable}" >&2
    fail=$((fail+1)); continue
  fi
  case "$url" in /*) url="${MODDB}${url}" ;; esac

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

# Purge des zips qui ne sont plus au manifeste. Sans ca, changer la version d'un
# mod laisse l'ancien fichier a cote du nouveau: deux zips declarent alors le
# meme modid, et le serveur en charge un au hasard. Vu en production avec
# vanillapackfr 0.1.0 et 0.1.1 presents en meme temps.
# cut decoupe sur la tabulation sans ambiguite. Surtout pas de sed avec [^\t]:
# dans une classe de caracteres, \t vaut "ni antislash ni t", pas une tabulation.
attendus=$(grep -v '^#' "$MANIFEST" | cut -f3 | tr -d '\r' | grep -v '^$')
echo "manifeste: $(printf '%s\n' "$attendus" | grep -c .) fichiers attendus"
purge=0
for f in "$DEST"/*.zip; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  if ! printf '%s\n' "$attendus" | grep -qxF "$base"; then
    rm -f "$f"
    echo "  purge  $base (absent du manifeste)"
    purge=$((purge+1))
  fi
done
[ "$purge" -gt 0 ] && echo "$purge fichier(s) obsolete(s) supprime(s)"

[ "$fail" -eq 0 ]
