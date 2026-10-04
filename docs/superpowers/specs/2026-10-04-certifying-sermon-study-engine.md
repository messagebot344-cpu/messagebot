# Spécification technique — Étudier & obtenir la certification

**Projet :** Le Grenier du Message — V4 IR Expert  
**Date :** 4 octobre 2026  
**Branche :** feature/certifying-study-engine  
**Statut :** spécification avant implémentation  
**Audit associé :** docs/superpowers/audits/2026-10-04-certifying-study-engine-audit.md

---

# 1. Objectif

Construire un moteur générique permettant à toute prédication valide du corpus de suivre le parcours :

**Lire → Étudier → Comprendre → Vérifier dans la Bible → Réviser → Passer l’examen → Être certifié**

Le moteur doit fonctionner pour les 1 211 prédications actuelles et pour toute nouvelle prédication ajoutée ultérieurement, sans créer une interface ou du code spécifique par prédication.

La certification mesure la réussite d’un parcours d’étude interne à l’application. Elle ne constitue ni un diplôme académique, ni une accréditation ecclésiastique.

---

# 2. Principes non négociables

## 2.1 Le corpus est l’autorité

Le texte canonique stocké dans corpus.db reste la source d’autorité.

Le moteur d’étude n’a pas le droit de :

- réécrire une citation ;
- inventer une citation ;
- déplacer une déclaration d’une prédication à une autre ;
- présenter une explication pédagogique comme parole originale de William Marrion Branham ;
- construire une question dont la réponse correcte n’est pas démontrable.

## 2.2 Séparation des trois types de contenu

Toute interface d’étude doit distinguer visuellement et sémantiquement :

1. **Citation exacte de la prédication**
2. **Texte biblique**
3. **Explication pédagogique**

Une explication pédagogique doit être étiquetée comme telle.

## 2.3 Aucune IA générative obligatoire au runtime

Le runtime Flutter reste local et déterministe.

Une IA peut être utilisée comme **outil de proposition pendant la construction des packs**, mais :

- elle ne devient jamais source d’autorité ;
- sa sortie est structurée ;
- chaque affirmation est validée contre le corpus ;
- les propositions ambiguës sont rejetées ou envoyées en revue ;
- le Study Pack final est sauvegardé et versionné.

## 2.4 corpus.db reste immuable

Le hash canonique du corpus est une garantie de release.

Les nouvelles données d’étude sont stockées dans un paquet séparé. Aucun Study Pack ne modifie text_display.

---

# 3. Architecture cible

~~~text
PDF / corpus source
      ↓
corpus.db canonique V4
      ↓
Dérivation de paragraphes canoniques
      ↓
Analyse de structure / références / concepts
      ↓
Propositions de sections et questions
      ↓
Validation documentaire automatique
      ↓
Revue humaine pour les cas exigeants
      ↓
study_packs.db
      ↓
StudyPackRepository
      ↓
UI générique Flutter
      ↓
user.db : progression / examens / certifications
~~~

Bases logiques séparées :

- **corpus.db** : source canonique read-only
- **study_packs.db** : parcours pédagogiques read-only/versionnés
- **bible_pack.db** : texte biblique local vérifié, lorsque disponible
- **user.db** : données propres à l’utilisateur

---

# 4. Modèle canonique de paragraphe d’étude

Le passage SQLite actuel est trop gros pour être considéré comme un paragraphe.

Le pipeline doit dériver des **StudyParagraph** à partir du texte exact d’une édition principale.

## 4.1 Règle de dérivation

Utiliser prioritairement les blocs séparés par les doubles sauts de ligne déjà préservés dans passage.text_display.

Aucune normalisation ne doit modifier le texte source.

Pour chaque bloc :

- conserver passage_id ;
- conserver start_offset et end_offset dans text_display ;
- conserver le texte exact uniquement pour validation de build ;
- calculer un hash SHA-256 du bloc ;
- conserver page source ;
- conserver un éventuel numéro de paragraphe imprimé détecté ;
- conserver un ordinal global dans la prédication.

## 4.2 Identifiant stable

paragraph_key doit être déterministe et dépendre de la source :

~~~text
sermon_id + edition_id + passage_id + start_offset + end_offset + text_sha256
~~~

Une modification du texte canonique produit donc une nouvelle identité au lieu de faire croire qu’il s’agit du même paragraphe.

## 4.3 Règle de fidélité

Le texte des StudyParagraph ne doit pas devenir une copie concurrente du corpus dans le runtime.

Le Study Pack distribué référence passage_id + offsets + hash. L’application reconstruit le texte depuis corpus.db et vérifie si nécessaire le hash.

---

# 5. Bible Pack

## 5.1 Prérequis

Le dépôt actuel ne contient pas de Bible structurée. La couche biblique doit donc être ajoutée explicitement avant la publication des questions nécessitant le texte d’un verset.

## 5.2 Structure minimale

bible_pack.db :

- bible_meta
- bible_translations
- bible_books
- bible_verses
- bible_aliases

bible_verses :

- translation_id
- book_id
- chapter
- verse
- text
- text_sha256

## 5.3 Référence normalisée

Toutes les références sont normalisées vers une clé stable, par exemple :

~~~text
JHN.3.16
ROM.9.18
~~~

La forme affichée reste française.

## 5.4 Licence et provenance

Le manifest du Bible Pack doit conserver :

- traduction ;
- version ;
- origine ;
- licence ;
- hash global ;
- date de construction.

Aucun texte biblique ne doit être ajouté depuis une mémoire de modèle ou une source non vérifiée.

## 5.5 Garde-fou

Si une question exige un texte biblique mais bible_pack.db n’est pas installé ou ne contient pas la référence exacte :

- question non publiée ;
- statut needs_review ou rejected ;
- examen non dépendant de cette question.

---

# 6. SermonStudyPack

Un seul modèle générique est utilisé pour toutes les prédications.

## 6.1 Identité

SermonStudyPack :

- sermon_id
- sermon_code
- pack_version
- pack_schema_version
- corpus_version
- corpus_canonical_sha256
- primary_edition_id
- bible_pack_version nullable
- status
- validation_status
- generated_at
- published_at nullable

## 6.2 Contenu

Le pack contient :

- sections
- learningObjectives
- concepts
- bibleReferences
- questions
- finalExamRules
- sourceEvidence
- validationSummary
- migrationMetadata

## 6.3 Statuts du pack

- draft
- generated
- needs_review
- validated
- published
- superseded
- rejected

Seuls les packs **published** sont proposés à l’utilisateur pour une certification.

---

# 7. Stockage study_packs.db

Base SQLite séparée, read-only dans l’application.

Tables proposées :

## 7.1 Métadonnées

study_pack_meta  
study_packs  
study_pack_migrations

## 7.2 Paragraphes et sections

study_paragraphs  
study_sections  
study_section_paragraphs  
study_learning_objectives  
study_concepts

## 7.3 Bible

study_scripture_references  
study_section_scripture_refs

## 7.4 Questions

study_questions  
study_question_options  
study_question_evidence  
study_question_scripture_refs  
study_question_tags

## 7.5 Examens

study_exam_rules  
study_exam_category_rules

## 7.6 Rapports de validation

study_validation_issues

Chaque table utilisée par sermon_id / pack_version / section_id / question_id doit posséder les index correspondants.

---

# 8. Découpage intelligent en unités pédagogiques

## 8.1 Entrée

Séquence ordonnée des StudyParagraph de l’édition principale.

## 8.2 Signaux de segmentation

Le pipeline peut utiliser de manière déterministe :

- rupture de cohésion lexicale ;
- changement important de termes dominants ;
- densité de références bibliques ;
- marqueurs de transition ;
- changement de page ;
- longueur ;
- paragraphes d’introduction/conclusion détectables ;
- répétitions de concepts ;
- proximité documentaire IR.

Une étape d’IA peut proposer un intitulé ou ajuster une frontière, mais ne peut jamais modifier les paragraphes sources.

## 8.3 Contraintes

Ne jamais forcer un nombre fixe de sections.

Les sections doivent respecter :

- ordre canonique ;
- couverture complète du texte ;
- aucune superposition incohérente ;
- aucune omission silencieuse ;
- taille minimale/maximale configurable.

## 8.4 Types de section

classification pédagogique possible :

- introduction
- contexte
- thème
- argument
- développement_biblique
- enseignement_doctrinal
- illustration
- application
- conclusion
- autre

Cette classification est une métadonnée pédagogique, pas une citation.

## 8.5 Titres de section

Les titres de section peuvent être générés, mais doivent être affichés comme titres pédagogiques et non comme titres originaux de la brochure.

---

# 9. Concepts et objectifs pédagogiques

## 9.1 LearningObjective

- id
- section_id
- label
- evidence_ids
- status

## 9.2 Concept

- id
- normalized_label
- display_label
- section_ids
- evidence_ids
- doctrinal_tag nullable
- status

Un concept n’est accepté que s’il existe des preuves textuelles.

Les tags doctrinaux à forte portée interprétative doivent être soumis à revue humaine avant publication.

---

# 10. SourceEvidence

C’est l’élément central de traçabilité.

Chaque preuve issue d’une prédication contient au minimum :

- evidence_id
- source_kind = sermon
- sermon_id
- edition_id
- passage_id
- paragraph_key
- start_offset
- end_offset
- exact_quote
- quote_sha256
- source_page_start
- source_page_end
- evidence_role

evidence_role :

- prompt_context
- correct_answer_support
- explanation_support
- distractor_refutation
- section_boundary_support
- learning_objective_support

Preuve biblique :

- source_kind = bible
- translation_id
- normalized_reference
- verse_range
- exact_text
- text_sha256

Le validateur doit pouvoir reconstruire chaque exact_quote depuis corpus.db et vérifier égalité caractère par caractère.

---

# 11. Questions

## 11.1 Modèle générique

StudyQuestion :

- question_id
- sermon_id
- pack_version
- section_id nullable
- type
- category
- difficulty
- prompt
- pedagogical_explanation
- correct_answer_payload
- scoring_payload
- validation_status
- certification_eligible
- generator_kind
- created_at
- reviewed_at nullable
- reviewer nullable

## 11.2 Types autorisés

- single_choice
- multiple_choice
- true_false_justified
- quote_to_context
- quote_to_scripture
- reasoning_order
- fill_blank
- best_interpretation
- bad_interpretation
- short_answer
- case_study
- synthesis

## 11.3 Catégories

- comprehension
- context
- reasoning
- bible
- doctrine
- comparison
- case_analysis

## 11.4 Difficulté

Échelle recommandée :

- 1 = élémentaire
- 2 = compréhension simple
- 3 = intermédiaire
- 4 = avancée
- 5 = certification exigeante

La difficulté n’est pas déduite uniquement de la longueur de la question.

---

# 12. Construction des questions

## 12.1 Ordre de priorité

1. générateurs déterministes sûrs ;
2. générateurs structurés basés sur les preuves ;
3. IA de proposition optionnelle ;
4. validation mécanique ;
5. revue humaine pour les classes ambiguës.

## 12.2 Règle de publication

Une question n’est publiée que si :

- la source existe ;
- la preuve exacte existe ;
- la réponse correcte est soutenue ;
- le format est auto-notable de manière fiable ou possède une rubrique validée ;
- les distracteurs ne créent pas une seconde réponse valide ;
- aucune citation n’est inventée.

## 12.3 Questions complexes

Les questions de doctrine, interprétation, comparaison et cas pratique proposées par IA passent par **needs_review** par défaut, sauf si elles proviennent d’un template déterministe dont les conditions de preuve sont suffisamment fortes.

---

# 13. Validation automatique des questions

Pipeline minimal obligatoire.

## V01 — SermonExistenceValidator

Vérifie sermon_id, code, édition principale.

## V02 — ParagraphEvidenceValidator

Vérifie paragraph_key, passage_id et offsets.

## V03 — ExactQuoteValidator

Rejoue substring(start_offset, end_offset) et exige égalité exacte.

## V04 — ScriptureReferenceValidator

Normalise la référence et vérifie :

- qu’elle est effectivement présente dans la prédication si la question affirme qu’elle y est utilisée ;
- qu’elle existe dans Bible Pack si le texte biblique est requis.

## V05 — CorrectAnswerEvidenceValidator

Exige au moins une preuve de correct_answer_support.

## V06 — DistractorValidator

Pour QCM :

- interdit distracteurs absurdes générés automatiquement ;
- exige une provenance ou une raison de rejet ;
- détecte si plusieurs options semblent soutenues par les mêmes preuves ;
- en cas d’incertitude : needs_review.

## V07 — AmbiguityValidator

Pour single_choice : exactement une réponse doit être validée.

## V08 — DuplicateQuestionValidator

Détection :

- prompt normalisé identique ;
- mêmes preuves + même objectif ;
- similarité lexicale au-dessus d’un seuil.

## V09 — LanguageValidator

Vérifie la langue attendue et évite les mélanges inutiles.

## V10 — DifficultyValidator

Contrôle cohérence entre type, quantité de contexte et difficulté annoncée.

## V11 — GeneratedClaimValidator

Toute phrase présentée comme explication pédagogique doit rester séparée des citations exactes.

## V12 — PackCoverageValidator

Vérifie la couverture des sections et catégories.

États finaux :

- validated
- needs_review
- rejected

Seules les questions validated peuvent être certification_eligible.

---

# 14. Explication des réponses

Pour les exercices formatifs, après validation d’une réponse :

**Réponse**  
réponse correcte

**Pourquoi ?**  
explication pédagogique

**Source dans la prédication**  
citation exacte + référence

**Référence biblique**  
si disponible et validée

Bouton :

**Voir dans la prédication**

Ce bouton utilise passage_id + offsets via openStudyPassage et applique un surlignage temporaire.

---

# 15. Progression de lecture

## 15.1 Ce qui ne compte pas

Ouvrir la page ne marque pas la prédication comme lue.

## 15.2 Mesure

La progression est calculée sur les StudyParagraph de l’édition principale.

Chaque paragraphe possède :

- unseen
- seen
- read

Un paragraphe devient read lorsqu’il a été effectivement parcouru dans le viewport pendant un temps actif minimal proportionnel à sa taille, avec seuils configurables.

Recommandation initiale :

~~~text
minimum_seconds = clamp(character_count / 35, 2, 30)
minimum_visible_ratio = 0.60
~~~

Le temps n’est accumulé que lorsque :

- l’application est au premier plan ;
- l’écran d’étude est actif ;
- le paragraphe est suffisamment visible ;
- la session n’est pas considérée idle.

## 15.3 Pourcentage

Utiliser le poids en caractères canoniques :

~~~text
reading_percent =
  somme(chars des paragraphes read)
  /
  somme(chars de tous les paragraphes requis)
~~~

Ainsi, un petit paragraphe et un grand bloc ne valent pas artificiellement la même chose.

## 15.4 Reprise

Stocker :

- dernier section_id
- dernier paragraph_key
- dernier passage_id
- dernier offset
- reading_percent
- last_read_at
- active_study_seconds

La reprise doit ramener exactement au dernier paragraphe.

---

# 16. Progression de section

Une section peut avoir :

- lecture
- références bibliques
- passages importants
- questions de compréhension

Statuts :

- locked
- available
- in_progress
- completed
- needs_review

Règle initiale recommandée de complétion :

- au moins 90 % des caractères de la section lus ;
- fin de section atteinte ;
- checkpoint requis terminé ;
- seuil formatif configurable.

Ces seuils sont stockés dans le pack, pas codés en dur dans l’UI.

---

# 17. Intégration des surlignages et notes

Réutiliser passage_highlights et user_notes.

Dans une étude :

**Mes passages importants**

affiche uniquement les surlignages dont passage_id appartient à la prédication.

Actions :

- ouvrir la citation ;
- retirer le surlignage ;
- ajouter/consulter une note ;
- utiliser comme matériel de révision.

Aucune copie du surlignage n’est nécessaire dans la base d’étude.

---

# 18. Stockage utilisateur — futur schéma

L’implémentation devra migrer user.db après V5.

Tables proposées :

## study_progress

- sermon_id
- pack_version
- status
- reading_percent
- active_study_seconds
- last_section_id
- last_paragraph_key
- last_passage_id
- last_offset
- started_at
- last_studied_at
- completed_at nullable
- updated_at

## study_paragraph_progress

- sermon_id
- pack_version
- paragraph_key
- accumulated_visible_ms
- state
- first_seen_at
- read_at
- updated_at

## study_section_progress

- sermon_id
- pack_version
- section_id
- state
- reading_percent
- checkpoint_score
- completed_at
- updated_at

## study_question_attempts

- question_id
- sermon_id
- pack_version
- context = formative / exam
- attempt_id nullable
- answer_payload
- score
- answered_at

## study_exam_attempts

- attempt_id
- sermon_id
- pack_version
- seed
- started_at
- submitted_at
- overall_score
- category_scores_json
- passed
- attempt_number

## study_exam_items

- attempt_id
- question_id
- display_order
- option_order_json

## study_certifications

- certification_id
- sermon_id
- pack_version
- corpus_version
- score
- category_scores_json
- study_seconds
- attempt_id
- certified_at
- level
- integrity_hash

Toutes les données restent locales.

Pour une future synchronisation, les nouvelles lignes doivent utiliser des identifiants stables et des updated_at, sans introduire de réseau dans cette mission.

---

# 19. Statuts globaux d’une étude

Statuts utilisateur :

- not_started
- in_progress
- reading_completed
- review_required
- exam_available
- exam_failed
- certified

Le statut doit être dérivé des données réelles et non stocké comme simple décoration lorsque cela peut être recalculé.

---

# 20. Déblocage de l’examen final

ExamEligibilityRules est contenu dans Study Pack.

Valeurs initiales recommandées :

- reading_percent >= 95 %
- toutes les sections obligatoires completed
- checkpoints requis terminés
- pack published
- banque de questions suffisante

Si une catégorie n’a pas assez de questions validées, l’examen ne doit pas inventer des remplaçantes.

---

# 21. Examen final

## 21.1 ExamRules

- exam_size
- pass_threshold
- category_weights
- minimum_category_scores nullable
- difficulty_distribution
- max_duration_minutes nullable
- retry_policy
- recent_question_exclusion_count
- explanation_policy

Seuil initial recommandé :

**85 %**

mais il reste une donnée configurable.

## 21.2 Répartition

Valeur par défaut proposée :

- 20 % compréhension
- 20 % contexte
- 20 % Bible
- 20 % raisonnement/doctrine
- 20 % analyse approfondie

Le pack peut adapter la distribution si la prédication ne comporte pas suffisamment de matière dans une catégorie.

Cette adaptation doit être validée et enregistrée.

## 21.3 Sélection

Algorithme :

1. filtrer les questions validated + certification_eligible ;
2. constituer les pools par catégorie/difficulté ;
3. respecter les quotas ;
4. exclure si possible les questions utilisées dans les tentatives récentes ;
5. tirer sans remise ;
6. générer un seed cryptographiquement aléatoire local ;
7. sauvegarder seed + liste + ordre ;
8. mélanger les options indépendamment.

Une tentative doit être reproductible à partir de son enregistrement pour audit.

---

# 22. Banque de questions

Un examen ne doit pas utiliser une banque égale à sa taille.

Critère initial recommandé avant publication :

~~~text
validated certification questions >= exam_size * 2.4
~~~

Exemple :

- examen 25 questions
- objectif de banque : au moins 60 questions validées

Ce ratio peut varier, mais une alerte de validation doit apparaître sous le minimum.

Le pipeline industriel produit un rapport par prédication :

- proposed
- validated
- needs_review
- rejected
- certification_eligible
- couverture par catégorie

---

# 23. Notation des formats libres

Le runtime est offline et sans LLM.

Donc :

- QCM / multi-QCM / vrai-faux / association / ordre / texte à trous structurés : auto-notables ;
- réponses courtes : auto-notables seulement si une rubrique déterministe validée existe ;
- synthèses ouvertes : formatives par défaut, non certifiantes automatiquement ;
- toute future notation par modèle doit être une fonctionnalité séparée et ne doit jamais être requise pour obtenir le fonctionnement offline de base.

---

# 24. Politique après échec

Après un examen échoué, ne pas afficher automatiquement :

- toutes les bonnes réponses ;
- l’ordre exact des options ;
- la totalité de la banque.

Afficher plutôt :

**À revoir**

- sections
- paragraphes/plages
- références bibliques
- thèmes
- catégories faibles

La remediation_map doit être produite à partir des questions ratées et de leurs preuves.

Une nouvelle tentative utilise une autre combinaison lorsque la banque le permet.

---

# 25. Certification

Une certification est créée uniquement lorsque l’examen est passed.

Données :

- certification_id
- titre de prédication
- code/date disponible
- score
- scores par catégorie
- date de réussite
- nombre de tentatives
- durée totale d’étude
- niveau
- pack_version
- corpus_version

Texte obligatoire :

> Certification de réussite du parcours d’étude de l’application Le Grenier du Message.  
> Ceci n’est pas un diplôme académique ou ecclésiastique officiel.

Le certificat peut être affiché dans l’application puis exporté en PDF avec l’infrastructure locale existante.

---

# 26. Date de prédication

Créer un SermonDateResolver déterministe.

Pour un code compatible YY-MMDD :

- valider mois ;
- valider jour ;
- produire date exacte.

Sinon :

- utiliser year structuré ;
- precision = year_only.

Ne jamais transformer 00/00 en date réelle.

---

# 27. UX par prédication

Action ajoutée à la fiche/lecteur :

**Étudier / Certification**

## Écran d’accueil de l’étude

- titre
- code/date
- statut
- progression lecture
- temps actif
- sections terminées / total
- références bibliques étudiées
- checkpoints réussis
- état de l’examen
- certification

CTA :

- Commencer l’étude
- Continuer l’étude
- Réviser
- Passer l’examen
- Voir le certificat

selon l’état.

## Écran section

- titre pédagogique
- progression
- Lecture
- Références bibliques
- Mes passages importants
- Notes
- Questions de compréhension

Pas de scroll horizontal.

Responsive mobile/desktop.

---

# 28. Tableau de bord « Mes études »

Nouvelle destination :

**Mes études**

Résumé :

- commencées
- lecture terminée
- certifiées
- à réviser
- progression générale
- dernières études
- certifications
- thèmes/concepts étudiés

Filtres :

- Non commencées
- En cours
- Terminées
- Certifiées
- À réviser

La liste des 1 211 prédications utilise requêtes indexées + rendu paresseux.

Aucun chargement des questions de tous les packs au démarrage.

---

# 29. Installation des Study Packs

Créer StudyPackInstaller sur le modèle sécurisé de CorpusInstaller.

Manifest séparé :

study_packs/manifest.json

Contient :

- packset_version
- schema_version
- corpus_version requis
- corpus_canonical_sha256 requis
- bible_pack_version nullable
- database_bytes
- database_sha256
- parts

Installation :

1. reconstruire fichier temporaire ;
2. vérifier SHA de chaque morceau ;
3. vérifier SHA global ;
4. quick_check SQLite ;
5. vérifier compatibilité avec corpus ;
6. swap last-known-good.

Une mise à jour de Study Packs ne doit pas imposer la reconstruction de corpus.db.

---

# 30. Versionnement

## 30.1 Pack version

Chaque sermon possède pack_version entier ou semver.

Exemple :

~~~text
sermon_id: 42
pack_version: 3
~~~

## 30.2 Historique utilisateur

La progression conserve le pack_version étudié.

## 30.3 Migration

study_pack_migrations :

- sermon_id
- from_version
- to_version
- old_section_id
- new_section_id nullable
- migration_kind
- reason

Règles :

- section inchangée par plage source : progression migrable ;
- section profondément modifiée : needs_review ;
- question corrigée : anciennes réponses restent historiques ;
- certification existante conserve sa version d’origine ;
- aucune certification n’est silencieusement réécrite.

---

# 31. Pipeline de génération

Créer tools/study_pipeline.

Étapes prévues :

## 31.1 inspect_corpus.py

Inventaire et compatibilité.

## 31.2 derive_paragraphs.py

Dérive les StudyParagraph avec offsets/hashes.

## 31.3 segment_sermons.py

Segmentation structurée.

## 31.4 extract_scripture_refs.py

Détection et normalisation des références.

## 31.5 extract_concepts.py

Extraction déterministe IR/TF-IDF de candidats de concepts.

## 31.6 generate_question_candidates.py

Générateurs templates + adaptateur de propositions IA optionnel.

## 31.7 validate_question_candidates.py

V01 à V12.

## 31.8 build_study_pack_db.py

Ne publie que validated.

## 31.9 validate_study_pack_db.py

Intégrité structurelle et documentaire.

## 31.10 package_study_assets.py

Découpage + manifest.

## 31.11 report_study_packset.py

Rapports qualité.

---

# 32. Interface optionnelle de génération IA

Le pipeline doit permettre un fournisseur externe sans en dépendre.

Contrat entrée :

- paragraphes canoniques limités à la fenêtre nécessaire ;
- objectifs ;
- références bibliques déjà extraites ;
- schéma JSON strict ;
- interdiction d’inventer une source.

Contrat sortie :

- question candidate
- correct_answer
- options
- explanation
- evidence requests
- difficulty/category

Cette sortie n’est jamais directement publiée.

Le validateur retrouve lui-même les preuves dans corpus.db.

Si la preuve demandée n’existe pas : rejected.

---

# 33. Prototype avant industrialisation

Ne pas générer les 1 211 packs immédiatement.

Sélectionner plusieurs prédications selon des critères objectifs :

1. prédication ancienne connue dans le corpus : 47-0412 — La Foi Est l'Assurance ;
2. prédication courte autour du décile bas de longueur ;
3. prédication autour de la médiane ;
4. prédication longue autour du décile haut ;
5. prédication possédant plusieurs éditions ;
6. prédication avec forte densité de références bibliques ;
7. cas à date imprécise/code 0000 si utile.

Le prototype doit couvrir différentes structures sans choisir uniquement des cas faciles.

---

# 34. Critères de réussite du prototype

Pour chaque prédication prototype :

- 100 % des paragraphes canoniques couverts ;
- sections valides sans trou ;
- références bibliques extraites et vérifiées ;
- objectifs sourcés ;
- banque de questions suffisante ou état explicite insuffisant ;
- 0 citation inventée ;
- 0 preuve cassée ;
- reprise de progression ;
- examen reproductible/auditable ;
- certification uniquement après seuil ;
- fonctionnement offline ;
- intégration surlignages/notes.

---

# 35. Génération industrielle

Seulement après validation du prototype.

Rapport global obligatoire :

- sermons_detected
- sermons_processed
- packs_generated
- packs_published
- packs_needs_review
- packs_rejected
- total_sections
- total_questions_proposed
- total_questions_validated
- total_questions_needs_review
- total_questions_rejected
- duplicate_questions
- invalid_quotes
- invalid_scripture_refs
- bible_coverage
- packs_with_exam_ready
- packs_without_sufficient_bank

Aucun chiffre de « couverture » ne doit être affiché sans définition précise.

---

# 36. Tests obligatoires

## 36.1 Pipeline Python

- dérivation de paragraphes ;
- offsets exacts ;
- hash ;
- couverture sans trou ;
- citation exacte ;
- référence biblique ;
- validation de bonne réponse ;
- ambiguïté QCM ;
- doublons ;
- versionnement ;
- migration de pack ;
- rapport.

## 36.2 Flutter unit tests

- calcul reading_percent ;
- reprise ;
- temps actif ;
- état des sections ;
- seuil d’examen ;
- seuil de certification ;
- scores par catégorie ;
- sélection aléatoire ;
- exclusion questions récentes ;
- persistance ;
- migration user.db ;
- conservation des surlignages ;
- certification versionnée.

## 36.3 Widget tests

Tailles minimales :

- mobile 360 px
- mobile 390 px
- tablette 760 px
- desktop 1180 px
- desktop 1440 px

Tester :

- aucun overflow ;
- navigation ;
- étude ;
- examen ;
- résultats ;
- certificat ;
- dashboard.

## 36.4 Intégration

- installer pack local ;
- ouvrir une prédication ;
- progresser ;
- fermer/réouvrir ;
- terminer sections ;
- passer examen ;
- échouer ;
- réviser ;
- repasser ;
- réussir ;
- générer certificat.

## 36.5 Offline

La suite doit échouer si une dépendance réseau devient obligatoire au runtime du moteur d’étude.

---

# 37. Performance

Contraintes d’architecture :

- aucun scan des 1 211 packs au bootstrap ;
- métadonnées de dashboard indexées ;
- contenu d’un pack chargé à la demande ;
- questions chargées par section/examen ;
- listes avec builder paresseux ;
- pas de duplication des 130+ millions de caractères du corpus dans les Study Packs ;
- requêtes SQL indexées ;
- cache limité au pack actif.

Le rapport industriel doit mesurer :

- taille du packset ;
- temps de génération ;
- temps de validation ;
- temps d’ouverture d’un pack ;
- temps de sélection d’un examen.

---

# 38. Sécurité documentaire

Le moteur doit avoir des assertions de release :

- Study Pack lié au bon canonical_text_sha256 ;
- question validée ne peut pas référencer un passage absent ;
- exact_quote doit correspondre aux offsets ;
- question Bible nécessitant un verset doit référencer un Bible Pack valide ;
- corpus canonique ne doit pas être modifié par installation des Study Packs.

---

# 39. Évolution du runtime guard

Le garde-fou V4 devra être étendu lors de l’implémentation pour vérifier :

- aucune dépendance générative runtime dans study engine ;
- aucune dépendance HTTP obligatoire ;
- StudyPackRepository lit localement ;
- BibleProvider lit localement ;
- corpus.db reste read-only ;
- les Study Packs n’embarquent pas de prétendues citations sans evidence.

---

# 40. Ordre d’implémentation

## Phase 1 — Audit

**Terminé dans le document associé.**

## Phase 2 — Fondation

- modèles Study Pack ;
- study_packs.db schema ;
- StudyPackInstaller/Repository ;
- paragraph derivation ;
- user.db migration ;
- interfaces de progression.

## Phase 3 — Prototype pipeline

- segmentation ;
- refs bibliques ;
- validation ;
- packs prototypes.

## Phase 4 — UX prototype

- Étudier / Certification ;
- section ;
- checkpoint ;
- examen ;
- résultat ;
- certificat ;
- Mes études.

## Phase 5 — Bible Pack

Doit être achevé avant de certifier des questions dépendant du texte biblique.

## Phase 6 — QA prototype

Fidélité + offline + UX + performance.

## Phase 7 — Génération industrielle

Seulement après validation formelle du prototype.

## Phase 8 — Contrôle qualité global

Rapports + revue humaine.

## Phase 9 — Intégration finale

Packset publié + dashboard complet.

---

# 41. Critères de non-régression

L’implémentation ne doit pas casser :

- recherche V4 ;
- conversations ;
- lecteur ;
- multi-éditions ;
- favoris ;
- notes ;
- collections ;
- signets ;
- surlignages ;
- PDF ;
- Android ;
- Windows ;
- fonctionnement offline ;
- hash canonique corpus.

---

# 42. Définition de « terminé »

La mission n’est PAS terminée si :

- un bouton Quiz existe ;
- un seul sermon fonctionne ;
- les questions ne sont pas traçables ;
- l’examen dépend d’un LLM en ligne ;
- le texte biblique est inventé ;
- les citations ne sont pas vérifiées ;
- la progression est basée sur l’ouverture d’un écran ;
- la banque n’est pas versionnée ;
- la génération des 1 211 sermons est manuelle.

La mission est terminée lorsque :

1. une architecture unique traite une prédication arbitraire ;
2. les sources sont vérifiables ;
3. un Study Pack publié peut être étudié offline ;
4. la progression survit à la fermeture ;
5. l’examen est exigeant et randomisé ;
6. la certification suit les règles ;
7. la génération industrielle produit des rapports ;
8. l’ajout d’une nouvelle prédication nécessite seulement de relancer le pipeline, pas de coder une nouvelle fonctionnalité.

---

# 43. Décisions verrouillées par cette spécification

1. **Study Packs séparés de corpus.db.**
2. **Aucune génération IA obligatoire dans Flutter.**
3. **Paragraphes d’étude dérivés par offsets canoniques.**
4. **SourceEvidence obligatoire pour toute question.**
5. **Questions ambiguës : needs_review/rejected.**
6. **Bible Pack local requis pour citer le texte biblique.**
7. **Progression basée sur paragraphes réellement parcourus.**
8. **Examen configurable, seuil initial 85 %.**
9. **Banque plus grande que l’examen.**
10. **Certificat versionné et explicitement non officiel.**
11. **Progression/certification dans user.db, contenus pédagogiques dans study_packs.db.**
12. **Prototype avant génération des 1 211 prédications.**
13. **V4 IR Expert reste le moteur de preuve documentaire.**
14. **Aucune modification silencieuse du corpus canonique.**

Cette spécification doit être approuvée avant de commencer la Phase 2 d’implémentation.
