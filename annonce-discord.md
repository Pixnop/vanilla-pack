# Serveur Vintage Story ouvert

**Adresse : `82.66.202.240:42420`**
**Version : 1.22.6**

Deux mondes derrière une seule adresse. Vous arrivez en survie, et `/crea` vous
bascule sur un monde plat en créatif pour construire ou tester. `/survie` vous
ramène. Pas besoin de se déconnecter, ni de retenir deux adresses.

## À faire avant de vous connecter

Une seule chose, et elle est obligatoire : installez
[RedirectFix 1.0.1](https://github.com/StratumServer/redirectfix/releases/tag/v1.0.1)
dans votre dossier `Mods`. Sans lui, le jeu plante au moment de passer d'un monde
à l'autre. Le Mod DB ne le propose pas encore en 1.22.6, d'où l'installation
manuelle.

Le reste du modpack s'installe tout seul à la connexion, le jeu vous le proposera.

## Ce qu'il y a dedans

40 mods, orientés survie et construction. Cuisine étendue, rivières et cours
d'eau générés, ruines, rangement, artisanat textile, alchimie, soif. La liste
complète est là : <https://github.com/Pixnop/vanilla-pack/blob/main/MODLIST.md>

Le monde de survie a été généré avec 50% de terres et des océans à grande
échelle, ce qu'exige le mod Rivers pour produire de vraies rivières. Comptez donc
un peu de marche avant de tomber sur une côte.

## Détails techniques, pour ceux que ça intéresse

Le serveur tourne sous Stratum, un runtime serveur optimisé, derrière un proxy
Nimbus qui gère le passage entre les mondes. Trois conteneurs Docker, le tout est
public : <https://github.com/Pixnop/vanilla-pack>

Si vous vous faites éjecter avec un message d'erreur, dites-le moi avec une
capture, c'est plus utile qu'un « ça marche pas ».
