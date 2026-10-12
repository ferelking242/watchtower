---
name: AniList studio browsing
description: Use AniList's studio relationship for studio-filtered catalog pages
---

Studio-filtered AniList browse requests must query `Studio(id: ...) { media(...) }`; do not pass `studioId` to `Page.media`.

**Why:** `Page.media` does not accept a `studioId` argument, so including one causes AniList to reject the whole GraphQL query and leaves studio “Voir tout” pages unavailable.

**How to apply:** Keep the general `Page.media` query for genre, format, country, and sort filters. Route studio filters through `Studio.media`, and apply any filters unsupported by that relationship query to its returned media.
