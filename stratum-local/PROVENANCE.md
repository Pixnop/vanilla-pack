# D'où vient ce binaire

Build de [Stratum](https://github.com/StratumServer/Stratum) faite depuis la
branche `fix/world-gen-and-mod-compat`, commit `7ff2709`, celle de la
[PR 231](https://github.com/StratumServer/Stratum/pull/231).

Elle est ici parce que la release publiée `v1.22.6-stratum.1-indev.1` casse le
mod `watersheds` : 225 erreurs de génération par minute sur un monde neuf, zéro
avec cette build. Le même mod seul sur un serveur 1.22.6 officiel ne produit
aucune erreur, donc la régression vient bien de Stratum.

Stratum est sous licence MIT, `LICENSE` est joint à côté.

## Ce qu'il faut savoir

C'est un draft non mergé, dont la description dit elle-même que le worldgen
vanilla n'a pas été validé. Deux symptômes observés en jeu qui pourraient en
venir : des `IndexOutOfRangeException` dans `ChildDepositGenerator` via
`GenPartial.GenChunkColumn`, un des fichiers que la PR modifie, et beaucoup
d'avertissements « block listener outside of the main thread ».

La PR ne se construit pas telle quelle : son `GenBlockLayers.cs.patch` déclare un
hunk de 35 lignes côté nouveau alors qu'il en contient 34, ce qui fait échouer
tout le bootstrap. Le détail est dans `../PR231-retour-de-test.md`.

## Reconstruire

```bash
./scripts/build-stratum.sh fix/world-gen-and-mod-compat
```

## Quand la supprimer

Dès que le correctif worldgen est publié en release. Il suffira alors de mettre
`STRATUM_MODE=release` dans `.env` et de pointer `STRATUM_URL` sur la nouvelle
version.
