import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart'
    as io;

import 'package:path/path.dart' as p;
import 'package:watchtower/models/page.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';

/// Rebuilds page placeholders for a completed folder download after its URL
/// cache has been lost. Empty URLs are safe because these pages are read from
/// their corresponding local files.
Future<List<PageUrl>> getDownloadedLocalMangaPages(
  io.Directory? chapterDirectory,
) async {
  if (chapterDirectory == null || !await chapterDirectory.exists()) {
    return [];
  }

  final pages = <PageUrl>[];
  for (var index = 0; ; index++) {
    final pageFile = io.File(
      p.join(chapterDirectory.path, '${padIndex(index)}.jpg'),
    );
    if (!await pageFile.exists() || await pageFile.length() == 0) break;
    pages.add(PageUrl(''));
  }
  return pages;
}
