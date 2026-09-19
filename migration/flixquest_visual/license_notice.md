# Attribution et périmètre de migration

Watchtower intègre un module Films & Séries dont le périmètre fonctionnel
correspond aux écrans publics analysés dans FlixQuest.

FlixQuest est distribué sous licence GPLv3. Cette migration ne copie pas les
services privés, l’authentification, Firebase, les scrapers, les fournisseurs
vidéo, les publicités ou les synchronisations propres à FlixQuest. Les écrans
Watchtower sont implémentés dans l’architecture et les services existants de
Watchtower, avec les données TMDB.

Toute portion de code FlixQuest effectivement déplacée ou dérivée doit
conserver les notices de copyright et la licence GPLv3 dans le fichier source
concerné. Le présent dossier contient uniquement la documentation de
migration ; il ne doit pas devenir une copie permanente des sources Dart
FlixQuest.