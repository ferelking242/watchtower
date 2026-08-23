# 🔧 Instructions — Push des fixes CI sur les repos plugins

Les 4 repos plugins ont besoin des mêmes fixes. Voici exactement quoi faire.

## Étape 1 : Pour chaque repo, créer/modifier ces fichiers

### `.github/workflows/build.yml`
Copier le contenu de `tools/plugins/ci_template.yml` (dans le repo watchtower principal).

### `Makefile`
Remplacer par :
```makefile
.PHONY: compile archive clean

compile:
	mkdir -p build
	hetu compile src/plugin.ht build/plugin.out

archive: compile
	mkdir -p build/archive
	cp plugin.json build/plugin.out build/archive/
	cp assets/logo.png build/archive/ 2>/dev/null || true
	cd build/archive && rm -f ../plugin.smplug && zip -q -r ../plugin.smplug .
	cp build/plugin.smplug .
	@echo "✓ plugin.smplug"

clean:
	rm -rf build plugin.smplug
```

### `.gitignore`
Ajouter :
```
build/
dist/
plugin.smplug
*.smplug
```

## Étape 2 : Deezer — fixer les submodules

Le repo Deezer a besoin de 2 dépendances Hetu :

```bash
cd spotube-plugin-deezer
git submodule add https://github.com/hetu-community/hetu_otp_util.git dependencies/hetu_otp_util
git submodule add -b og-main https://github.com/sonic-liberation/hetu_spotify_gql_client.git dependencies/hetu_spotify_gql_client
```

## Étape 3 : Spotify — fixer le submodule OTP

```bash
cd spotube-plugin-spotify
git submodule update --init --recursive
```

## Étape 4 : Commit & Push

```bash
# Pour chaque repo :
git add .github/workflows/build.yml Makefile .gitignore
git add .gitmodules dependencies/  # si applicable
git commit -m "fix: proper CI build + release workflow + clean Makefile"
git push origin main
```

## Étape 5 : Trigger les builds

```bash
# Lire la version depuis plugin.json
VERSION=$(python3 -c "import json; print(json.load(open('plugin.json'))['version'])")

# Créer le tag (trigger le CI)
git tag v$VERSION
git push origin v$VERSION
```

Ou aller dans GitHub → Actions → "Build & Release Plugin" → Run workflow.

## Résultat attendu

Chaque repo aura :
- ✅ Une GitHub Release avec le `.smplug` attaché
- ✅ Des release notes formatées (nom, version, abilities, instructions)
- ✅ Un artefact build pour chaque push sur main

## ⚡ Script rapide (depuis le repo watchtower principal)

```bash
# Générer les patchs
./tools/plugins/generate_patches.sh

# Appliquer manuellement chaque patch dans son repo
cd /path/to/spotube-plugin-spotify
git apply /path/to/tools/plugins/patches/spotube-plugin-spotify.patch
```
