#!/usr/bin/env bash
set -euo pipefail

DATA=/data
mkdir -p "$DATA/Mods" "$DATA/ModConfig" "$DATA/Saves"

# Le modpack de l'image fait autorite. On resynchronise a chaque demarrage pour
# qu'un rebuild suffise a mettre a jour les mods, sans laisser d'orphelins.
find "$DATA/Mods" -maxdepth 1 -name '*.zip' -delete
cp /opt/modpack/*.zip "$DATA/Mods/"

# Exclusions par monde. Certains mods ne cassent que sous un playstyle donne,
# il serait dommage de les retirer du pack entier pour autant.
for excluded in ${MODS_EXCLUDE:-}; do
  if [ -f "$DATA/Mods/$excluded" ]; then
    rm -f "$DATA/Mods/$excluded"
    echo "[entrypoint] mod exclu de ce monde : $excluded"
  else
    echo "[entrypoint] MODS_EXCLUDE mentionne '$excluded', absent du pack" >&2
  fi
done

rm -rf "$DATA/Mods/Nimbus.ServerMod"
cp -r /opt/nimbus-servermod "$DATA/Mods/Nimbus.ServerMod"

# Config du mod backend, regeneree depuis l'environnement a chaque demarrage :
# c'est compose qui fait foi, pas un fichier edite a la main dans le volume.
jq -n \
  --arg id       "$NIMBUS_SERVER_ID" \
  --arg name     "$NIMBUS_DISPLAY_NAME" \
  --arg host     "$NIMBUS_PUBLIC_HOST" \
  --argjson port "$NIMBUS_PUBLIC_PORT" \
  --arg registry "$NIMBUS_REGISTRY_URL" \
  --arg secret   "$NIMBUS_SHARED_SECRET" \
  --argjson reservation "$NIMBUS_RESERVATION_REQUIRED" \
  '{
     Enabled: true,
     ServerId: $id,
     DisplayName: $name,
     PublicHost: $host,
     PublicPort: $port,
     RegistryUrl: $registry,
     SharedSecret: $secret,
     ReservationRequired: $reservation
   }' > "$DATA/ModConfig/nimbus-server.json"

# serverconfig.json : pose depuis le modele au premier demarrage seulement.
# Le modele vient d'un serveur 1.22.6 reel, pas d'une config ecrite a la main.
if [ ! -f "$DATA/serverconfig.json" ]; then
  echo "[entrypoint] premier demarrage, pose de serverconfig.json depuis le modele"
  cp /opt/serverconfig.template.json "$DATA/serverconfig.json"
fi

# Ensuite on ne reecrit que les cles pilotees par compose, pour ne pas ecraser
# les reglages que tu ajusteras dans le fichier (roles, privileges, PvP...).
tmp=$(mktemp)
jq \
  --arg name      "$VS_SERVER_NAME" \
  --arg role      "$VS_DEFAULT_ROLE" \
  --arg world     "$VS_WORLD_NAME" \
  --arg play      "$VS_PLAYSTYLE" \
  --arg playlang  "$VS_PLAYSTYLE_LANG" \
  --argjson port  "$VS_PORT" \
  --argjson max   "$VS_MAX_CLIENTS" \
  --argjson wl    "${VS_WHITELIST_MODE:-1}" \
  --argjson verifyauth "${VS_VERIFY_AUTH:-true}" \
  '.ServerName = $name
   | .Port = $port
   | .MaxClients = $max
   | .AdvertiseServer = false
   | .Upnp = false
   # EnumWhitelistMode : 0 Default, 1 Off, 2 On. Sur un serveur dedie, Default
   # vaut whitelist active, ce qui refuse tout le monde. On coupe par defaut :
   # les backends sont prives et c est le proxy qui filtre, via ReservationRequired.
   | .WhitelistMode = $wl
   # Revalidation de la session aupres du serveur d auth d Anego. Le jeton est
   # a usage unique : si deux backends le presentent, le second se voit repondre
   # {"valid":0,"reason":"missingaccount"}. Voir le README.
   | .VerifyPlayerAuth = $verifyauth
   | .DefaultRoleCode = $role
   | .ModPaths = ["Mods", "/data/Mods"]
   | .WorldConfig.WorldName = $world
   | .WorldConfig.PlayStyle = $play
   | .WorldConfig.PlayStyleLangCode = $playlang
   | .WorldConfig.SaveFileLocation = "/data/Saves/world.vcdbs"' \
  "$DATA/serverconfig.json" > "$tmp" && mv "$tmp" "$DATA/serverconfig.json"

# Reglages de generation des mods, sous forme d'une chaine JSON echappee dans
# WorldConfiguration. Ils ne prennent effet qu'a la creation du monde : les
# changer sur un monde existant ne regenere pas le terrain deja ecrit.
if [ -n "${VS_WORLDCONFIG:-}" ]; then
  if ! echo "$VS_WORLDCONFIG" | jq -e . >/dev/null 2>&1; then
    echo "[entrypoint] VS_WORLDCONFIG n'est pas du JSON valide, ignore" >&2
  else
    tmp=$(mktemp)
    jq --arg wc "$(echo "$VS_WORLDCONFIG" | jq -c .)" \
       '.WorldConfig.WorldConfiguration = $wc' \
       "$DATA/serverconfig.json" > "$tmp" && mv "$tmp" "$DATA/serverconfig.json"
    echo "[entrypoint] WorldConfiguration: $(echo "$VS_WORLDCONFIG" | jq -c .)"
  fi
fi

# Administrateurs, sous forme "uid:pseudo" separes par des espaces. Applique
# avant le demarrage du serveur, qui garde ensuite les donnees joueur en memoire
# et reecrit le fichier lui-meme. Idempotent : relancer ne duplique rien.
if [ -n "${VS_ADMINS:-}" ]; then
  # Sur un monde neuf, Playerdata/ n'existe pas encore : c'est le serveur qui le
  # cree au premier demarrage, or on passe avant lui.
  mkdir -p "$DATA/Playerdata"
  PD="$DATA/Playerdata/playerdata.json"
  [ -f "$PD" ] || echo '[]' > "$PD"
  for entry in $VS_ADMINS; do
    uid="${entry%%:*}"; pseudo="${entry#*:}"
    [ -n "$uid" ] && [ "$uid" != "$entry" ] || { echo "[entrypoint] VS_ADMINS: '$entry' n'est pas au format uid:pseudo" >&2; continue; }
    tmp=$(mktemp)
    jq --arg uid "$uid" --arg name "$pseudo" '
      if any(.[]; .PlayerUID == $uid)
      then map(if .PlayerUID == $uid then .RoleCode = "admin" else . end)
      else . + [{
        PlayerUID: $uid,
        RoleCode: "admin",
        PermaPrivileges: [],
        DeniedPrivileges: [],
        PlayerGroupMemberShips: {},
        AllowInvite: true,
        LastKnownPlayername: $name,
        CustomPlayerData: {},
        ExtraLandClaimAllowance: 0,
        ExtraLandClaimAreas: 0
      }] end' "$PD" > "$tmp" && mv "$tmp" "$PD"
    echo "[entrypoint] admin: $pseudo ($uid)"
  done
fi

echo "[entrypoint] $(ls "$DATA/Mods"/*.zip | wc -l) mods + Nimbus.ServerMod, role $VS_DEFAULT_ROLE, playstyle $VS_PLAYSTYLE"

exec /opt/stratum/StratumServer --dataPath="$DATA" --stratum-no-banner
