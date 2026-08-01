# vs-network

Réseau Vintage Story en trois conteneurs : un proxy Nimbus devant deux mondes,
survie et créatif, tous les deux sous le runtime Stratum avec ton modpack.

```
              joueurs
                 │
                 ▼
         nimbus  :42420          ← seul port publié
     (registry embarqué :8765)
                 │
        ┌────────┴────────┐
        ▼                 ▼
  survival :42421   creative :42422     ← privés, réseau docker uniquement
```

## Démarrer

Le dépôt ne contient pas les binaires des mods. Récupère-les d'abord depuis le
Mod DB, d'après `mods.manifest` :

```bash
./scripts/fetch-mods.sh
```

Copie ensuite `.env.example` en `.env`, mets un vrai secret dans
`NIMBUS_SHARED_SECRET` et un token dans `METRICS_TOKEN`, puis lance :

```bash
docker compose up -d
```

Les joueurs se connectent à l'adresse du proxy, port 42420. Une fois en jeu,
`/server creative` ou `/server survival` fait passer d'un monde à l'autre. Il
leur faut RedirectFix, voir plus bas.

## Ce qu'il y a dans les images

Le backend part de `mcr.microsoft.com/dotnet/runtime:10.0`, parce que le serveur
Vintage Story 1.22.6 déclare `net10.0` dans son `runtimeconfig.json`. Le proxy
part de `dotnet/aspnet:10.0`, parce que `Nimbus.Proxy.runtimeconfig.json`
réclame en plus `Microsoft.AspNetCore.App`.

Stratum est un binaire unique de 19 Mo. Au premier lancement il récupère
l'archive serveur officielle via le manifeste d'Anego, la vérifie et pose ses
fichiers patchés dessus. Le `Dockerfile` fait ça au build avec
`--stratum-prepare-only`, donc un conteneur qui démarre ne télécharge rien.

Le modpack est copié dans l'image, pas monté. L'entrypoint resynchronise
`/data/Mods` à chaque démarrage : pour changer un mod, tu modifies `mods/` et tu
reconstruis, et les zips retirés disparaissent au lieu de traîner.

## Les mods

44 mods au départ, triés par le champ `side` de leur `modinfo.json` :

| side | nombre | destination |
|---|---|---|
| universal | 40 | serveur + client |
| server | 1 | serveur seul (`pei`) |
| client | 3 | client seul |

Les trois mods client, `ancestralblissshaders`, `extrainfo` et `optitime`, ne
sont pas dans le manifeste : ils n'ont rien à faire sur un serveur.

Les zips ne sont pas versionnés ici. `mods.manifest` liste modid, version et nom
de fichier attendu, et `scripts/fetch-mods.sh` va les chercher sur le Mod DB. Le
détail par mod est dans [MODLIST.md](MODLIST.md).

## Quel Stratum tourne, et pourquoi

`STRATUM_MODE` dans `.env` choisit la source :

- `release` télécharge le zip publié pointé par `STRATUM_URL`
- `local` prend la build présente dans `stratum-local/`

Le mode actif est `local`, et c'est un choix assumé. La build publiée
`1.22.6-stratum.1-indev.1` casse `watersheds`, 225 erreurs de génération par
minute sur un monde neuf. La PR 231 de Tsu corrige ça, mesuré à 0 erreur, mais
elle n'est ni mergée ni publiée. `stratum-local/` contient donc une build faite
depuis sa branche `fix/world-gen-and-mod-compat`.

Cette branche ne compile pas telle quelle. Son `GenBlockLayers.cs.patch` déclare
un hunk de 35 lignes côté nouveau alors qu'il en contient 34, ce qui fait échouer
tout le bootstrap. Le détail et le reste des mesures sont dans
`PR231-retour-de-test.md`.

Ce que ça implique : tes mondes tournent sur un binaire construit à la main
depuis un draft. Pour reconstruire après une mise à jour de la branche, relance
`.build/build.sh` dans un conteneur `dotnet/sdk:10.0`, recopie la sortie dans
`stratum-local/`, puis rebuild l'image. Repasser `STRATUM_MODE=release` te ramène
sur du publié, au prix de `watersheds`.

`betterruins` reste exclu du monde créatif via `MODS_EXCLUDE`. La PR 231 annonce
corriger ce cas mais ne le fait pas, vérifié : 169 erreurs avant comme après. Le
mod ne pose aucun problème sur la survie, donc il n'est retiré que du créatif.

## Réglages de génération

`VS_WORLDCONFIG` porte les réglages de monde des mods, sous forme d'une chaîne
JSON injectée dans `WorldConfig.WorldConfiguration`. La survie utilise :

```json
{"landcover":"50%","oceanscale":"400%"}
```

C'est l'exigence de `rivers`, dont la fiche Mod DB dit qu'il faut des océans pour
que les rivières se génèrent, avec 300 à 500% de « landcover scale » et 50% de
« landcover ». Dans les libellés du jeu, « Landcover scale » correspond à la clé
`oceanscale`, pas à `landcover`, ce qui prête facilement à confusion.

Ces réglages ne s'appliquent qu'à la création du monde. Les changer sur un monde
existant ne régénère pas le terrain déjà écrit, il faut repartir d'un `Saves/`
vide.

## RedirectFix, à installer côté joueurs

Nimbus a besoin d'un mod client, sans quoi le jeu plante au moment d'un
transfert entre mondes.

`redirectfix` fait partie du pack serveur, alors qu'il est marqué
`RequiredOnClient: true` et `RequiredOnServer: false`. C'est voulu : c'est sa
présence côté serveur qui déclenche le téléchargement automatique chez le
client, depuis le Mod DB, à la connexion. Sans ça chaque joueur devrait
l'installer à la main.

Une réserve avant d'ouvrir aux joueurs. La release publiée sur le Mod DB est la
1.0.0, déclarée compatible `1.22.0`, `1.22.1` et `1.22.2` seulement. Rien pour
1.22.6. Le zip lui-même fonctionne, vérifié en le chargeant sur un serveur
1.22.6, mais un client peut refuser une release que le Mod DB n'annonce pas
compatible, et le joueur se retrouverait alors bloqué à la connexion au lieu de
simplement planter au transfert.

Le vrai correctif est côté Mod DB : y publier la 1.0.1 en la taguant 1.22.6. La
fiche est au nom de `imtsubaki` et n'a pas de contributeur, donc c'est lui qui
doit le faire.

À noter, c'est la 1.0.0 du Mod DB qui est dans le pack serveur, pas la 1.0.1 de
GitHub. C'est volontaire : le client télécharge la version que le serveur exige,
donc réclamer une 1.0.1 absente du Mod DB ferait échouer l'auto-installation à
coup sûr. Avec la 1.0.0 les versions concordent et il ne reste que le tag comme
inconnue.

Si un client se fait refuser à la connexion, coupe le mod sans reconstruire
l'image en ajoutant ceci aux deux backends dans `docker-compose.yml`, puis
`docker compose up -d` :

```yaml
MODS_EXCLUDE: "redirectfix-1.0.0.zip"
```

Les joueurs devront alors installer la
[v1.0.1](https://github.com/StratumServer/redirectfix/releases/tag/v1.0.1) à la
main dans leur dossier `Mods`.

À ne pas confondre : l'asset GitHub de la v1.0.0 était mal emballé, tout dans un
dossier `redirectfix/` donc pas de `modinfo.json` à la racine, et ne se chargeait
pas. Le zip hébergé sur le Mod DB, lui, est correct. La v1.0.1 est packagée en CI
et corrige l'asset GitHub.

## Configuration

Tout se règle dans `.env` et dans les blocs `environment` de
`docker-compose.yml`. Le fichier `.env` contient le secret partagé entre le
proxy et les backends, généré aléatoirement, et il est dans `.gitignore`.

`backend/serverconfig.template.json` vient d'un serveur 1.22.6 qui a réellement
tourné, ce n'est pas une config écrite à la main. Il n'est posé qu'au premier
démarrage d'un monde. Ensuite l'entrypoint ne réécrit que les clés pilotées par
compose, donc tes réglages de rôles, privilèges ou PvP survivent aux redémarrages.

Le monde créatif utilise le rôle `crplayer`, qui porte `DefaultGameMode: 2`, et
le playstyle `creativebuilding`. Ce playstyle donne un terrain plat et vide.
Si tu préfères construire sur du relief normal, remplace `VS_PLAYSTYLE` par
`surviveandbuild` en gardant le rôle `crplayer`.

## Sauvegardes

Les mondes sont des bind mounts dans `worlds/`, pas des volumes nommés, pour que
tu puisses les copier directement. `stop_grace_period` est à 2 minutes : Vintage
Story sauvegarde en s'arrêtant, il ne faut pas le tuer trop tôt.

## Versions épinglées

| Composant | Version |
|---|---|
| Vintage Story | 1.22.6 |
| Stratum | PR 231 `fix/world-gen-and-mod-compat` @ 7ff2709, build locale |
| Nimbus | v0.2.0 |
| RedirectFix | 1.0.0 depuis le Mod DB, dans le pack serveur |

La release publiée la plus proche est `v1.22.6-stratum.1-indev.1`, elle-même un
prerelease indev. La dernière vraiment stable est `v1.22.5-stratum.1`, qui
imposerait de jouer en 1.22.5.
