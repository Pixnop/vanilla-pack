#!/usr/bin/env bash
# Construit Stratum depuis une branche du depot et depose le resultat dans
# stratum-local/, pour STRATUM_MODE=local.
#
# Utile tant qu'un correctif n'est pas publie en release. Tout se passe dans un
# conteneur dotnet/sdk:10.0, rien n'est installe sur l'hote.
#
#   ./scripts/build-stratum.sh [branche]
#
# La branche par defaut est indev. Le bootstrap decompile VintagestoryLib, ce
# qui demande les DLL client csogg et csvorbis, absentes de l'archive serveur.
# CLIENT_LIB_DIR doit donc pointer sur le dossier Lib d'une install cliente.
set -euo pipefail

cd "$(dirname "$0")/.."
BRANCH="${1:-indev}"
WORK=".build"
CLIENT_LIB_DIR="${CLIENT_LIB_DIR:-$HOME/.config/VSLGameVersions/1.22.6/Lib}"

if [ ! -f "$CLIENT_LIB_DIR/csogg.dll" ]; then
  echo "csogg.dll introuvable dans $CLIENT_LIB_DIR" >&2
  echo "Renseigne CLIENT_LIB_DIR avec le dossier Lib d'une install Vintage Story." >&2
  exit 1
fi

mkdir -p "$WORK"
cat > "$WORK/_build-inner.sh" <<'INNER'
#!/usr/bin/env bash
set -euo pipefail
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
trap 'chown -R "${HOST_UID}:${HOST_GID}" /work 2>/dev/null || true' EXIT

apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  git perl python3 curl tar unzip ca-certificates make >/dev/null

cd /work
if [ ! -d Stratum ]; then
  git clone --depth 1 --branch "$BRANCH" https://github.com/StratumServer/Stratum.git
fi
cd Stratum
git fetch --depth 1 origin "$BRANCH" && git checkout -q FETCH_HEAD
echo "HEAD: $(git rev-parse --short HEAD) $(git log -1 --format=%s)"

export PATH="$PATH:/root/.dotnet/tools"
make bootstrap CLIENT_LIB_DIR=/clientlib
make build     CLIENT_LIB_DIR=/clientlib
INNER
chmod +x "$WORK/_build-inner.sh"

docker run --rm \
  -e BRANCH="$BRANCH" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$PWD/$WORK:/work" \
  -v "$CLIENT_LIB_DIR:/clientlib:ro" \
  mcr.microsoft.com/dotnet/sdk:10.0 bash /work/_build-inner.sh

OUT="$WORK/Stratum/StratumServer/bin/Release/net10.0"
[ -f "$OUT/StratumServer" ] || { echo "build sans sortie exploitable" >&2; exit 1; }

rm -rf stratum-local
mkdir -p stratum-local
cp -r "$OUT/." stratum-local/
touch stratum-local/.gitkeep
echo
echo "stratum-local/ mis a jour depuis la branche $BRANCH."
echo "Mets STRATUM_MODE=local dans .env, puis: docker compose build && docker compose up -d"
