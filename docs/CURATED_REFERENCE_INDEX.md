# Références thématiques validées

Cette couche améliore la recherche de Message Bot sans modifier ni dupliquer le
corpus canonique.

## Principe

Un document de recherche humaine peut fournir :

- des thèmes et formulations utilisateur ;
- des synonymes et expressions proches ;
- des codes de prédications ;
- des plages de référence (E- / §) ;
- un contexte court ;
- des mots d’ancrage servant uniquement à retrouver le passage dans corpus.db.

Le texte affiché à l’utilisateur vient toujours de corpus.db. Les fichiers
`assets/curated/*.reference_index.json` ne doivent jamais embarquer une
citation canonique destinée à être affichée.

## Statuts

Une référence est `resolved` par défaut. La CI exige alors que le code de
prédication existe dans le corpus et que les ancres retrouvent au moins un
passage de l’édition principale.

Si une référence d’un document humain n’existe pas dans le corpus actuel, elle
est conservée avec `corpus_status: unresolved` et une
`unresolved_reason`. Elle n’est jamais utilisée pour influencer les
résultats tant qu’elle n’a pas été réconciliée.

## Ajout d’un nouveau PDF travaillé

1. Identifier les thèmes, sous-thèmes et formulations naturelles.
2. Extraire les références manuellement validées du document.
3. Créer un fichier JSON séparé dans `assets/curated/`.
4. Ajouter son chemin dans `assets/curated/manifest.json`.
5. Conserver l’empreinte SHA-256 du PDF source dans `source_guides`.
6. Lancer la CI. Une release est refusée si une référence déclarée résolue ne
   correspond pas au corpus canonique.

Cette architecture permet d’ajouter progressivement d’autres études (mariage,
foyer, foi, prière, guérison, doctrine, etc.) sans recoder le moteur de
recherche.


## Compatibilité des Study Packs

Le générateur industriel doit utiliser l’identifiant `corpus_version` du
manifest distribué avec l’application, et non le libellé historique conservé
dans `corpus_meta`. Le hash canonique doit être identique avant toute
génération. Cette règle empêche un Study Pack valide sur le fond mais refusé
au démarrage à cause d’un simple écart de libellé de version.


Le validateur industriel applique la même identité de distribution. Une
génération est donc acceptée seulement si générateur, validateur, manifest du
corpus et installateur Flutter convergent sur le même `corpus_version` et le
même hash canonique.
