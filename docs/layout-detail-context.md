# Detail layout component compatibility

The `detail` component-picker context is intentionally empty in the current
Watchtower renderer. `ComponentGalleryScreen` builds picker choices directly
from `LayoutComponentRegistry.forContext`, so no component is advertised until
the app has a Detail adapter that can render it from the Detail page's actual
models.

The existing extension `DetailLayout` is presentation metadata only:

- `hero` contains legacy style values such as `poster` and `backdrop`.
- `episodeList` contains legacy style values such as `compact` and `vertical`.
- `showRecommendations` is a boolean; it does not provide recommendation items.

These values are retained unchanged when parsing existing `layout.json` files.
They are not component IDs, and the current Detail pages do not consume this
layout object.

Components deliberately excluded from the Detail picker:

- `mangaFeaturedCard` and `mangaChapterCard` are wired to Home's
  `ContentItem` adapter, not to the persisted Detail `Manga` model.
- `homeEpisodeCard` and `chapterCard` have extension/Home adapters for
  `MManga`/`MChapter`; the detail screens use persisted `Manga`/`Chapter`
  objects and do not currently route their lists through those adapters.
- The Gallery's detail-media widgets depend on TMDB-specific media, cast,
  season, and video data. Those fields are not part of `DetailLayout` and
  cannot be supplied by the extension Detail model.

Registering any of these before its Detail renderer and adapter are connected
would make the visual selector promise a layout that the runtime cannot render.
The registry test keeps this context empty and confirms that the legacy Detail
style values still parse as-is.
