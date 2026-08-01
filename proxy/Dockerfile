# Proxy Nimbus. Nimbus.Proxy.runtimeconfig.json demande Microsoft.NETCore.App 10
# ET Microsoft.AspNetCore.App 10, d'ou l'image aspnet et non runtime.
FROM mcr.microsoft.com/dotnet/aspnet:10.0

ARG NIMBUS_URL

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip tini \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/nimbus

RUN curl -fsSL -o /tmp/nimbus.zip "${NIMBUS_URL}" \
 && unzip -q /tmp/nimbus.zip -d /tmp/nimbus \
 && cp -r "$(find /tmp/nimbus -type d -name Nimbus | head -1)/." /opt/nimbus/ \
 && rm -rf /tmp/nimbus /tmp/nimbus.zip

COPY proxy/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
