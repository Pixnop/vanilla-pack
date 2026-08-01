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

```bash
./scripts/setup.sh
docker compose up -d
```

`setup.sh` crée le `.env` avec des secrets frais et les bons `PUID`/`PGID`, puis
récupère les mods depuis le Mod DB d'après `mods.manifest`. Les binaires des mods
ne sont pas versionnés ici, ils appartiennent à leurs auteurs.

Restent deux réglages à faire selon l'usage : `VS_ADMINS` pour te donner le rôle
admin, et `REDIRECT_ADDRESS` si les joueurs ne passent pas par localhost.

Les joueurs se connectent à l'adresse du proxy, port 42420. Une fois en jeu,
`/server creative` ou `/server survival` fait passer d'un monde à l'autre. Il
leur faut RedirectFix, voir plus bas.

## Sous Windows

La stack tourne en conteneurs Linux, donc via Docker Desktop avec le moteur
WSL2. Lance les scripts depuis Git Bash, livré avec Git for Windows :

```bash
bash scripts/setup.sh
docker compose up -d
```

Le `.gitattributes` force les fins de ligne en LF sur les scripts. Sans lui, Git
for Windows les convertit en CRLF au checkout et les conteneurs meurent aussitôt
sur `bad interpreter: /bin/bash^M`. Ne le supprime pas, et si tu as cloné avant
son ajout, refais un clone propre plutôt que de corriger à la main.

`setup.sh` renseigne `PUID` et `PGID` depuis `id -u` et `id -g`. Sous Git Bash
ces commandes renvoient des identifiants Windows qui n'ont pas de sens pour un
conteneur. Si les backends bouclent sur un redémarrage en se plaignant de ne pas
pouvoir écrire dans `/data`, mets `PUID=0` et `PGID=0` dans `.env` : les
conteneurs tourneront en root, ce qui est sans conséquence ici puisque les
montages passent par la VM de Docker Desktop.

Le plus confortable reste de cloner dans le système de fichiers WSL2, par exemple
sous `\\wsl$\Ubuntu\home\...`, plutôt que sur un chemin `C:\`. Les
performances de montage sont bien meilleures et les permissions se comportent
normalement.

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

43 mods au départ, triés par le champ `side` de leur `modinfo.json` :

| side | nombre | destination |
|---|---|---|
| universal | 39 | serveur + client |
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

Le mode par défaut est `local`, et c'est un choix assumé. La build publiée
`1.22.6-stratum.1-indev.1` casse `watersheds`, 225 erreurs de génération par
minute sur un monde neuf. La PR 231 de Tsu corrige ça, mesuré à 0 erreur, mais
elle n'est ni mergée ni publiée.

`stratum-local/` est donc versionné et porte cette build, pour qu'un clone
reproduise l'état qui tourne ici sans étape supplémentaire. Stratum est sous
licence MIT, sa `LICENSE` est jointe et `stratum-local/PROVENANCE.md` dit d'où
vient exactement le binaire et quand le supprimer.

Cette branche ne compile pas telle quelle. Son `GenBlockLayers.cs.patch` déclare
un hunk de 35 lignes côté nouveau alors qu'il en contient 34, ce qui fait échouer
tout le bootstrap. Le détail et le reste des mesures sont dans
`PR231-retour-de-test.md`.

Ce que ça implique : les mondes tournent sur un binaire construit à la main
depuis un draft. Pour le reconstruire :

```bash
./scripts/build-stratum.sh fix/world-gen-and-mod-compat
```

Le script fait tout dans un conteneur `dotnet/sdk:10.0`, rien n'est installé sur
l'hôte, et dépose le résultat dans `stratum-local/`. Il a besoin du dossier `Lib`
d'une installation cliente, via `CLIENT_LIB_DIR`, parce que le bootstrap
décompile `VintagestoryLib`, qui référence `csogg` et `csvorbis`, absents de
l'archive serveur.

Repasser `STRATUM_MODE=release` ramène sur du publié, au prix de `watersheds`.

`betterruins` reste exclu du monde créatif via `MODS_EXCLUDE`. La PR 231 annonce
corriger ce cas mais ne le fait pas, vérifié : 169 erreurs avant comme après. Le
mod ne pose aucun problème sur la survie, donc il n'est retiré que du créatif.

## Réglages de génération

`VS_WORLDCONFIG` porte les réglages de monde des mods, sous forme d'une chaîne
JSON injectée dans `WorldConfig.WorldConfiguration`. La survie utilise :

```json
{"landcover":"0.5","oceanscale":"4"}
```

C'est l'exigence de `rivers`, dont la fiche Mod DB dit qu'il faut des océans pour
que les rivières se génèrent, avec 300 à 500% de « landcover scale » et 50% de
« landcover ». Deux pièges à cet endroit.

« Landcover scale » correspond à la clé `oceanscale`, pas à `landcover`.

Et surtout, ce sont les valeurs qu'il faut écrire, pas les libellés.
`AssemblyInfo.cs` de VSSurvivalMod définit `landcover` avec
`values: ["0" … "1"]` pour `names: ["~0%" … "100%"]`, et `oceanscale` avec
`values: ["0.1" … "5"]` pour `names: ["10%" … "500%"]`. Or `GenMaps` fait
`worldConfig.GetString("landcover", "1").ToFloat(1f)`, et `ToFloat` s'appuie sur
`float.TryParse` en `NumberStyles.Any`, qui refuse le signe pourcent. Écrire
`"50%"` retombe donc silencieusement sur `1`, soit 100% de terre et pas un seul
océan.

Ces réglages ne s'appliquent qu'à la création du monde. Les changer sur un monde
existant ne régénère pas le terrain déjà écrit, il faut repartir d'un `Saves/`
vide.

## RedirectFix, à installer côté joueurs

Nimbus a besoin d'un mod client, sans quoi le jeu plante au moment d'un
transfert entre mondes.

**Installation manuelle obligatoire pour l'instant.** Envoie ce lien à tes
joueurs, à décompresser dans leur dossier `Mods` :

<https://github.com/StratumServer/redirectfix/releases/tag/v1.0.1>

L'idée naturelle serait de mettre `redirectfix` dans le pack serveur : le mod est
marqué `RequiredOnClient: true`, donc sa présence côté serveur déclencherait le
téléchargement automatique chez le client depuis le Mod DB. Ça ne marche pas
aujourd'hui, et c'est vérifiable sans lancer le jeu.

`ModDbUtil.cs` montre que le client résout ses mods via
`v2/mods/install-information?gv=<version>&ids=<modids>`. La même requête, posée à
la main :

```
gv=1.22.6  ->  { "redirectfix": { "errorCode": 4041 } }
gv=1.22.2  ->  { "fileName": "redirectfix-v1.0.0.zip", "fileUrl": "/download/95008/..." }
```

`4041` est `SPEC_NOT_FOUND`, que le joueur verrait sous la forme « Release not
found. ». La fiche Mod DB est bloquée en 1.0.0, taguée `1.22.0` à `1.22.2`, alors
que la 1.0.1 est sortie côté GitHub. Mettre le mod dans le pack serveur
demanderait donc aux clients une release que le Mod DB refuse de leur servir.

Le correctif est côté Mod DB : y publier la 1.0.1 en la taguant 1.22.6. La fiche
est au nom de `imtsubaki` et sans contributeur, c'est donc lui qui doit le faire.
Une fois que `gv=1.22.6` renverra un `fileUrl`, remets la ligne
`redirectfix<TAB>1.0.1<TAB>redirectfix-1.0.1.zip` dans `mods.manifest`, relance
`scripts/fetch-mods.sh` et reconstruis : l'installation deviendra automatique.

À ne pas confondre avec l'autre bug : l'asset GitHub de la v1.0.0 était mal
emballé, tout dans un dossier `redirectfix/` donc pas de `modinfo.json` à la
racine, et ne se chargeait pas. Le zip hébergé sur le Mod DB, lui, est correct.
La v1.0.1 est packagée en CI et corrige l'asset GitHub.

## Transferts entre mondes

`/server creative` et `/server survival` en jeu, ou les raccourcis `/crea` et
`/survie` déclarés par backend dans `NIMBUS_SHORTCUTS`. Un raccourci vers le
monde courant n'est jamais retenu, donc chaque monde ne déclare que l'autre. Les joueurs ont besoin de
[RedirectFix](https://github.com/StratumServer/redirectfix) 1.0.1 ou plus récent,
le plantage à la redirection est toujours là en 1.22.6.

Nimbus 0.2.0 cassait tous les transferts sur 1.22.6 : le proxy supposait que la
première trame du client était `Identification`, alors que c'est
`LoginTokenQuery`, qui ne porte aucune identité. La reconnexion partait sur le
backend par défaut, le jeton de session à usage unique était rejoué vers la
destination, et celle-ci renvoyait « Bad game session ». Corrigé en 0.3.0 : la
reconnexion est routée par adresse client quand la première trame est anonyme, et
un garde-fou refuse de présenter le même login à un second backend.

`REDIRECT_ADDRESS` dans `.env` tamponne une adresse `hôte:port` dans les paquets
de redirection. À renseigner dès que les joueurs passent par autre chose que
localhost, sinon le client se reconnecte sur l'adresse annoncée par le backend.

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

## Administrateurs

`VS_ADMINS` dans `.env` prend une liste `uid:pseudo` séparée par des espaces, et
l'entrypoint force le `RoleCode` à `admin` dans `Playerdata/playerdata.json` des
deux mondes avant que le serveur démarre. C'est idempotent, et ça crée l'entrée
si le joueur ne s'est encore jamais connecté.

L'uid se lit dans `worlds/<monde>/Playerdata/playerdata.json` après une première
connexion. Il reste dans `.env`, qui n'est pas versionné : c'est un identifiant
de compte, il n'a rien à faire dans un dépôt public.

Le fichier n'est pas modifiable à chaud : le serveur garde les données joueur en
mémoire et réécrit le fichier lui-même à la sauvegarde. D'où le passage par
l'entrypoint plutôt qu'une édition directe.

## Sauvegardes

Les mondes sont des bind mounts dans `worlds/`, pas des volumes nommés, pour que
tu puisses les copier directement. `stop_grace_period` est à 2 minutes : Vintage
Story sauvegarde en s'arrêtant, il ne faut pas le tuer trop tôt.

## Versions épinglées

| Composant | Version |
|---|---|
| Vintage Story | 1.22.6 |
| Stratum | PR 231 `fix/world-gen-and-mod-compat` @ 7ff2709, build locale |
| Nimbus | v0.3.0 |
| RedirectFix | v1.0.1, installation manuelle côté joueur |

La release publiée la plus proche est `v1.22.6-stratum.1-indev.1`, elle-même un
prerelease indev. La dernière vraiment stable est `v1.22.5-stratum.1`, qui
imposerait de jouer en 1.22.5.
