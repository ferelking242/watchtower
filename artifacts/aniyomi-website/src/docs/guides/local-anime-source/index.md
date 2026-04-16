---
title: Local watch source
titleTemplate: Guides
description: For users who would like to download and organize their own media.
---

# Local watch source

If you like to download and organize your media, then you want to know how to manage your own watch content in Watchtower.

::: warning
This page explores some advanced features.
:::

## Creating local series

1. In the location you specified as your storage location (e.g., `/Watchtower/`), there should be a `localanime` folder. Place correctly structured series inside that (e.g. `/Watchtower/localanime/`).

    > If adding series in folders it is recommended to add a file named `.nomedia` to the local folder so images and videos do not show up in the gallery.

1. You should now be able to access the series in <nav to="sources"> under **Local watch source**.

If you add more episodes then you'll have to manually refresh the episode list (by pulling down the list).

Supported episode formats are `.mp4` and `.mkv` video files.

### Folder structure

Watchtower requires a specific folder structure for local series to be correctly processed.
Local watch content will be read from the `localanime` folder.
Each series must have a `Watch` folder.
Videos will then go into the Watch folder.
See below for more information on archive files.
You can refer to the following example:

:::info Example
<div class="tree">
  <ul>
    <img src="/img/folder.svg" alt="Folder" class="tree-icon icon-folder">
    <span class="folder root">[your storage location]/localanime</span>
    <li>
      <img src="/img/folder.svg" alt="Folder" class="tree-icon icon-folder">
      <span class="folder main">[the series title]</span>
      <ul>
        <li>
          <img src="/img/jpeg.svg" alt="File" class="tree-icon icon-jpeg">
          <span class="file jpg">cover<span class="file-extension">.jpg</span></span>
        </li>
        <li>
          <img src="/img/video.svg" alt="Video" class="tree-icon icon-video">
          <span class="file jpg">ep01<span class="file-extension">.mp4</span></span>
        </li>
        <li>
          <img src="/img/video.svg" alt="Video" class="tree-icon icon-video">
          <span class="file jpg">ep02<span class="file-extension">.mkv</span></span>
        </li>
      </ul>
    </li>
    <li>...</li>
  </ul>
</div>
:::

<style scoped>
  @import "../../../.vitepress/theme/styles/tree.styl"
</style>
