# UI Layouts — Watchtower Extension Home Screens

Each extension can ship a declarative JSON that tells Watchtower how to render
its source home screen — pill tabs, sections, carousels, ranked lists, etc.

---

## Where to put the file

Store the JSON in this folder under the extension's source id:

```
ui-layouts/<source-id>.json
```

Then reference it in `index.min.json`:

```json
{
  "uiLayout": "ui-layouts/mangadex.json",
  "uiLayoutVersion": "1.0.0"
}
```

`uiLayoutVersion` is compared against the on-device cache — bump it to force a
refresh when you update the layout.

---

## Schema

```jsonc
{
  "schemaVersion": 1,
  "home": {
    "sections": [
      {
        "id": "home",           // REQUIRED — marks this as the Accueil tab
        "component": "carousel",// see Component types below
        "title": "Accueil",
        "icon": "home",         // key from _kIconMap in the app
        "seeAll": false,
        "paginated": false,
        "requiresAuth": false
      }
    ]
  }
}
```

### `id` field

| id | behaviour |
|----|-----------|
| `"home"` | Creates the **Accueil** pill tab and triggers `source.providesHome = true` |
| `"popular"` | Reserved — renders in-line on the home view as a Popular carousel |
| `"latest"` | Reserved — renders in-line on the home view as a Latest Updates list |
| anything else | Custom section — horizontal row on the home view + dedicated tab |

### Component types

| component | rendered as |
|-----------|-------------|
| `carousel` / `spotlight` | Full-width auto-scroll card (cover + title + description + genres) |
| `compactRow` / `compact` | Horizontal cover row (12 items max) |
| `mangaChapterList` | Vertical list with cover + title + chapter + time |
| `ranked` | Numbered list (1–10 rank badges) |
| `grid` / `catalogue` | 3-column cover grid |
| `banner` / `hero` | Full-width image banner |
| `categoryPills` / `category` | Genre pill buttons |
| `newHot` / `new_hot` | "New & Hot" stacked card style |
| `feed` | TikTok-style vertical reel (anime only) |

### `icon` field (optional)

Maps to a Material icon in the pill label:

| key | icon |
|-----|------|
| `home` | `Icons.home_rounded` |
| `fire` | `Icons.local_fire_department_rounded` |
| `fiber_new` | `Icons.fiber_new_rounded` |
| `trending_up` | `Icons.trending_up_rounded` |
| `star` | `Icons.star_rounded` |
| `update` | `Icons.update_rounded` |
| `filter` | `Icons.tune_rounded` |
| `animation` | `Icons.animation_rounded` |
| `category` | `Icons.category_rounded` |
| `new_releases` | `Icons.new_releases_rounded` |

Any key not found in the map is treated as an emoji/text label shown in the pill.

---

## Full example → see `mangadex.json`
