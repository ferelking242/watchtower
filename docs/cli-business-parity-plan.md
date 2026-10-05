# Audit et plan de complétion du CLI

## Périmètre confirmé

Le CLI doit exposer les actions métier utiles de Watchtower sur Linux et Windows,
sans reproduire les écrans. Il doit réutiliser les services, modèles et moteurs
existants plutôt que créer une seconde implémentation de ces fonctions.

La lecture, l’affichage vidéo/audio et les interactions propres à un écran ne
peuvent pas être reproduits dans un terminal. Le CLI doit toutefois pouvoir
résoudre les flux et pages, afficher leurs métadonnées, manipuler la progression
et la bibliothèque lorsque les services existants le permettent.

## État audité

- `lib/main.dart` détecte `--cli` avant `runApp`, ce qui évite de démarrer
  l’interface Flutter. Le CLI est donc une porte d’entrée vers les fonctions
  métier, pas une application parallèle.
- `lib/cli/watchtower_cli.dart` fournit `help`, `version`, `doctor`,
  `extensions list`, `extensions test` et `source`. Le catalogue attendu est un
  dépôt local avec `index/*.json`; les entrées sans `sourceCodeUrl` et
  `index/plugins.json` sont ignorés.
- Le chargement force `sourceCodeLanguage` à JavaScript. Le CLI ne suit donc pas
  le choix de moteur porté par `Source`, alors que Watchtower prend en charge
  les moteurs JavaScript, Dart et Mihon.
- La commande `source` couvre popular/latest/search/detail/videos/pages, mais
  pas l’ensemble de `ExtensionService` : filtres, préférences, headers, listes
  personnalisées, suggestions, recommandations, commentaires et HTML.
- `extensions test --mode load` charge le moteur et lit préférences/headers.
  `smoke` et `deep` ajoutent quelques appels; `deep` ne vérifie qu’une page et
  une URL média. L’exploration par filtres et les fonctionnalités facultatives
  des extensions ne sont pas couvertes.
- Il n’y a pas de tests CLI dédiés. Les tests existants sont des tests de
  composants/services de l’application et ne protègent ni le parseur CLI, ni
  ses codes de retour, ni ses rapports.
- Le chemin CLI retourne avant l’initialisation normale de Watchtower : Isar,
  Hive, bibliothèque, historique, progression, téléchargement, trackers,
  musique et services de fichiers ne sont pas accessibles comme commandes.
- Le workflow Linux headless actif construit une archive, mais ses smoke tests
  se limitent à `doctor`, `help` et l’inventaire. Il utilise aussi Xvfb.
- Le workflow `build-all-platforms` exécute le test CLI Linux en mode `load`
  uniquement, mais l’état GitHub du workflow est `disabled_manually`. Le
  workflow Windows existant est lui aussi désactivé et ne lance pas le CLI.
- GitHub Actions est activé au niveau du dépôt. Le workflow d’analyse Flutter
  et le workflow Linux dédié sont actifs. Le workspace local n’a pas Flutter
  installé; les builds Dart/Flutter devront être validés sur ces runners.

## Phases et critères de sortie

### Phase 1 — Contrat CLI et tests déterministes

- Définir et valider la syntaxe, les options requises, les valeurs et les codes
  de sortie; ne pas transformer silencieusement une option invalide en valeur
  par défaut.
- Rendre les diagnostics vérifiables au lieu de déclarer des capacités natives
  sans les tester.
- Ajouter des tests isolés du réseau pour le parseur, le catalogue, les erreurs,
  les sorties JSON et les codes de retour.
- Garder les commandes actuelles compatibles, sauf correction explicitement
  documentée.

**Sortie de phase :** tests CLI déterministes et analyse Flutter verts.

### Phase 2 — Parité des extensions et plugins

- Respecter le moteur déclaré de chaque source (JavaScript, Dart, Mihon).
- Couvrir les méthodes de `ExtensionService`, les filtres réels, les listes
  personnalisées et les capacités facultatives.
- Inventorier et valider le manifeste, le schéma UI et les scripts des plugins;
  n’exécuter un plugin que par son runtime existant, avec timeout, capture de
  sortie et limites documentées.
- Produire des rapports par étape, reproductibles et exploitables en CI.

**Sortie de phase :** fixtures locales pour chaque type de moteur/plugin et
rapport avec statut fiable par capacité.

### Phase 3 — Commandes des fonctions métier

Ajouter des commandes qui appellent les services existants pour les domaines
suivants; une commande absente doit être signalée comme telle, pas simulée :

- découverte/recherche et résolution de détails, pages, vidéos et flux;
- bibliothèque, catégories, favoris, historique, progression et synchronisation
  des trackers;
- file de téléchargement, état des tâches et opérations de fichiers compatibles
  avec le système;
- plugins et intégrations de musique/metadata;
- configuration et sauvegarde des données, avec masquage des valeurs secrètes;
- diagnostics et services locaux réellement utilisables sans interface.

Chaque groupe doit documenter les opérations en lecture seule et celles qui
modifient les données. Les opérations destructives exigent une confirmation
explicite ou un indicateur de force.

**Sortie de phase :** matrice commande/service/test couvrant les actions CLI
annoncées, avec tests sur une base temporaire ou des fixtures.

### Phase 4 — Linux, Windows et CI

- Conserver la distribution Linux existante et étendre ses validations au
  comportement réel des commandes et aux extensions.
- Ajouter un workflow Windows actif qui construit le binaire, attache correctement
  la console et exécute les mêmes tests CLI; le CLI ne doit pas ouvrir une fenêtre
  visible.
- Lancer les contrôles rapides sur chaque push de branche; réserver les tests
  réseau plus longs à un workflow explicite ou planifié et toujours publier le
  rapport, même en cas d’échec.
- Tester les archives produites, pas uniquement le build intermédiaire.

**Sortie de phase :** jobs Linux et Windows verts sur le même commit, avec
rapports CI consultables et sans fenêtre/UI nécessaire.

### Phase 5 — Documentation et livraison

- Documenter toutes les commandes, leurs options, exemples Linux/PowerShell,
  limites par OS, emplacements des données et codes de sortie.
- Publier chaque phase validée sur `agent/cli-business-parity`; ne pas pousser
  directement sur `main`.
- Après chaque push, vérifier les workflows qui ont réellement démarré et
  distinguer un workflow désactivé d’un test réussi.

**Sortie finale :** documentation alignée sur le binaire livré, couverture de
commandes/services publiée et CI Linux/Windows vérifiée.

## Décisions de sécurité et compatibilité

- Ne pas inclure de jeton GitHub dans l’URL du remote, les arguments visibles,
  les rapports ou les journaux.
- Ne jamais imprimer les identifiants de trackers ou autres valeurs secrètes
  lors d’un diagnostic ou d’un export.
- Épingler ou enregistrer la révision du catalogue d’extensions utilisée par
  un rapport CI pour que les résultats puissent être reproduits.
- Un test réseau peut échouer parce qu’une source externe est indisponible; le
  rapport doit distinguer indisponibilité réseau, défaut de l’extension et
  capacité non prise en charge.
