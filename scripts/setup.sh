#!/usr/bin/env bash
# Prepare un clone pour qu'il tourne: .env avec des secrets frais, PUID/PGID
# corrects, et les mods recuperes depuis le Mod DB.
#
#   ./scripts/setup.sh && docker compose up -d
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env existe deja, je n'y touche pas."
else
  cp .env.example .env
  # Le proxy refuse de demarrer sur un bind registry non-loopback tant que le
  # secret vaut sa valeur par defaut, donc on en genere un vrai tout de suite.
  if command -v openssl >/dev/null; then
    secret=$(openssl rand -hex 32)
    token=$(openssl rand -hex 24)
  else
    secret=$(head -c32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    token=$(head -c24 /dev/urandom | od -An -tx1 | tr -d ' \n')
  fi
  sed -i "s|^NIMBUS_SHARED_SECRET=.*|NIMBUS_SHARED_SECRET=${secret}|" .env
  sed -i "s|^METRICS_TOKEN=.*|METRICS_TOKEN=${token}|" .env
  # Les conteneurs tournent sous cette identite. Si elle ne correspond pas au
  # compte qui lance la stack, ils bouclent faute d'ecrire dans worlds/.
  sed -i "s|^PUID=.*|PUID=$(id -u)|" .env
  sed -i "s|^PGID=.*|PGID=$(id -g)|" .env
  echo ".env cree: secrets generes, PUID=$(id -u) PGID=$(id -g)."
fi

echo
echo "Recuperation des mods depuis le Mod DB..."
./scripts/fetch-mods.sh

cat <<'EOF'

Pret. Lance la stack avec:

  docker compose up -d

Deux choses a regler toi-meme selon l'usage:
  - VS_ADMINS dans .env, au format "uid:pseudo". L'uid se lit dans
    worlds/<monde>/Playerdata/playerdata.json apres une premiere connexion.
  - REDIRECT_ADDRESS dans .env si les joueurs ne passent pas par localhost,
    sinon leur client tentera de se reconnecter sur un nom de conteneur.
EOF
