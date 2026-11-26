# Changelog

## 2026-11-24 — Music Hub : fin du 401 et réglages de plugins reconstruits

### Music Hub
- Le Hub ne remonte plus `DioException [bad response] … 401` à l'ouverture.
  Les appels ListenBrainz liés au compte (bibliothèque, playlists, top artistes
  et titres) renvoient une page vide au lieu d'une erreur : le Hub affiche son
  contenu public, même sans compte ou avec un jeton révoqué.
- Un jeton rejeté est oublié automatiquement, et les appels publics repartent en
  anonyme, donc la page ne reste plus bloquée sur une erreur d'authentification.
- Le plugin MusicBrainz/ListenBrainz livré passe en `1.1.0` avec un client HTTP
  tolérant au 401 (`ResilientHttpClient`) ; l'ancienne copie installée sous un
  autre nom d'auteur est détectée et remplacée, pour que ce ne soit plus le
  bytecode périmé qui tourne.

### Réglages du Music Hub
- Toutes les pages de réglages reprennent la mise en page de Réglages
  Watchtower (pas de cartes, pas de shadcn), y compris À propos.
- La barre de recherche est présente sur la page des plugins.
- Réglages Watchtower → Music Hub ouvre la page de réglages du Hub : le chevron
  retour ramène à l'accueil du Hub, et plus à la racine du hub.
- La page des plugins n'affiche que les extensions réellement installées depuis
  le Marketplace : la section « Installés » codée en dur est supprimée.
- Chaque ligne tient sur une seule ligne : les capacités sont des icônes avec
  info-bulle (icône de connexion pour les plugins qui exigent un compte, note
  pour le scrobbling), plus de phrase de trois lignes.
- L'éditeur affiché est Watchtower partout ; l'auteur upstream n'apparaît plus
  dans les réglages ni dans la fiche plugin du Marketplace.
- Le libellé « Définir la source de métadonnées par défaut » est raccourci
  (une action par ligne, avec son icône) au lieu d'une phrase coupée.

### Vérifications
- `flutter test` : 1195 tests verts, dont la suite des réglages et celle des
  points d'entrée de plugins.
- Test live du plugin contre les API MusicBrainz et ListenBrainz réelles.

## 2026-11-22 — Mises à jour automatiques via app_updater
- Nouvelle dépendance `app_updater` (fork ferelking242) : sources GitHub Actions
  artifacts + GitHub Releases, téléchargement vérifié par SHA-256.
- `AppUpdateService` : pont entre le paquet et les notifications/installeur de
  Watchtower (`UpdateNotifier`, `UpdateInstaller`), sans dupliquer la logique.
- À propos : nouveau réglage « Mises à jour automatiques ». Une fois activé, la
  build est récupérée en arrière-plan et la notification « Prêt à installer »
  propose le bouton Installer.
- Vérification au lancement (opt-in) et toutes les 6 h, sans bloquer l'UI.
- Build web : stub sans effet, `app_updater` n'est pas compilé pour le web.
- CI : `app-update.json` (version, build, SHA-256, taille) est généré puis
  envoyé avec l'APK, et l'étape « Notify app_updater » publie la build sur le
  serveur de mises à jour dès qu'elle est verte.
- Comparaison : le numéro de build départage deux versions identiques, et les
  releases glissantes (`android-latest`) sont prises en compte.
- À propos : action « Vérifier avec les mises à jour auto » pour tester le
  téléchargement et la notification sans attendre la vérification périodique.

## 2026-06-15 — Python Bionic runtime (Méthode B)
- libpython.so (4KB) + libpython.zip.so (11MB) depuis youtubedl-android → jniLibs
- zeusdl.zip (3MB) → assets, extractible au runtime dans filesDir
- Exécution : nativeLibsDir/libpython.so + filesDir/zeusdl/__main__.py
- Plus de SIGSEGV (exit 139), plus de blocage SELinux execv
- Auto-update zeusdl.zip sans réinstaller l'APK

