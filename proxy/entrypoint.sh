#!/usr/bin/env bash
set -euo pipefail

cd /opt/nimbus

# Le proxy lit nimbus.proxy.toml a cote du binaire. On le regenere a chaque
# demarrage depuis l'environnement, comme le fait l'egg officiel a l'install.
cat > nimbus.proxy.toml <<EOF
bind = "0.0.0.0:${PROXY_PORT}"
try = [ "${DEFAULT_BACKEND}" ]

[servers]
# ProxyConfig.cs initialise ce dictionnaire avec default = 127.0.0.1:42421 et
# nos entrees s'y ajoutent sans l'ecraser. Sans redefinition explicite, le
# backend 'default' reste dans le pool et c'est lui qui recoit l'UDP, vers une
# adresse qui ne mene nulle part dans le conteneur proxy.
default = "${SURVIVAL_ADDR}"
survival = "${SURVIVAL_ADDR}"
creative = "${CREATIVE_ADDR}"

[registry]
mode = "embedded"
# Les backends envoient leur heartbeat ici. Doit rester joignable depuis eux.
embedded_bind = "http://0.0.0.0:${REGISTRY_PORT}"
# Le proxy refuse de demarrer sur un bind registry non-loopback tant que ce
# secret vaut la valeur par defaut. Il est genere dans .env.
embedded_shared_secret = "${NIMBUS_SHARED_SECRET}"

[metrics]
enabled = true
# Bind sur 0.0.0.0 parce que la publication de port docker passe par l'interface
# du conteneur. Cote hote le mapping est restreint a 127.0.0.1, et le token
# ci-dessous protege /status, que le proxy signale sinon comme ouvert a tous.
bind = "http://0.0.0.0:${METRICS_PORT}"
status_api_token = "${METRICS_TOKEN}"
EOF

echo "[entrypoint] proxy sur :${PROXY_PORT}, backends survival=${SURVIVAL_ADDR} creative=${CREATIVE_ADDR}"

exec dotnet Nimbus.Proxy.dll
