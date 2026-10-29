#!/usr/bin/env python3
"""Appends the Marketplace catalogue strings to every ARB file.

Run once from the repository root. Idempotent: a key already present is left
untouched, so re-running after adding a string to the tables below only adds the
new ones. The file is rewritten textually (not via json) because the ARB files
carry a hand-maintained key order and the French file already contains duplicate
keys that a json round-trip would silently collapse.
"""
import os

TAGS_EN = [
    ("watch", "Watch"), ("read", "Read"), ("manga", "Manga"), ("manhwa", "Manhwa"),
    ("manhua", "Manhua"), ("webtoon", "Webtoon"), ("comics", "Comics"),
    ("novel", "Novel"), ("anime", "Anime"), ("animation", "Animation"),
    ("movies", "Movies"), ("series", "Series"), ("documentary", "Documentaries"),
    ("music", "Music"), ("game", "Games"), ("action", "Action"),
    ("adventure", "Adventure"), ("fantasy", "Fantasy"), ("science-fiction", "Sci-Fi"),
    ("romance", "Romance"), ("mystery", "Mystery"), ("drama", "Drama"),
    ("comedy", "Comedy"), ("horror", "Horror"), ("thriller", "Thriller"),
    ("historical", "Historical"), ("slice-of-life", "Slice of Life"),
    ("mecha", "Mecha"), ("sports", "Sports"), ("multilingual", "Multilingual"),
    ("french", "French"), ("english", "English"), ("spanish", "Spanish"),
    ("german", "German"), ("italian", "Italian"), ("portuguese", "Portuguese"),
    ("japanese", "Japanese"), ("korean", "Korean"), ("chinese", "Chinese"),
    ("arabic", "Arabic"), ("russian", "Russian"), ("turkish", "Turkish"),
    ("thai", "Thai"), ("indonesian", "Indonesian"), ("hindi", "Hindi"),
    ("vietnamese", "Vietnamese"), ("polish", "Polish"), ("dutch", "Dutch"),
    ("featured", "Featured"), ("new", "New"), ("popular", "Popular"),
    ("trending", "Trending"),
]

TAGS_FR = {
    "watch": "À regarder", "read": "À lire", "comics": "BD et comics",
    "novel": "Roman", "documentary": "Documentaires", "music": "Musique",
    "game": "Jeux", "adventure": "Aventure", "science-fiction": "Science-fiction",
    "mystery": "Mystère", "drama": "Drame", "comedy": "Comédie",
    "horror": "Horreur", "historical": "Historique",
    "slice-of-life": "Tranche de vie", "sports": "Sport",
    "multilingual": "Multilingue", "french": "Français", "english": "Anglais",
    "spanish": "Espagnol", "german": "Allemand", "italian": "Italien",
    "portuguese": "Portugais", "japanese": "Japonais", "korean": "Coréen",
    "chinese": "Chinois", "arabic": "Arabe", "russian": "Russe", "turkish": "Turc",
    "thai": "Thaï", "indonesian": "Indonésien", "hindi": "Hindi",
    "vietnamese": "Vietnamien", "polish": "Polonais", "dutch": "Néerlandais",
    "featured": "Mis en avant", "new": "Nouveau", "popular": "Populaire",
    "trending": "Tendance",
}

SHELF = [
    ("catalog_shelf_watch_popular", "Popular to watch", "Populaire à regarder"),
    ("catalog_shelf_read_popular", "Popular to read", "Populaire à lire"),
    ("catalog_shelf_new_watch", "New watch sources", "Nouvelles sources vidéo"),
    ("catalog_shelf_new_read", "New reading sources", "Nouvelles sources de lecture"),
    ("catalog_shelf_new", "Recently added", "Récemment ajoutées"),
    ("catalog_shelf_recommended", "Recommended for you", "Recommandé pour toi"),
    ("catalog_shelf_featured", "Featured", "Mises en avant"),
    ("catalog_shelf_movies", "Movies", "Films"),
    ("catalog_shelf_series", "Series", "Séries"),
    ("catalog_shelf_anime", "Anime", "Anime"),
    ("catalog_shelf_animation", "Animation", "Animation"),
    ("catalog_shelf_documentaries", "Documentaries", "Documentaires"),
    ("catalog_shelf_science_fiction", "Sci-Fi", "Science-fiction"),
    ("catalog_shelf_fantasy", "Fantasy", "Fantasy"),
    ("catalog_shelf_action_adventure", "Action and adventure", "Action et aventure"),
    ("catalog_shelf_romance_mystery", "Romance and mystery", "Romance et mystère"),
    ("catalog_shelf_manga", "Manga", "Manga"),
    ("catalog_shelf_manga_manhwa", "Manga and manhwa", "Manga et manhwa"),
    ("catalog_shelf_manhwa", "Manhwa", "Manhwa"),
    ("catalog_shelf_manhua", "Manhua", "Manhua"),
    ("catalog_shelf_webtoons", "Webtoons", "Webtoons"),
    ("catalog_shelf_comics", "Comics and graphic novels", "BD et comics"),
    ("catalog_shelf_novels", "Novels and light novels", "Romans et light novels"),
    ("catalog_shelf_french", "French sources", "Sources françaises"),
    ("catalog_shelf_english", "English sources", "Sources anglaises"),
    ("catalog_shelf_multilingual", "Multilingual sources", "Sources multilingues"),
    ("catalog_shelf_scifi_fantasy", "Sci-Fi and fantasy", "Science-fiction et fantasy"),
    ("catalog_shelf_music", "Music", "Musique"),
    ("catalog_shelf_games", "Games", "Jeux"),
    ("catalog_shelf_adult_watch", "Midnight World", "Midnight World"),
    ("catalog_shelf_adult_read", "Midnight Library", "Midnight Library"),
    ("catalog_shelf_for_you_watch", "For you · to watch", "Pour toi · à regarder"),
    ("catalog_shelf_for_you_read", "For you · to read", "Pour toi · à lire"),
    ("catalog_tab_for_you", "For you", "Pour vous"),
    ("catalog_tab_watch", "Watch", "Watch"),
    ("catalog_tab_manga", "Manga", "Manga"),
    ("catalog_tab_music", "Music", "Musique"),
    ("catalog_tab_games", "Games", "Jeux"),
    ("catalog_tab_novels", "Novels", "Romans"),
]

UI = [
    ("catalog_shelf_order_curated", "Featured first, then most recently added",
     "Mises en avant d'abord, puis les plus récemment ajoutées"),
    ("catalog_shelf_empty", "No extension matches this selection yet.",
     "Aucune extension ne correspond encore à cette sélection."),
    ("catalog_see_all", "See all", "Voir tout"),
    ("catalog_back", "Back", "Retour"),
    ("catalog_error", "Could not load the catalogue.", "Impossible de charger le catalogue."),
    ("marketplace_all_extensions", "All {type} extensions", "Toutes les extensions {type}"),
    ("marketplace_explore_by_language", "Explore by language", "Explorer par langue"),
    ("marketplace_whole_catalogue", "The whole catalogue", "Tout le catalogue"),
    ("catalog_card_see_more", "See more", "Voir plus"),
    ("catalog_card_see_less", "See less", "Voir moins"),
    ("catalog_card_open_site", "Open the website", "Ouvrir le site"),
    ("catalog_card_open_site_unavailable", "No website for this extension",
     "Aucun site pour cette extension"),
    ("plugins_section_builtin", "Built-in plugins", "Plugins intégrés"),
    ("plugins_section_engines", "Components and engines", "Composants et moteurs"),
    ("plugins_section_empty", "No plugin available.", "Aucun plugin disponible."),
    ("plugins_nfile_title", "NFile — file manager",
     "NFile — gestionnaire de fichiers"),
    ("plugins_nfile_description",
     "Built-in file explorer with players and management tools.",
     "Explorateur de fichiers intégré avec lecteurs et outils de gestion."),
    ("plugins_smart_library_description",
     "Scans and organises the videos and mangas already on the device.",
     "Analyse et organise les vidéos et mangas déjà présents sur l’appareil."),
    ("plugins_ffmpeg_ready", "Verified binary available for HLS files.",
     "Exécutable vérifié disponible pour les fichiers HLS."),
    ("plugins_ffmpeg_optional",
     "Optional: direct concatenation is used automatically.",
     "Optionnel : la concaténation directe reste utilisée automatiquement."),
    ("plugins_mpv_description",
     "Downloads only mpv.conf, input.conf and the scripts.",
     "Télécharge uniquement mpv.conf, input.conf et les scripts."),
    ("plugins_action_open", "Open", "Ouvrir"),
    ("plugins_action_info", "Info", "Info"),
    ("plugins_action_install", "Install", "Installer"),
    ("plugins_action_close", "Close", "Fermer"),
    ("plugins_mpv_config_exception",
     "The MPV configuration folder is unavailable.",
     "Le dossier de configuration MPV est indisponible."),
    ("plugins_ffmpeg_title", "FFmpeg runtime", "Runtime FFmpeg"),
    ("plugins_smart_library_title", "Smart Library", "Smart Library"),
    ("plugins_music_title", "Music plugins", "Plugins Musique"),
    ("plugins_mpv_title", "MPV configuration", "Configuration MPV"),
    ("marketplace_search_results", "Search results", "Résultats de recherche"),
    ("marketplace_empty_search_title", "No extension found", "Aucune extension trouvée"),
    ("marketplace_empty_catalog_title", "No extension available",
     "Aucune extension disponible"),
    ("marketplace_empty_search_hint", "Try another name or refresh the catalogue.",
     "Essaie un autre nom ou actualise le catalogue."),
    ("marketplace_empty_catalog_hint",
     "The catalogue is empty right now. Try again later.",
     "Le catalogue est vide pour le moment. Réessaie plus tard."),
    ("marketplace_empty_semantics", "Empty catalogue", "Catalogue vide"),
    ("marketplace_settings_tooltip", "Marketplace settings",
     "Paramètres du Marketplace"),
    ("marketplace_load_error", "Could not load the marketplace",
     "Impossible de charger le Marketplace"),
    ("marketplace_search_hint", "Search extensions", "Rechercher des extensions"),
    ("marketplace_recent_searches", "Recent searches", "Recherches récentes"),
    ("marketplace_popular_searches", "Popular searches", "Recherches populaires"),
    ("marketplace_browse_by_category", "Browse by category",
     "Parcourir par catégorie"),
    ("marketplace_nsfw_gate_title", "Adult content hidden",
     "Contenu adulte masqué"),
    ("marketplace_nsfw_gate_body",
     "Enable adult content in the preferences to show these extensions.",
     "Active le contenu adulte dans les préférences pour afficher ces extensions."),
    ("marketplace_nsfw_gate_show", "Show adult content",
     "Afficher le contenu adulte"),
    ("marketplace_account_title", "Watchtower account", "Compte Watchtower"),
    ("marketplace_manage_installed", "Manage installed extensions",
     "Gérer les extensions installées"),
    ("marketplace_preferences", "Marketplace preferences",
     "Préférences du Marketplace"),
    ("marketplace_help_feedback", "Help and feedback", "Aide et commentaires"),
    ("marketplace_details_title", "Details", "Détails"),
    ("marketplace_coming_soon", "{label} is coming soon.",
     "{label} sera disponible prochainement."),
    ("marketplace_source_blurb",
     "{language} source to discover {kind} in Watchtower.",
     "Source {language} pour découvrir {kind} dans Watchtower."),
    ("marketplace_kind_anime", "anime and series", "anime et séries"),
    ("marketplace_kind_manga", "mangas and comics",
     "mangas et bandes dessinées"),
    ("marketplace_kind_novel", "novels and light novels",
     "romans et light novels"),
    ("marketplace_kind_music", "music and audio", "musique et audio"),
    ("marketplace_kind_default", "content", "contenus"),
    ("marketplace_lang_french", "French", "français"),
    ("marketplace_lang_english", "English", "anglais"),
    ("marketplace_lang_multilingual", "multilingual", "multilingue"),
    ("marketplace_unknown_size", "Unknown size", "Taille inconnue"),
    ("marketplace_reviews_count", "{count} reviews", "{count} avis"),
    ("marketplace_reviews_unavailable", "No reviews available",
     "Avis non disponibles"),
    ("marketplace_update", "Update", "Mettre à jour"),
    ("marketplace_extension_installed", "Extension installed",
     "Extension installée"),
    ("marketplace_about_extension", "About this extension",
     "À propos de cette extension"),
    ("marketplace_info_access", "Access", "Accès"),
    ("marketplace_info_community", "Community", "Communauté"),
    ("marketplace_info_repo", "Repository and provenance",
     "Dépôt et provenance"),
    ("marketplace_official_repo_note",
     "Updated through the official Watchtower Extensions repository.",
     "Mise à jour via le dépôt officiel Watchtower Extensions."),
    ("marketplace_ntfy_signals", "ntfy signals", "Signaux ntfy"),
    ("marketplace_info_information", "Information", "Informations"),
    ("marketplace_info_size", "Size", "Taille"),
    ("marketplace_info_technology", "Technology", "Technologie"),
    ("marketplace_info_reading", "Reading", "Lecture"),
    ("marketplace_info_catalog", "Catalogue", "Catalogue"),
    ("marketplace_info_content", "Content", "Contenu"),
    ("marketplace_access_required", "Account required", "Compte requis"),
    ("marketplace_aggregator", "Aggregator", "Agrégateur"),
    ("marketplace_comments", "Comments", "Commentaires"),
    ("marketplace_available_version", "available v{version}",
     "disponible v{version}"),
    ("marketplace_source_count",
     "{count, plural, =1{{count} source} other{{count} sources}}",
     "{count, plural, =1{{count} source} other{{count} sources}}"),
    ("marketplace_installed_count",
     "{count, plural, =1{{count} extension installed} other{{count} extensions installed}}",
     "{count, plural, =1{{count} extension installée} other{{count} extensions installées}}"),
    ("plugins_ffmpeg_info",
     "FFmpeg only muxes HLS TS/fMP4 fragments into a readable file. It "
     "downloads neither the player nor MPV.\\n\\nWhen no verified binary is "
     "installed, Watchtower falls back to direct fragment concatenation, so "
     "online playback does not depend on this plugin.",
     "FFmpeg sert uniquement à muxer les fragments HLS TS/fMP4 en fichier "
     "lisible. Il ne télécharge ni le lecteur ni MPV.\\n\\nSi aucun exécutable "
     "vérifié n’est installé, Watchtower utilise automatiquement la "
     "concaténation directe des fragments. La lecture en ligne ne dépend donc "
     "pas de ce plugin."),
]

# Marketplace screen strings that were still hard-coded in French. Kept in a
# separate table from UI so the already-shipped block stays untouched.
MARKETPLACE = [
    ("marketplace_search_extension_hint", "Search an extension…",
     "Rechercher une extension…"),
    ("marketplace_search_apps_hint", "Search apps and games…",
     "Rechercher des applis et des jeux…"),
    ("marketplace_filter_extensions", "Filter extensions",
     "Filtrer les extensions"),
    ("marketplace_search_language_hint", "Search a language…",
     "Rechercher une langue…"),
    ("marketplace_browse_extensions", "Browse extensions",
     "Parcourir les extensions"),
    ("marketplace_clear_all_filters", "Clear all", "Effacer tout"),
    ("marketplace_installed_only", "Installed only", "Installées uniquement"),
    ("marketplace_installed_only_sub", "Hide extensions that are not installed",
     "Masquer les extensions non installées"),
    ("marketplace_updates_available", "Updates available",
     "Mises à jour disponibles"),
    ("marketplace_updates_available_sub", "Extensions with a new version",
     "Extensions avec une nouvelle version"),
    ("marketplace_all_option", "(all)", "(toutes)"),
    ("marketplace_nothing_to_install", "Nothing to install", "Rien à installer"),
    ("marketplace_check_updates_subtitle", "When the app starts",
     "Au démarrage de l’app"),
    ("marketplace_auto_update_subtitle", "Without confirmation",
     "Sans confirmation"),
    ("marketplace_adult_content_title", "18+ content", "Contenu 18+"),
    ("marketplace_adult_content_subtitle", "Show NSFW extensions",
     "Afficher les extensions NSFW"),
    ("marketplace_manage_repositories", "Manage repositories",
     "Gérer les dépôts"),
    ("marketplace_reload_catalogue", "Reload the catalogue",
     "Recharger le catalogue"),
    ("marketplace_bulk_install", "Bulk install", "Installer en masse"),
    ("marketplace_ntfy_error_subtitle", "Push an alert on error",
     "Pousser une alerte en cas d’erreur"),
    ("plugins_third_party_confirm_title", "Install this plugin?",
     "Installer ce plugin ?"),
    ("plugins_third_party_confirm_body",
     "Third-party plugin from {owner}.\n\nIt will access the APIs declared in "
     "its manifest.\n\nLong-press the card to uninstall.",
     "Plugin tiers de {owner}.\n\nIl accèdera aux APIs déclarées dans son "
     "manifest.\n\nAppui long sur la carte pour désinstaller."),
    ("plugins_auth_required_body",
     "This plugin requires authentication.\nOpen Music Hub → Settings → "
     "Sources, select this plugin as the default source, then tap “Sign in”.",
     "Ce plugin nécessite une authentification.\nOuvrez le Hub Musique → "
     "Paramètres → Sources, sélectionnez ce plugin comme source par défaut, "
     "puis appuyez sur « Se connecter »."),
    ("marketplace_error_load_failed",
     "{count, plural, =1{Failed to load {count} repository} other{Failed to load {count} repositories}}",
     "{count, plural, =1{Échec du chargement de {count} dépôt} other{Échec du chargement de {count} dépôts}}"),
    ("marketplace_error_http", "HTTP {status} for {url}",
     "HTTP {status} pour {url}"),
    ("marketplace_error_empty_response", "Empty response for {url}",
     "Réponse vide pour {url}"),
    ("marketplace_error_plugin_not_registered",
     "Plugin {name} was not registered after the download.",
     "Le plugin {name} n’a pas été enregistré après le téléchargement."),
    ("marketplace_error_generic", "Error: {error}", "Erreur : {error}"),
    ("marketplace_error_uninstall", "Uninstall error: {error}",
     "Erreur désinstallation : {error}"),
    ("marketplace_error_not_installed",
     "Extension {name} could not be installed. No active source was recorded.",
     "L’extension {name} n’a pas pu être installée. Aucune source active n’a été enregistrée."),
    ("marketplace_error_layout_not_saved",
     "The UI layout of {name} was not saved.",
     "Le layout UI de {name} n’a pas été enregistré."),
    ("marketplace_error_layout_unreadable",
     "The UI layout of {name} is unreadable.",
     "Le layout UI de {name} est illisible."),
    ("marketplace_error_categories_not_saved",
     "The categories of {name} were not saved.",
     "Les catégories de {name} n’ont pas été enregistrées."),
    ("marketplace_error_content_types_not_saved",
     "The content types of {name} were not saved.",
     "Les types de contenu de {name} n’ont pas été enregistrés."),
    ("marketplace_error_audio_plugin_missing",
     "Audio plugin not found in local storage.",
     "Plugin audio introuvable dans le stockage local."),
    ("marketplace_error_extension_missing",
     "Extension not found in local storage.",
     "Extension introuvable dans le stockage local."),
    ("marketplace_uninstall_title", "Uninstall {name}", "Désinstaller {name}"),
    ("marketplace_uninstall_body",
     "The extension will be uninstalled. It can be reinstalled at any time.",
     "L’extension sera désinstallée. Réinstallable à tout moment."),
    ("marketplace_uninstalled_toast", "{name} uninstalled",
     "{name} désinstallée"),
    ("marketplace_bulk_install_count",
     "{count, plural, =1{Install {count} extension} other{Install {count} extensions}}",
     "{count, plural, =1{Installer {count} extension} other{Installer {count} extensions}}"),
    ("marketplace_bulk_install_confirm",
     "{count, plural, =1{{count} extension to install} other{{count} extensions to install}}",
     "{count, plural, =1{{count} extension à installer} other{{count} extensions à installer}}"),
    ("marketplace_settings_section_behavior", "Behavior", "Comportement"),
    ("marketplace_settings_section_repositories", "Repositories", "Dépôts"),
    ("marketplace_settings_section_cache", "Cache", "Cache"),
    ("marketplace_settings_section_actions", "Actions", "Actions"),
    ("marketplace_force_reload", "Force reload (bypass cache)",
     "Forcer rechargement (bypass cache)"),
    ("marketplace_installed_toast", "{name} installed", "{name} installée"),
    ("marketplace_repository", "Repository", "Dépôt"),
    ("marketplace_default_metadata_provider", "Default metadata provider",
     "Provider par défaut (métadonnées)"),
    ("marketplace_currently_default", "Currently the default",
     "Actuellement par défaut"),
    ("marketplace_set_default_provider", "Set as default provider",
     "Définir comme provider par défaut"),
    ("marketplace_default_audio_source", "Default audio source",
     "Source audio par défaut"),
    ("marketplace_set_default_audio_source", "Set as default audio source",
     "Définir comme source audio par défaut"),
    ("marketplace_update_available_short", "Update available", "Màj dispo"),
    ("marketplace_with_updates_short", "With updates", "Avec màj"),
    ("marketplace_section_show", "SHOW", "AFFICHER"),
    ("marketplace_section_active_filters", "ACTIVE FILTERS", "FILTRES ACTIFS"),
    ("marketplace_advanced_filters", "Advanced filters", "Filtres avancés"),
    ("marketplace_sort_installed", "Installed", "Installées"),
    ("marketplace_selected_count", "{count} selected",
     "{count} sélectionnées"),
    ("marketplace_progress", "{done} / {total} processed",
     "{done} / {total} traitées"),
    ("marketplace_kind_subtitles", "subtitles and caption tracks",
     "sous-titres et pistes de sous-titres"),
    ("marketplace_type_subtitles", "Subtitles", "Sous-titres"),
    ("marketplace_size_kb", "{value} KB", "{value} Ko"),
    ("marketplace_size_mb", "{value} MB", "{value} Mo"),
    ("marketplace_failed_count", "{count} failed", "{count} échec(s)"),
]

PLURAL_KEY = "catalog_shelf_count"
PLURAL_VALUE = "{count, plural, =1{{count} extension} other{{count} extensions}}"


def quote(value):
    """JSON string literal for an ARB value.

    Newlines become the two-character `\n` escape the ARB files already use, so
    gen-l10n turns them into a real newline in the generated Dart instead of
    rejecting the file for a raw control character.
    """
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped.replace("\n", "\\n") + '"'


def append_entries(path, entries):
    """Inserts `key: value` entries just before the closing brace.

    The original bytes above the closing brace are reused verbatim, so the diff
    stays a pure addition even though the file keeps its hand-maintained order.
    """
    text = open(path, encoding="utf-8").read()
    cut = text.rfind("\n}")
    assert cut != -1, path
    head, tail = text[:cut + 1], text[cut + 1:]
    if not head.rstrip().endswith(","):
        head = head.rstrip("\n") + ",\n"
    body = "".join(f'  "{key}": {quote(value)},\n' for key, value in entries)
    return head + body[:-2] + "\n" + tail


def has_key(text, key):
    return f'\n  "{key}":' in "\n" + text


en_entries = [(f"catalog_tag_{tag.replace('-', '_')}", label) for tag, label in TAGS_EN]
fr_entries = [(f"catalog_tag_{tag.replace('-', '_')}", TAGS_FR.get(tag, label))
              for tag, label in TAGS_EN]
en_entries += [(key, en) for key, en, _ in SHELF]
fr_entries += [(key, fr) for key, _, fr in SHELF]
en_entries += [(key, en) for key, en, _ in UI]
fr_entries += [(key, fr) for key, _, fr in UI]
en_entries += [(key, en) for key, en, _ in MARKETPLACE]
fr_entries += [(key, fr) for key, _, fr in MARKETPLACE]
en_entries.append((PLURAL_KEY, PLURAL_VALUE))
fr_entries.append((PLURAL_KEY, PLURAL_VALUE))

authored = {"app_en.arb": en_entries, "app_fr.arb": fr_entries}

# Every other locale mirrors the English wording: a key that exists everywhere
# keeps the generated class uniform, and untranslated_messages.txt stays an
# honest report of what still needs a translator.
mirror = en_entries

for name in sorted(os.listdir("lib/l10n")):
    if not name.endswith(".arb"):
        continue
    path = f"lib/l10n/{name}"
    text = open(path, encoding="utf-8").read()
    wanted = authored.get(name, mirror)
    missing = [(key, value) for key, value in wanted if not has_key(text, key)]
    if not missing:
        print(f"{name}: up to date")
        continue
    # Read fully before writing: opening for write truncates, and the reader
    # above has already completed, so the write is safe here.
    updated = append_entries(path, missing)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(updated)
    print(f"{name}: +{len(missing)} keys")
