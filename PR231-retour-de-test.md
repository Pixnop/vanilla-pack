# Retour de test sur la PR 231 (draft, `fix/world-gen-and-mod-compat` @ 7ff2709)

Build fait depuis la branche dans un conteneur `mcr.microsoft.com/dotnet/sdk:10.0`,
Linux, .NET 10. Chaque test part d'un `dataPath` neuf, monde généré de zéro, un
seul mod présent. Le comptage se fait sur `grep -c 'error was thrown in pass'`.

## La branche ne se construit pas en l'état

`patches/VSEssentials/Systems/WorldGen/Standard/ChunkGen/4.GenBlockLayers/GenBlockLayers.cs.patch`
est malformé et fait échouer tout le bootstrap :

```
1 patch(es) failed to apply:
  patches/VSEssentials/.../GenBlockLayers.cs.patch
Bootstrap FAILED: 1 patch(es) did not apply. The working tree is incomplete.
```

`git apply --check` pointe la ligne 49, qui est l'en-tête du hunk suivant. Le
hunk fautif est celui de la ligne 11, `@@ -14,15 +15,35 @@`. Son corps contient
12 lignes de contexte, 22 ajouts et 3 suppressions. Côté ancien, 12 + 3 = 15,
conforme. Côté nouveau, 12 + 22 = **34**, pas 35. Git attend une ligne de plus et
tombe sur le hunk suivant.

Le corps du hunk est complet, rien ne manque côté code. Passer l'en-tête à
`@@ -14,15 +15,34 @@` suffit, `git apply --check` passe et le bootstrap va au
bout. Ça ressemble à une retouche manuelle du `.patch` sans repasser par
`scripts/extract-patches.sh`.

Second point, pas un bug : `baseline/VintagestoryLib` embarque du code client
(`OggDecoder.cs`, `OggPage.cs`) qui référence `csogg` et `csvorbis`, absents de
l'archive serveur. Sans `CLIENT_LIB_DIR`, le build sort 4 × CS0246. Le Makefile
le prévoit, mais ça n'est écrit nulle part dans le README.

## Watersheds : réglé

| Runtime | Erreurs |
| --- | --- |
| 1.22.6-stratum.1-indev.1 publié | 225 |
| PR 231 (en-tête corrigé) | **0** |

L'avertissement Harmony sur le transpiler de `WatershedsMod` est toujours émis,
mais plus rien ne casse derrière. Le shim `rnd` semé au setup fait bien son
travail face au prefix qui remplace `OnChunkColumnGeneration`.

Vérification que le test n'est pas un faux positif : le lancement affiche
`Stratum: applied patched files (10 file(s))`, donc l'overlay est actif et c'est
bien le `VintagestoryLib` patché qui tourne. Sans embarquement le serveur
retomberait sur le vanilla, qui donne 0 erreur pour de mauvaises raisons.

## BetterRuins : inchangé

La description de la PR annonce fermer la #230. Ce n'est pas le cas ici.

| Runtime | Playstyle | Erreurs |
| --- | --- | --- |
| 1.22.6-stratum.1-indev.1 publié | creativebuilding | 169 |
| PR 231 (en-tête corrigé) | creativebuilding | **169** |

Même compte exact, même pile :

```
at Vintagestory.ServerMods.BlockSchematicStructure.SatisfiesMinSpawnDistance(Int32 minSpawnDistance, BlockPos pos, BlockPos spawnPos)
   in VSEssentials/Systems/WorldGen/Standard/Datastructures/BlockSchematicStructure.cs:line 56
at Vintagestory.ServerMods.GenStructures.DoGenStructures(...)  line 398
```

Le mod est bien chargé (`Mods, sorted by dependency: game, betterruins, creative, survival`)
et le playstyle bien appliqué (`creativebuilding / crplayer`). La PR touche
GenCaves, GenBlockLayers et GenPartial, aucun de ces fichiers n'est sur le chemin
de `GenStructures`, donc le résultat n'a rien de surprenant.

## Ce que je n'ai pas testé

Rien sur le worldgen vanilla propre ni sur la comparaison de grottes à seed égale,
les deux réserves que la description de la PR mentionne déjà. Rien non plus sur
rivers ou terrapretty.
