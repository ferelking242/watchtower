# Paramètres › Téléchargements — Référence complète des options

> Document généré automatiquement — reflet de l'état du code à la date de génération.

---

## 1. Téléchargeur par média

Section à 3 onglets (Watch / Manga / Novel). Chaque onglet regroupe les réglages spécifiques au type de contenu.

---

### Onglet Watch (vidéo / anime)

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Moteur de téléchargement** | Carte sélectionnable | HYDRA · ZEUS · ARES · Externe | Moteur utilisé pour télécharger les épisodes. HYDRA = moteur HLS interne. ZEUS = ZeusDL (multi-thread). ARES = Aria2 (protocole externe). Externe = délègue à une application tierce. |
| **Connexions HLS simultanées** | Compteur (1–20) | Défaut : 4 | Nombre de segments HLS téléchargés en parallèle par épisode. Augmenter accélère les streams, mais consomme plus de bande passante. |
| **Épisodes simultanés (file)** | Compteur (1–10) | Défaut : 1 | Nombre d'épisodes traités en même temps dans la file de téléchargement. |
| **Wi-Fi uniquement** | Interrupteur | Activé / Désactivé | Bloque tout téléchargement Watch si aucun réseau Wi-Fi n'est disponible. |
| **Télécharger les nouveaux épisodes** | Interrupteur | Activé / Désactivé | Ajoute automatiquement à la file les nouveaux épisodes détectés lors d'une mise à jour de bibliothèque. |
| **Autoriser les épisodes filler** | Interrupteur | Activé / Désactivé | Inclut les épisodes de type « filler » dans le téléchargement automatique. |
| **Téléchargement anticipé (visionnage)** | Interrupteur | Activé / Désactivé | Pré-télécharge les deux épisodes suivants pendant le visionnage en cours, à condition qu'ils soient déjà disponibles dans la bibliothèque. |
| **Toujours utiliser un téléchargeur externe** | Interrupteur | Activé / Désactivé | Force l'envoi de chaque téléchargement vers l'application externe configurée ci-dessous, même si un moteur interne est sélectionné. |
| **App de téléchargement préférée** | Sélecteur | ADM · IDM · Aucune | Application externe à qui le lien de téléchargement direct est transmis. Si « Aucune », l'app demande à chaque téléchargement. |

---

### Onglet Manga

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Connexions simultanées** | Compteur (1–20) | Défaut : 3 | Nombre d'images téléchargées en parallèle par chapitre. |
| **Chapitres simultanés (file)** | Compteur (1–10) | Défaut : 1 | Nombre de chapitres traités en même temps dans la file. |
| **Archiver en…** | Sélecteur | Dossier · CBZ · CBR · CB7 · ZIP | Format dans lequel les chapitres sont sauvegardés après téléchargement. « Dossier » = images brutes. |
| **Wi-Fi uniquement** | Interrupteur | Activé / Désactivé | Bloque les téléchargements Manga sans connexion Wi-Fi. |
| **Télécharger les nouveaux chapitres** | Interrupteur | Activé / Désactivé | Ajoute automatiquement à la file les nouveaux chapitres détectés. |
| **Supprimer après lecture** | Interrupteur | Activé / Désactivé | Supprime le chapitre dès qu'il est marqué comme lu. |
| **Supprimer même les chapitres marqués** | Interrupteur | Activé / Désactivé | Permet la suppression automatique même si le chapitre a un marque-page. |
| **Téléchargement anticipé (lecture)** | Interrupteur | Activé / Désactivé | Pré-télécharge le chapitre suivant pendant la lecture, si le chapitre actuel et le suivant sont déjà en file. |

---

### Onglet Novel

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Connexions simultanées** | Compteur (1–20) | Défaut : 2 | Nombre de requêtes réseau parallèles par roman. |
| **Chapitres simultanés (file)** | Compteur (1–10) | Défaut : 1 | Nombre de chapitres traités simultanément dans la file. |
| **Wi-Fi uniquement** | Interrupteur | Activé / Désactivé | Bloque les téléchargements Novel sans Wi-Fi. |

---

## 2. Téléchargements (options globales)

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Nombre max. de téléchargements** | Compteur (1–10) | Défaut : 2 | Limite globale du nombre de téléchargements actifs simultanément, tous types confondus. |
| **Limite de vitesse** | Sélecteur prédéfini | Désactivée · 128 · 256 · 512 KB/s · 1 · 2 · 5 · 10 MB/s | Bride la bande passante totale allouée aux téléchargements. 0 = pas de limite. |

---

## 3. Navigation rapide (dock)

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Historique sur le dock** | Interrupteur | Visible / Caché | Affiche ou masque l'onglet Historique dans la barre de navigation principale. |
| **Mises à jour sur le dock** | Interrupteur | Visible / Caché | Affiche ou masque l'onglet Mises à jour dans la barre de navigation principale. |

---

## 4. Suppression des chapitres

| Option | Type | Valeurs | Description |
|--------|------|---------|-------------|
| **Suppression automatique après lecture** | Interrupteur | Activé / Désactivé | Supprime tout chapitre (manga ou roman) après qu'il a été marqué comme lu. Priorité sur le réglage par onglet Manga. |
| **Autoriser la suppression des chapitres marqués** | Interrupteur | Activé / Désactivé | Autorise la suppression automatique même si le chapitre est marqué d'un marque-page (favoris). |

---

## 5. Design des cartes de téléchargement

Chaque carte dans la file de téléchargement peut afficher jusqu'à 5 boutons d'action rapide. Cocher/décocher pour les activer.

| Bouton | Icône | Description |
|--------|-------|-------------|
| **Pause / Reprendre** | ⏸ | Met en pause ou reprend un téléchargement en cours. |
| **Réessayer** | ↺ | Relance un téléchargement qui a échoué. |
| **Annuler** | ✕ | Annule le téléchargement sans supprimer les fichiers partiels. |
| **Supprimer** | 🗑 | Annule et supprime tous les fichiers du chapitre. |
| **Ouvrir dossier** | 📂 | Ouvre le dossier de destination dans le gestionnaire de fichiers. |

---

## 6. Actions de balayage (file de téléchargement)

Définit l'action déclenchée par glissement horizontal sur une carte de téléchargement.

| Réglage | Options disponibles |
|---------|---------------------|
| **Balayer à gauche** | Pause/Reprendre · Annuler · Supprimer · Réessayer · Aucune action |
| **Balayer à droite** | Pause/Reprendre · Annuler · Supprimer · Réessayer · Aucune action |

> **Note :** Le fond révélé à gauche (glissement vers la droite) correspond à l'action « Balayer à gauche » et inversement.

---

## 7. Dossiers locaux

| Option | Type | Description |
|--------|------|-------------|
| **Rescanner les dossiers locaux** | Action | Lance une analyse de tous les dossiers configurés pour importer les fichiers locaux dans la bibliothèque. |
| **Ajouter un dossier local** | Sélecteur de chemin | Ouvre le sélecteur de fichiers pour ajouter un nouveau dossier source. |
| **Structure de dossier** | Dialog d'aide | Affiche la hiérarchie attendue : `LocalFolder / MangaName / ChapterX / Page.jpg`. |
| **Liste des dossiers configurés** | Liste avec suppression | Affiche tous les dossiers ajoutés manuellement. Le dossier par défaut (stockage interne) est en lecture seule. Chaque dossier ajouté peut être supprimé via la corbeille. |

---

## Structure attendue pour les dossiers locaux

```
LocalFolder/
├── MangaName/
│   ├── cover.jpg
│   ├── Chapter1/
│   │   ├── Page1.jpg
│   │   └── Page2.jpeg
│   └── Chapter2/
│       └── ...
├── AnimeName/
│   └── Episode1.mp4
└── NovelName/
    └── Chapter1.html
```

---

## Valeurs par défaut récapitulatives

| Réglage | Défaut |
|---------|--------|
| Moteur Watch | HYDRA (HLS interne) |
| Connexions HLS | 4 |
| Connexions Manga | 3 |
| Connexions Novel | 2 |
| Épisodes/Chapitres simultanés | 1 |
| Wi-Fi uniquement | Désactivé |
| Téléchargement anticipé | Désactivé |
| Auto-téléchargement nouveaux | Désactivé |
| Archive format | Dossier (images brutes) |
| Limite de vitesse | Désactivée (0 KB/s) |
| Téléchargements max globaux | 2 |
| Suppression après lecture | Désactivée |
| Marque-pages supprimables | Désactivé |
| Boutons carte actifs | Pause/Reprendre |
| Balayer à gauche | Pause/Reprendre |
| Balayer à droite | Supprimer |
| Historique sur dock | Visible |
| Mises à jour sur dock | Visible |
