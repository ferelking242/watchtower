# Changelog

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

