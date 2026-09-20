---
name: Compatibilité Flutter
description: Contrainte de version du SDK à vérifier avant les validations locales.
---

Le projet ne peut pas résoudre ses dépendances avec un SDK Dart inférieur à 3.11.

**Why:** L’environnement de travail peut fournir un Flutter plus ancien que la contrainte déclarée par le projet, ce qui fait échouer `pub get` avant toute analyse utile.

**How to apply:** Vérifier `dart --version` avant `flutter pub get`, puis utiliser un Flutter compatible Dart 3.11+ pour lancer l’analyse, les tests et le build.