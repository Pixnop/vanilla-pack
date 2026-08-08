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

`setup.sh` détecte les identifiants Windows renvoyés par Git Bash, du genre
197609, et bascule `PUID`/`PGID` sur root, ce qui est sans conséquence ici
puisque les montages passent par la VM de Docker Desktop. Rien à faire de ton
côté, le script te le signale au passage.

Les scripts n'utilisent que `curl` et `sed`, fournis par Git Bash. Pas de
`python3` : sous Windows il tombe sur le raccourci Microsoft Store, qui affiche
un message d'aide au lieu d'exécuter quoi que ce soit.

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

- `release` télécharge le zip publié pointé par `STRATUM_URL`, c'est le défaut
- `local` prend une build déposée dans `stratum-local/`, pour tester une branche
  non publiée

La stack tourne sur `v1.22.6-stratum.2`, une release stable.

Ça n'a pas toujours été le cas. La première build 1.22.6 disponible,
`stratum.1-indev.1`, cassait deux mods de worldgen : `watersheds` produisait 225
erreurs de génération par minute sur un monde neuf, et `betterruins` 169 sous le
playstyle `creativebuilding`. Les deux ont été isolés mod par mod avec un témoin
sur le serveur officiel, remontés en amont, et corrigés par les PR
[228](https://github.com/StratumServer/Stratum/pull/228) et
[231](https://github.com/StratumServer/Stratum/pull/231), incluses depuis
`v1.22.6-stratum.1`. Vérifié après bascule : zéro erreur sur les deux mondes,
avec les deux mods chargés.

Le dépôt a un temps embarqué une build maison de la PR 231 pour contourner ça.
Elle a été retirée. `scripts/build-stratum.sh` reste disponible si tu veux à
nouveau tester une branche avant publication, et `PR231-retour-de-test.md` garde
la trace de la méthode.

## Stratum : BlockBreakGuards désactivé

`VS_STRATUM_CONFIG` fusionne des réglages dans `worlds/<monde>/stratum.json`.
Les deux mondes portent :

```json
{"BlockBreakGuards":{"Enabled":false},"Hardening":{"BlockBreakGuards":false}}
```

Sans ça, les toits de `vsroofing` ne se cassent pas en survie : le client joue
l'animation, puis le bloc réapparaît. Aucun message, aucune ligne de log, et
aucune violation enregistrée même avec `LogViolations` à `true`.

Isolé en changeant une variable à la fois : le même modpack sur un serveur 1.22.6
officiel casse le toit normalement, sur Stratum non, et sur Stratum avec ce
réglage désactivé oui. En créatif ça marche partout, le cassage instantané ne
passant pas par la même validation.

Le détail est dans `BUG-stratum-blockbreakguards.md`. Ce réglage saute dès que le
correctif amont sera publié.

## Réglages de génération

`VS_WORLDCONFIG` porte les réglages de monde des mods, sous forme d'une chaîne
JSON injectée dans `WorldConfig.WorldConfiguration`. La survie utilise :

```json
{"landcover":"0.5","oceanscale":"4"}
```

C'est l'exigence de `rivers`, dont la fiche Mod DB dit qu'il faut des océans pour
que les rivières se génèrent, avec 300 à 500% de « landcover scale » et 50% de
« landcover ».

Un essai à `0.7` et `3` a laissé plus de terre et rapproché les côtes, mais on
est revenu au réglage recommandé. À `0.5`, le point d'apparition peut tomber sur
un îlot isolé : la graine étant aléatoire, une régénération suffit alors à
retomber sur autre chose.

Deux pièges à cet endroit.

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

## Ce qui s'auto-installe, et ce qui ne peut pas

Sur les 42 mods du serveur, **39 se téléchargent tout seuls** chez le joueur à la
connexion. Vérifié en pratique : une instance cliente vierge a reçu les 39, y
compris `aculinaryartillery` dont le nom de fichier trompe.

Deux règles décident, et elles sont dans le code du jeu.

`ServerMain.CreatePacketIdentification` filtre `where mod.Info.Side.IsUniversal()`
avant d'annoncer quoi que ce soit. Un mod `side: client` posé sur le serveur y
est bien chargé, mais jamais annoncé, donc jamais téléchargé par personne. C'est
le cas d'`extrainfo`, `optitime` et `ancestralblissshaders` : chaque joueur les
installe pour lui, il n'y a pas moyen de les pousser depuis le serveur.

Ensuite, `SystemModHandler` ne retient côté client que les mods annoncés avec
`RequiredOnClient`. `terraprety` et `vanillapackfr` déclarent `false`, donc ils
restent sur le serveur sans être réclamés. `pei` est `side: server` et n'est même
pas annoncé.

D'où le compte : 42 moins `pei`, `terraprety` et `vanillapackfr` font 39.

On a essayé de contourner ça par les dépendances, et ça ne marche pas. L'idée
était de faire déclarer à `vanillapackfr`, qui est requis donc téléchargé, une
dépendance sur `extrainfo` : le client aurait alors proposé de récupérer la
dépendance manquante, et cette branche-là ne filtre pas sur le `side`.

En pratique le client se retrouve bloqué, avec un dialogue « Missing mods /
ModDB Error: Bad Request ». La raison est dans `SystemModHandler` :

```csharp
foreach (string modid in list5) {
    ModContainer mc = mods.FirstOrDefault(m => modid == m.Info.ModID + "@" + m.Info.NetworkVersion && m.Error.HasValue);
    if (mc != null) list7.Add(mc.Info.ModID + "@" + mc.Info.Version);
}
foreach (string item in list7) list5.Remove(item);
game.disconnectMissingMods = list5;
```

Le client possède `vanillapackfr` mais ne peut pas le charger, ses dépendances
manquant. Il compte donc comme « en erreur », le jeu le retire de la liste à
télécharger, la liste devient vide, et la requête part avec `ids=` vide. Le Mod
DB répond `HTTP 400 {"error":"Missing ids."}`.

C'est circulaire : les dépendances ne peuvent arriver que par le mod qui ne peut
pas se charger sans elles. Ça ne fonctionnerait que pour un joueur qui les a
déjà, ce qui enlève tout intérêt.

Testé deux fois, la seconde sur une base sans aucun doublon, avec
`vanillapackfr` 0.1.3 publié sur le Mod DB et les trois mods présents côté
serveur. Résultat identique : le client installe 40 mods, `vanillapackfr`
compris, et aucune des trois dépendances. L'écran suivant annonce « You are
missing 0 mods », et le téléchargement part avec `ids=` vide.

Les dépendances sont pourtant correctement déclarées : sans les trois mods, le
serveur refuse de charger `vanillapackfr` avec `Could not resolve some
dependencies`. Le jeu les lit et les honore, il ne va simplement jamais chercher
une dépendance `side: client` auprès d'un serveur.

Ce n'est pas une limite de cette configuration. L'issue
[7602](https://github.com/anegostudios/VintageStory-Issues/issues/7602) chez Anego
décrit le même cas, ouverte depuis novembre 2025 et sans réponse. Et sur le forum
officiel, quelqu'un a tenté de passer un mod de `Client` à `Universal` dans son
`modinfo.json` : ça ne fonctionne pas non plus. La réponse retenue par la
communauté est de distribuer les mods client à la main, ce que fait
`annonce-discord.md`.

Un détail qui m'avait égaré : la spec envoyée au Mod DB utilise bien
`mod.Id + "@" + mod.Version`. La `NetworkVersion` ne sert qu'à comparer les mods
locaux et distants pour repérer les manquants. C'est pourquoi
`aculinaryartillery`, qui déclare `networkVersion: 2.0.0` pour une release
`2.0.0-dev.21`, s'installe malgré tout sans problème.

## RedirectFix et la traduction française

`redirectfix` est dans le pack serveur. Il est marqué `RequiredOnClient: true`,
donc sa présence côté serveur suffit à déclencher son téléchargement automatique
chez le client depuis le Mod DB. Rien à distribuer à la main.

Ça n'a pas toujours été le cas. La fiche Mod DB est restée bloquée en 1.0.0
taguée jusqu'en 1.22.2, et `install-information?gv=1.22.6` renvoyait
`errorCode 4041`, soit `SPEC_NOT_FOUND` : impossible d'auto-installer. La 1.0.1
publiée depuis est taguée jusqu'en 1.22.6 et le Mod DB la sert correctement.

`vanillapackfr`, le pack de traductions françaises, est dans le pack serveur lui
aussi mais ne se propagera pas : son `modinfo.json` déclare
`"requiredonclient": false`, et le serveur ne réclame que les mods marqués
requis. Or ses 29 fichiers `fr.json` ne servent qu'à l'affichage côté joueur.
Passer ce drapeau à `true` et republier suffirait à le rendre automatique.

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
| RedirectFix | v1.0.1, auto-installé depuis le Mod DB |

La release publiée la plus proche est `v1.22.6-stratum.1-indev.1`, elle-même un
prerelease indev. La dernière vraiment stable est `v1.22.5-stratum.1`, qui
imposerait de jouer en 1.22.5.
