# Passe generale de relecture, avec le contexte du mod

Tu relis des traductions francaises de mods Vintage Story deja faites, et tu ne
corriges QUE ce qui doit l'etre. Une traduction correcte se laisse tranquille.

## Ce que tu lis

- Ton lot : `.todo/_pass/<LOT>.json`, une liste de {dom, cle, en, fr}
- Le contexte des mods : `.todo/_contexte.json`, avec le nom et la description
  reelle de chaque mod, tiree de son modinfo.json
- Le glossaire deja fige : `.todo/_glossaire.json`

## Le point de cette passe

Vintage Story est un jeu de survie a l'ambiance prehistorique et medievale,
artisanale, au vocabulaire concret. Chaque mod a en plus son propre registre :
un mod de mycologie ne parle pas comme un mod de taverne.

Lis la description du mod dans `_contexte.json` AVANT de juger ses chaines, et
demande-toi si le francais retenu sonne juste pour CE mod dans CE jeu. Une
traduction peut etre exacte et sonner faux : trop savante, trop moderne, trop
plate, ou empruntee au registre d'un autre mod.

## Ce que tu corriges

1. Faute de langue : accord, conjugaison, syntaxe, orthographe.
2. Contresens ou faux ami.
3. Calque de l'anglais : tournure qui n'existe pas en francais, ou mot anglais
   laisse dans du texte francais.
4. Registre inadapte au mod ou anachronique dans un jeu medieval.
5. Incoherence interne : le meme terme anglais rendu de deux facons dans ton lot.
6. Formulation qui ne tiendrait pas dans une interface de jeu : trop longue,
   ampoulee, ou peu claire pour un joueur.

## Ce que tu ne touches pas

- Le glossaire figé : ces termes ont ete arbitres, ne les defais pas.
- Les noms propres, et les termes identiques en francais.
- Tout ce qui est deja correct et bien tourne, meme si tu aurais dit autrement.

## Contraintes techniques

- Preserve exactement les marqueurs {0}, {1} et tout le balisage : <br>,
  <strong>, <i>, <font ...>, <a href="...">, </a>. Tu ne modifies que du texte
  visible, jamais une URL, un code couleur ou une valeur d'attribut.
- Ne change jamais une cle.
- Typographie francaise : espace insecable avant : ; ! ?

## Ce que tu produis

`.todo/_pass/<LOT>.corr.json`, uniquement les lignes a corriger :

[ {"dom":"...","cle":"...","avant":"...","apres":"...","motif":"une phrase courte"} ]

JSON UTF-8, indent 2, accents reels. Si une ligne est correcte, elle n'apparait
pas dans ce fichier.

Reponds avec : nombre de lignes relues, nombre corrigees, repartition par motif,
et les cinq corrections que tu juges les plus importantes.
