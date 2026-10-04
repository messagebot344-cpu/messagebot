# Le Grenier du Message — refonte UI fidèle à la maquette de référence

**Date :** 4 octobre 2026  
**Statut :** validée le 4 octobre 2026 — autorisée pour planification et exécution  
**Dépôt :** `messagebot344-cpu/messagebot`  
**Plateformes :** Android 15 ARM64 + Windows x64  
**Base fonctionnelle :** Message Bot V4 / IR déterministe hors ligne

## 1. Autorité de cette spécification

Cette spécification formalise la maquette visuelle approuvée dans la conversation du 4 octobre 2026.

La **source visuelle prioritaire** est l'image fournie et approuvée le 4 octobre 2026, représentant simultanément la vue desktop, les vues mobiles, les résultats développés, les filtres conversationnels et l'aperçu PDF.

Empreinte SHA-256 de cette référence approuvée :

`ee903b9298301ca13f2bdf4f6200740a77d74fdbc7c7c1757968ef5be6d56a17`

Le fichier historique `docs/design/Message_Bot_V4_DESIGN_REFERENCE.png` est antérieur et **n'est plus autoritaire s'il diffère de cette nouvelle référence**.

Cette spécification **supplante les décisions d'interface** de `docs/superpowers/specs/2026-09-22-message-bot-v4-specification.md` lorsqu'elles entrent en conflit avec elle. Elle ne remplace pas les contrats fonctionnels du moteur de recherche, du corpus, de l'offline, de l'impression, de la sécurité locale ou de la fidélité canonique.

## 2. Objectif

L'application doit reprendre aussi fidèlement que possible la hiérarchie visuelle, la composition, les proportions, les comportements responsives et le langage d'interface de la maquette approuvée.

Le résultat attendu n'est pas une simple recoloration. Il s'agit d'une **refonte structurée du shell et des composants d'interface** autour de la maquette, tout en conservant les fonctions V4 existantes.

Critères de réussite :

1. un utilisateur qui compare l'application et la maquette reconnaît immédiatement la même structure ;
2. la version desktop reproduit le bandeau supérieur, la barre latérale, la conversation centrale et le panneau de détails ;
3. la version mobile reproduit l'accueil, la conversation, les cartes et le résultat développé ;
4. les informations fonctionnelles restent exactes et issues du corpus canonique ;
5. aucun scroll horizontal n'est nécessaire sur mobile ;
6. Android et Windows utilisent le même design system ;
7. la refonte ne réintroduit ni réseau, ni IA générative, ni reformulation de citations.

## 3. Identité publique

L'identité visible principale devient :

**Le Grenier du Message**

Sous-titre produit :

**V4 – IR Expert**

Signature :

**Toute Sa Parole. Toujours avec vous. Hors ligne.**

Indicateurs permanents de confiance :

- **100% hors ligne**
- **Aucune IA générative**
- **Texte canonique uniquement**

Les identifiants techniques internes, le nom du package Flutter `le_grenier_du_message` et les structures de stockage peuvent rester inchangés afin d'éviter les migrations sans bénéfice.

Les anciennes chaînes visibles « Message Bot » doivent être remplacées dans le shell, l'accueil, les conversations, les écrans de résultats, les impressions et la page À propos, sauf si elles sont nécessaires pour une compatibilité technique invisible.

## 4. Principes de design

### 4.1 Hiérarchie

L'interface doit donner la priorité dans cet ordre :

1. identité du produit ;
2. requête de l'utilisateur ;
3. nombre de résultats et filtres ;
4. citation exacte ;
5. référence canonique ;
6. contexte plus large ;
7. actions secondaires.

### 4.2 Langage visuel

Palette de référence :

- bleu nuit navigation : `#0B1F3A` ;
- bleu action : `#147DDE` à `#2563EB` selon état ;
- fond principal clair : `#F6F8FC` ;
- surface carte : blanc ;
- bordures : gris bleuté clair ;
- surlignage citation/termes : jaune doux non agressif ;
- statut hors ligne : vert ;
- texte principal : gris très foncé / noir doux.

La navigation utilise des surfaces sombres. Le contenu documentaire utilise des surfaces claires et aérées.

Rayons :

- cartes : environ 12–16 px ;
- champs / chips : environ 12–18 px ;
- boutons principaux : environ 10–14 px.

Les ombres restent légères. Les bordures et la hiérarchie d'espacement sont prioritaires sur les ombres.

### 4.3 Typographie

Le titre « Le Grenier du Message » dans le bandeau desktop peut utiliser une famille serif système pour retrouver l'aspect éditorial de la maquette. Le reste de l'application utilise une sans-serif système lisible.

Aucune police web ou dépendance réseau n'est autorisée.

## 5. Shell desktop

### 5.1 Structure générale

Pour les grands écrans, la page se compose de quatre zones :

1. **bandeau supérieur pleine largeur** ;
2. **barre latérale fixe à gauche** ;
3. **zone centrale principale** ;
4. **panneau de détails à droite** lorsqu'un résultat est sélectionné.

Le shell doit occuper toute la fenêtre et éviter les marges externes inutiles.

### 5.2 Bandeau supérieur

Le bandeau reprend la composition de la maquette :

- ambiance sombre bleu nuit ;
- zone éditoriale à gauche avec livre / texture de livre ;
- texte court de marque à gauche ;
- au centre : « Le Grenier du Message » ;
- sous le titre : « Toute Sa Parole. Toujours avec vous. Hors ligne. » ;
- à droite : badge vert « 100% hors ligne » ;
- à côté : « Aucune IA générative » et « Texte canonique uniquement ».

Si l'image de fond exacte ne peut pas être utilisée sans créer une nouvelle dépendance, une composition locale sombre avec illustration déjà packagée est acceptable, mais la hiérarchie doit rester identique.

Hauteur cible desktop : environ 90–115 px selon la fenêtre.

### 5.3 Barre latérale gauche

Largeur cible : environ 250–285 px.

En tête :

- pictogramme livre ;
- « Le Grenier du Message » ;
- « V4 – IR Expert ».

Bouton principal pleine largeur :

**+ Nouvelle conversation**

Navigation dans cet ordre :

1. Accueil
2. Bibliothèque
3. Conversations
4. Collections
5. Notes
6. Concordance
7. Chronologie
8. Comparer
9. Références bibliques
10. Réglages

La destination active utilise un fond bleu légèrement plus clair et un contraste fort.

Sous la navigation : section **Conversations récentes** avec historique local.

Les conversations affichent un titre court, avec état sélectionné et menu contextuel si nécessaire.

## 6. Vue conversation desktop

### 6.1 En-tête de conversation

La zone centrale commence par une barre compacte contenant :

- titre local de la conversation ;
- métadonnées secondaires discrètes ;
- actions locales à droite si elles existent réellement.

### 6.2 Message utilisateur

Le message utilisateur est aligné à droite dans une bulle bleue compacte, comme dans la maquette.

Il ne doit pas prendre toute la largeur.

### 6.3 Réponse documentaire

Après la requête, un bloc « Le Grenier du Message » affiche :

- **N passages pertinents trouvés** ;
- périmètre de recherche ;
- filtres actifs ;
- bouton **Ajouter un filtre**.

Le bloc n'est jamais formulé comme une réponse générative.

### 6.4 Filtres

Les filtres actifs sont des chips lisibles :

- Sujet ;
- Période ;
- Source ;
- contexte de conversation si applicable.

Chaque filtre modifiable doit pouvoir être retiré sans perdre les autres.

## 7. Cartes de résultats

Chaque résultat est une carte autonome.

### 7.1 En-tête de carte

Contenu :

- rang numéroté dans un carré/cercle bleu foncé ;
- badge qualitatif : « Très pertinent », « Pertinent », « Correspondance partielle » ;
- à droite, un indicateur qualitatif de score, jamais une fausse probabilité numérique.

### 7.2 Citation

La phrase considérée comme la plus pertinente est affichée avant le contexte.

Les termes qui justifient la correspondance sont **surlignés dans la phrase**, avec un jaune doux semblable à la maquette.

Le surlignage ne modifie jamais le texte canonique stocké ; il est purement visuel.

### 7.3 Référence

Sous la citation :

- code de prédication si disponible ;
- titre ;
- date ;
- page ;
- type de source si nécessaire ;
- édition alternative lorsque pertinente.

### 7.4 Actions

Ordre desktop visé :

- Développer / Voir moins
- Ouvrir
- Comparer
- Passages similaires
- Ajouter à une collection
- Copier
- Imprimer
- Citer

Les actions non disponibles pour un type de source ne doivent pas être simulées.

### 7.5 Développement

« Développer » affiche le contexte canonique plus large dans la carte.

Le résultat développé reprend la hiérarchie de la maquette mobile : citation en haut, contexte dessous, référence et actions en bas.

## 8. Panneau de détails desktop

Sur écran suffisamment large, la sélection d'un résultat ouvre ou met à jour un panneau droit.

Largeur cible : environ 300–350 px.

Contenu :

### Détails du résultat

- référence ;
- date ;
- source ;
- page ;
- paragraphe / ordinal si disponible ;
- niveau de pertinence.

### Contexte plus large

Affiche un contexte canonique plus large autour de la phrase trouvée.

Actions :

- Voir le passage complet
- Ouvrir dans le lecteur

### Imprimer / Exporter

- Ce passage
- Tous les résultats de la recherche
- Toute la conversation
- Enregistrer en PDF

Sur desktop, ce panneau peut rester visible pendant le scroll de la conversation.

## 9. Composer conversationnel

Après le premier message, le composer reste fixé en bas.

Il contient :

- champ « Posez votre question sur le Message… » ;
- bouton d'envoi bleu circulaire ;
- indicateur de chargement pendant la recherche ;
- chips de contexte/filtres sous ou près du champ lorsque l'espace le permet.

Il ne doit pas masquer le dernier résultat.

Aucun contrôle purement décoratif ne doit être cliquable s'il n'a pas de fonction réelle.

## 10. Responsive et breakpoints

### 10.1 Desktop large — environ 1180 px et plus

- bandeau complet ;
- sidebar fixe ;
- conversation centrale ;
- panneau droit disponible.

### 10.2 Desktop compact / tablette paysage — environ 760–1179 px

- sidebar réduite ou drawer ;
- panneau droit devient panneau temporaire / sheet ;
- conversation utilise toute la largeur restante.

### 10.3 Mobile — moins d'environ 760 px

- aucune sidebar fixe ;
- aucun panneau droit fixe ;
- aucune table à scroll horizontal ;
- navigation basse + drawer secondaire ;
- cartes pleine largeur ;
- actions en wrap / menu compact ;
- typographie et espaces adaptés sans supprimer l'information.

Les seuils exacts peuvent être ajustés si les tests de contraintes Flutter montrent un meilleur point de rupture, sans changer le comportement attendu.

## 11. Accueil mobile

L'accueil mobile doit être visuellement proche de la maquette :

- fond sombre / visuel éditorial dans la partie haute ;
- pictogramme livre ;
- « Le Grenier du Message » ;
- « V4 – IR Expert » ;
- signature sur plusieurs lignes ;
- gros bouton bleu **Commencer une recherche**.

Navigation basse :

1. Accueil
2. Bibliothèque
3. Conversations
4. Réglages

Les fonctions avancées restent accessibles via le drawer / menu secondaire.

## 12. Conversation mobile

La conversation mobile reprend les mêmes données que desktop mais sous forme mono-colonne.

- flèche retour / navigation compacte en haut ;
- titre de conversation ;
- message utilisateur bleu ;
- nombre de passages trouvés ;
- cartes compactes ;
- citation prioritaire ;
- référence lisible ;
- boutons Développer et Ouvrir immédiatement accessibles ;
- actions secondaires regroupées si nécessaire ;
- composer fixé en bas.

Le panneau de détails desktop devient une page, un bottom sheet ou un panneau plein écran.

## 13. Surbrillance des citations

Le système conserve les offsets canoniques déjà ajoutés au moteur de navigation.

La nouvelle interface doit :

1. surligner la phrase clé dans la carte ;
2. surligner les termes réellement correspondants dans cette phrase ;
3. ouvrir le lecteur exactement au passage ciblé ;
4. conserver le surlignage de la portion canonique dans le lecteur.

La décoration visuelle doit être séparée du texte canonique.

## 14. Écrans secondaires

Les écrans Bibliothèque, Collections, Notes, Concordance, Chronologie, Comparer, Références bibliques et Réglages doivent être remis dans le même design system :

- même barre de titre ;
- même palette ;
- mêmes rayons ;
- mêmes champs ;
- mêmes cartes ;
- mêmes règles responsive.

Ils ne doivent pas être entièrement redessinés au point de modifier leur logique métier.

## 15. Impression et PDF

L'aperçu PDF doit reprendre la maquette :

- logo / pictogramme livre ;
- titre « Le Grenier du Message » ;
- sous-titre documentaire ;
- date ;
- section « Recherche » ;
- requête ;
- nombre de passages ;
- cartes/résultats dans leur ordre ;
- niveau qualitatif de pertinence ;
- citation ;
- référence canonique ;
- pagination ;
- signature de produit en pied de page.

Le PDF reste généré intégralement hors ligne.

Les coordonnées/auteur déjà imposés par les spécifications existantes restent conservés discrètement lorsque requis.

## 16. Thème sombre

Le thème sombre n'est pas supprimé.

Il traduit la même hiérarchie :

- navigation encore plus sombre ;
- cartes sombres distinctes du fond ;
- bleu action conservé ;
- jaune de surbrillance adapté au contraste ;
- statut hors ligne toujours visible.

Le mode clair reste la référence primaire de fidélité à la maquette fournie.

## 17. Accessibilité et ergonomie

Contraintes obligatoires :

- zones tactiles d'au moins environ 44–48 px ;
- contraste lisible ;
- taille de texte mobile non inférieure aux minima actuels ;
- clavier Windows fonctionnel ;
- focus visible ;
- boutons avec tooltips lorsque l'icône seule serait ambiguë ;
- `Semantics` pour les contrôles importants ;
- pas d'action critique cachée uniquement derrière un hover.

## 18. Performance

La refonte ne doit pas rendre l'application lourde.

Règles :

- listes de résultats virtualisées ;
- pas de rendu simultané inutile de centaines de cartes ;
- panneau de détails alimenté à la demande ;
- aucune nouvelle dépendance réseau ;
- pas de gros moteur d'animation ;
- pas de recalcul documentaire déclenché uniquement par le layout ;
- pas d'image plein écran non compressée répétée dans la mémoire.

## 19. Architecture UI cible

La refonte doit éviter un unique fichier monolithique.

Composants cibles :

- `GrenierResponsiveShell`
- `GrenierTopBanner`
- `GrenierSidebar`
- `GrenierMobileNavigation`
- `ConversationWorkspace`
- `ConversationHeader`
- `DocumentaryResponseHeader`
- `ActiveFilterBar`
- `DocumentResultCard`
- `RelevanceBadge`
- `CanonicalHighlightText`
- `ResultDetailsPanel`
- `GrenierComposer`
- `GrenierMobileHome`
- tokens centralisés dans le thème.

Les noms exacts peuvent être adaptés aux conventions existantes, mais les responsabilités doivent rester séparées.

## 20. État et flux de données

La refonte consomme les objets métier existants.

Flux principal :

`ConversationController → ConversationScreen → result cards / details panel`

La sélection d'une carte est un état d'interface, pas une modification du corpus.

Le panneau droit reçoit l'identifiant du résultat sélectionné.

Les filtres restent gérés par le contrôleur de conversation.

Les offsets de surbrillance restent produits par la recherche et transmis aux lecteurs.

Aucune copie de texte canonique ne devient une nouvelle source d'autorité.

## 21. Compatibilité et migrations

La refonte ne doit pas :

- modifier le format `corpus.db` ;
- modifier les 39 parties du corpus ;
- casser `user.db` ;
- supprimer les conversations existantes ;
- casser les collections, notes ou favoris ;
- modifier la logique Android 15 déjà validée ;
- réintroduire un SDK réseau.

Une migration `user.db` n'est justifiée que si une donnée UI persistante réellement nécessaire apparaît. La préférence est de garder la sélection de panneau et les états purement visuels en mémoire.

## 22. Tests obligatoires

### 22.1 Tests widgets desktop

À une taille représentative desktop, vérifier :

- présence du bandeau ;
- sidebar fixe ;
- bouton Nouvelle conversation ;
- navigation complète ;
- zone centrale ;
- panneau de détails lorsqu'un résultat est sélectionné ;
- absence d'overflow.

### 22.2 Tests widgets mobile

À une taille représentative mobile, vérifier :

- absence de sidebar fixe ;
- navigation basse à quatre destinations ;
- accueil de marque ;
- cartes pleine largeur ;
- composer en bas ;
- aucun overflow horizontal.

### 22.3 Tests conversation

Vérifier :

- requête utilisateur en bulle ;
- compteur de résultats ;
- filtres ;
- badge de pertinence ;
- citation ;
- référence ;
- développement ;
- sélection ;
- panneau de détails desktop ;
- sheet/page détails mobile.

### 22.4 Tests de fidélité documentaire

Vérifier qu'une citation affichée correspond exactement au sous-texte canonique ciblé par ses offsets.

Le surlignage des termes ne doit jamais changer le contenu copié/exporté.

### 22.5 Validation globale

Avant livraison :

- `flutter analyze` : 0 issue ;
- tous les tests : 100 % passants ;
- validation V4 : OK ;
- build Android 15 ARM64 : succès ;
- vérification signature / 16 KB : succès ;
- build Windows x64 : succès ;
- zéro warning dans les logs de CI selon le contrôle déjà adopté.

## 23. Critères d'acceptation visuels

La mission est acceptée seulement si les points suivants sont simultanément vrais :

1. desktop reconnaissable comme la maquette : bandeau + sidebar + conversation + panneau droit ;
2. mobile reconnaissable comme les vues mobiles de la maquette ;
3. identité « Le Grenier du Message » présente partout où le produit est nommé ;
4. cartes proches de la composition de référence ;
5. surlignage jaune visible et précis ;
6. filtres conversationnels visibles ;
7. détails de résultat accessibles sans quitter la conversation sur desktop ;
8. impression/PDF cohérente avec la référence ;
9. aucune fonctionnalité métier existante perdue ;
10. aucune erreur, aucun warning CI, aucun overflow Flutter connu.

## 24. Hors périmètre de cette refonte

Cette mission ne demande pas :

- un nouveau moteur de recherche ;
- une IA générative ;
- une API distante ;
- un compte utilisateur cloud ;
- une synchronisation ;
- un nouveau corpus ;
- une modification doctrinale du texte ;
- un format de base de données V5.

Toute évolution de ce type devra faire l'objet d'une spécification distincte.

## 25. Règle de décision en cas d'ambiguïté

En cas de conflit pendant l'implémentation, l'ordre d'autorité est :

1. la nouvelle image approuvée du 4 octobre 2026 ;
2. cette spécification ;
3. les exigences fonctionnelles V4 existantes ;
4. le code actuel.

Lorsque la fidélité visuelle entre en conflit avec l'accessibilité, l'absence d'overflow ou la fidélité canonique, ces contraintes de sécurité et de lisibilité priment, tout en conservant la composition générale de la maquette.
