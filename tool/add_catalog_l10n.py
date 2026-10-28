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
]

PLURAL_KEY = "catalog_shelf_count"
PLURAL_VALUE = "{count, plural, =1{{count} extension} other{{count} extensions}}"


def quote(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


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
