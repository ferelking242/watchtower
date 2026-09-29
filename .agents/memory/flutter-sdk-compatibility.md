---
name: Compatibilité Flutter
description: Contrainte de version du SDK à vérifier avant les validations locales.
---

Le projet ne peut pas résoudre ses dépendances avec un SDK Dart inférieur à 3.11. La validation Web fiable passe par le workflow GitHub avec Flutter 3.47.2.

**Why:** L’environnement de travail peut fournir un Flutter plus ancien que la contrainte déclarée par le projet, ce qui fait échouer `pub get` avant toute analyse utile. Le formatage local ne remplace pas l’analyse de compilation Web.

**How to apply:** Vérifier `dart --version` avant `flutter pub get`, puis utiliser un Flutter compatible Dart 3.11+ pour lancer l’analyse, les tests et le build. Pour cette application, surveiller `build_web.yml` après chaque push fonctionnel.