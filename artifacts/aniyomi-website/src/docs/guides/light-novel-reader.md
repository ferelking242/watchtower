---
title: Light Novel Reader
titleTemplate: Guides
description: How to read light novels in Watchtower using the built-in text reader.
---

# Light Novel Reader

Watchtower includes a full-featured **light novel (LN) reader** alongside its manga and anime capabilities — all in one app.

## What are Light Novels?

Light novels (LN) are Japanese prose fiction typically illustrated with anime-style artwork. Popular series include *Sword Art Online*, *Re:Zero*, *No Game No Life*, *Overlord*, and many more. Unlike manga, light novels are text-based — Watchtower's dedicated text reader handles them natively.

## Getting Light Novel Sources

Light novel content is provided through **extensions**, just like manga and anime.

### Adding a Light Novel Extension Repository

1. Open Watchtower and navigate to <nav to="browse">.
2. Tap **Extension repos** (or **LN extension repos**).
3. Add a repository URL ending in `index.min.json` that provides light novel sources.
4. Go to the **Extensions** tab and refresh.
5. Install the LN extension(s) you want.

::: tip Popular LN Sources
Look for extensions that provide content from sites like **NovelUpdates**, **Royal Road**, **WuxiaWorld**, **ScribbleHub**, and other light novel aggregators.
:::

::: danger Caution
Watchtower does not endorse or provide any third-party repositories. Third-party extensions have full access to the app — only install from sources you trust.
:::

### Local Light Novels

You can read locally stored `.epub` or `.txt` files using Watchtower's local source feature:

1. Place your LN files in the appropriate folder on your device.
2. In Watchtower, go to <nav to="browse"> → **Local source**.
3. Your local light novels will appear and can be added to your library.

## Reading Light Novels

### Text Reader Interface

The LN reader displays text in a scrollable, comfortable format:

- **Scroll mode** — continuous vertical scroll (like a web page)
- **Page mode** — tap or swipe to move between chapters
- **Tap zones** — tap left/right edges to navigate, center to show/hide the UI bar

### Font & Typography Settings

Access reading preferences by tapping the **Aa** icon or the settings gear while reading:

| Setting | Description |
|---|---|
| **Font family** | Choose from bundled fonts or use a custom font installed on your device |
| **Font size** | Adjust text size (default: 16sp) |
| **Line height** | Control spacing between lines for readability |
| **Text alignment** | Left, justify, or right alignment |
| **Margins** | Set horizontal and vertical padding around the text |
| **Paragraph spacing** | Extra space between paragraphs |

### Color & Theme

- **Dark mode / Light mode** — follows your system setting or can be forced
- **Custom background color** — pick any background color
- **Custom text color** — set your preferred reading color
- **Sepia mode** — warm brownish tones, easier on the eyes

### Reading Direction

Light novels are read **top-to-bottom** (like standard prose). Unlike manga, there is no RTL or webtoon mode for LN content.

## Library Management

Light novels are stored in your **Library** alongside manga series:

- You can **filter** your library by content type (Watch, Manga, LN)
- Use **categories** to organize your LN separately from manga
- **Tracking** works with LN series on supported trackers (AniList, NovelUpdates via tracker integration, etc.)

## Tracking Light Novels

Watchtower supports tracking your LN reading progress with:

- **AniList** — supports light novel entries
- **MyAnimeList** — supports light novel entries under the "Light Novel" media type
- **Kitsu** — supports LN

See the [Tracking guide](/docs/guides/tracking) for setup instructions.

## Downloads & Offline Reading

You can download light novel chapters for offline reading:

1. Open a light novel from your library.
2. Long-press a chapter (or use the **Download** button in the chapter list).
3. Downloaded chapters are stored locally and available without internet.

See [Downloads FAQ](/docs/faq/downloads) for storage and management details.

## Frequently Asked Questions

### Why does my LN extension not appear?

Make sure you have added the extension's repository URL first. Go to <nav to="browse"> → **Extension repos** and verify your repo is listed.

### Can I import EPUB files?

Yes, Watchtower supports importing `.epub` files through the Local source. Place your files in the correct folder and they will be automatically detected.

### Can I use custom fonts?

Yes. Install a `.ttf` or `.otf` font on your Android device, then select it from **Reader settings → Font**.

### Is reading progress synced?

Reading progress is stored locally on your device. You can back up and restore your progress through the [Backup system](/docs/guides/backups). Tracker sync (AniList, MAL) will also update your progress when connected.
