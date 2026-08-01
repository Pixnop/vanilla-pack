# Backend Vintage Story : runtime Stratum + modpack + mod backend Nimbus.
# Le serveur VS 1.22.6 cible net10.0, d'ou l'image runtime .NET 10.
FROM mcr.microsoft.com/dotnet/runtime:10.0

ARG STRATUM_URL
ARG NIMBUS_URL
# release : on telecharge le zip publie. local : on prend la build presente dans
# stratum-local/, produite depuis une branche du depot Stratum.
ARG STRATUM_MODE=release
ARG PUID=1000
ARG PGID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip jq tini \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/stratum

# Toujours copie, meme vide, sinon le COPY echoue en mode release.
COPY stratum-local/ /opt/stratum-local/

RUN if [ "$STRATUM_MODE" = "local" ]; then \
      echo "Stratum: build locale depuis stratum-local/" ; \
      test -f /opt/stratum-local/StratumServer || { echo "stratum-local/ ne contient pas StratumServer" >&2; exit 1; } ; \
      cp -a /opt/stratum-local/. /opt/stratum/ ; \
    else \
      echo "Stratum: release publiee" ; \
      curl -fsSL -o /tmp/stratum.zip "${STRATUM_URL}" ; \
      unzip -q /tmp/stratum.zip -d /opt/stratum ; \
      rm /tmp/stratum.zip ; \
    fi \
 && rm -rf /opt/stratum-local \
 && chmod +x /opt/stratum/StratumServer

# Au premier lancement, Stratum telecharge l'archive serveur officielle via le
# manifeste d'Anego, la verifie, la deballe et pose ses fichiers patches dessus.
# On le fait ici : les conteneurs demarrent ensuite sans rien telecharger.
RUN /opt/stratum/StratumServer --stratum-prepare-only --stratum-no-banner

# Mod backend Nimbus, sous forme de dossier comme dans l'egg officiel.
RUN curl -fsSL -o /tmp/nimbus.zip "${NIMBUS_URL}" \
 && unzip -q /tmp/nimbus.zip -d /tmp/nimbus \
 && cp -r "$(find /tmp/nimbus -type d -name Nimbus.ServerMod | head -1)" /opt/nimbus-servermod \
 && rm -rf /tmp/nimbus /tmp/nimbus.zip

COPY mods/ /opt/modpack/
COPY backend/serverconfig.template.json /opt/serverconfig.template.json
COPY backend/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Le conteneur tourne sous ton uid pour que worlds/ ne finisse pas en root.
# Stratum reecrit dans son dossier quand sa version ou celle du jeu change,
# il faut donc que /opt/stratum lui appartienne aussi.
RUN chown -R "${PUID}:${PGID}" /opt/stratum /opt/modpack /opt/nimbus-servermod

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
