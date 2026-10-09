import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/services/local_manga_page_files.dart';
import 'package:watchtower/utils/reg_exp_matcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores only consecutive, non-empty downloaded page files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'watchtower-local-pages-',
    );
    addTearDown(() => directory.delete(recursive: true));

    await File('${directory.path}/${padIndex(0)}.jpg').writeAsBytes([1]);
    await File('${directory.path}/${padIndex(1)}.jpg').writeAsBytes([2]);
    await File('${directory.path}/${padIndex(2)}.jpg').writeAsBytes([]);
    await File('${directory.path}/${padIndex(3)}.jpg').writeAsBytes([4]);

    final pages = await getDownloadedLocalMangaPages(directory);

    expect(pages, hasLength(2));
    expect(pages.map((page) => page.url).toList(), ['', '']);
  });

  test('returns no pages when a downloaded chapter folder is missing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'watchtower-local-pages-missing-',
    );
    final missing = Directory('${directory.path}/chapter');
    addTearDown(() => directory.delete(recursive: true));

    expect(await getDownloadedLocalMangaPages(missing), isEmpty);
  });
}
