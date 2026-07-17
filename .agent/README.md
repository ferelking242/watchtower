# .agent/ — Zone de travail des agents IA

> **Tu es un agent IA qui vient d'être initialisé sur ce projet.**  
> Lis ce fichier en premier. Ensuite lis dans l'ordre indiqué ci-dessous. Ne code rien avant d'avoir tout lu.

---

## Ordre de lecture obligatoire

```
1. CE FICHIER                   ← tu es ici
2. ARCHITECTURE.md              ← vue d'ensemble A-Z des 3 repos
3. ROADMAP.md                   ← ce qui est fait, en cours, planifié
4. plans/01-multi-ui.md         ← comment les UIs se fusionnent dans watchtower
5. plans/02-sdk.md              ← plan SDK (OpenAPI + dart + js + python)
6. plans/03-reel.md             ← état actuel de watchtower-real (UI Reel)
7. plans/04-server.md           ← architecture du serveur headless
8. transcripts/                 ← lis le fichier le plus récent
```

---

## Setup — première chose à faire

```bash
# 1. Demande le GITHUB_PAT à l'utilisateur (scope: repo + workflow)

# 2. Clone les 3 repos à la racine de ton espace de travail
git clone https://ferelking242:<PAT>@github.com/ferelking242/watchtower.git
git clone https://ferelking242:<PAT>@github.com/ferelking242/watchtower-real.git
git clone https://ferelking242:<PAT>@github.com/ferelking242/watchtower-website.git

# 3. Configure git dans chaque repo
for repo in watchtower watchtower-real watchtower-website; do
  cd $repo
  git config user.email "agent@replit.com"
  git config user.name "Replit Agent"
  cd ..
done
```

---

## Ce que tu NE dois PAS faire

- ❌ Créer un nouveau `RemoteApiClient` dans un repo UI → utilise le SDK Dart (plan 02)
- ❌ Copier des fichiers entre repos via script CI → utilise les git deps pubspec (plan 01)
- ❌ Ajouter `build_runner` / `riverpod_generator` / `isar_community_generator` dans watchtower-real → pas de codegen actif
- ❌ Déplacer `render.yaml` — il doit rester à la racine de watchtower (Render le lit là)
- ❌ Générer un nouveau keystore APK → le keystore permanent est dans les secrets GitHub (`KEYSTORE_BASE64`)
- ❌ Renommer le repo GitHub `watchtower-real` toi-même → c'est une action manuelle de l'utilisateur sur github.com

---

## Règle de mise à jour de ce dossier

**À chaque push significatif**, mets à jour :
- `ROADMAP.md` → marque les tâches finies ✅, ajoute les nouvelles
- `transcripts/YYYY-MM-DD.md` → résumé des décisions de la session

---

## Contacts repos

| Repo | URL | Rôle |
|---|---|---|
| watchtower | github.com/ferelking242/watchtower | App principale + serveur |
| watchtower-real | github.com/ferelking242/watchtower-real | UI Reel (TikTok-style) |
| watchtower-website | github.com/ferelking242/watchtower-website | Docs VitePress |
