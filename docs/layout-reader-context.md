# Reader layout component compatibility

The manga Reader is a distinct layout context from the video `player`. It has
no selectable components in the current registry.

The live page renderer is `MangaChapterPageGallery`, backed by the reader
controller and `UChapDataPreload`. It supports remote pages and local archive
images, zoom/crop gestures, page modes, continuous scrolling, transitions,
navigation, and persisted page progress. The Gallery's `MangaPageCard`,
`MangaPagePreviewCard`, `MangaPageStripCard`, and `MangaDoublePageCard` use
URL-oriented `ContentImage` previews and do not implement that reader pipeline.
Registering them as page renderers would replace reader behavior with a
demonstration card.

The mode, direction, settings, progress, and chapter-navigation cards also
need live Reader provider bindings and a Reader-specific layout/editor path.
The current `UiLayout` has no Reader configuration, and no adapter connects
those cards to the active Reader state. They remain Gallery-only until that
runtime path exists.

`LayoutComponentContext.reader` is therefore intentionally empty. It remains
separate from `player`, which represents video playback; the generic selector
will expose Reader components only after a real Reader renderer is registered.
