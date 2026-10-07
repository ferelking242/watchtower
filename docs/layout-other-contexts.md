# Extension Search, Browse, and Player layout contexts

## Search

Extension search returns `MManga` results and already adapts them to
`ContentItem` for its default `PosterCard`. The existing
`MangaHomeCardAdapter` can render the same live results, so the registry
exposes `mangaFeaturedCard` and `mangaChapterCard` in the Search context.
The extension detail screen opens the existing component gallery to select a
card; the selection is saved at `browse.search.results.cardComponent` and the
search result grid uses that adapter.

This is additive: existing `browse.search.results.component`, `columns`, and
`filters` values are left unchanged and are not repurposed as card IDs. Layouts
without `cardComponent` continue to render the default `PosterCard`.
Unsupported IDs are ignored by the runtime and rejected when saving through
`LayoutRegistry`.

## Browse and Player

The current browse layout values (`popular`, `latest`, and their presentation
fields) and the player mode are parsed and preserved, but their current screens
do not consume these values through the component registry. Search cards are
therefore not exposed in Browse, and no Player components are selectable. This
keeps the picker aligned with actual renderer paths rather than treating
similar data or legacy presentation names as proof of compatibility.
