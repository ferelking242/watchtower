import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/modules/plugin/nfile/services/paste_plan.dart';

/// The paste plan is what the copy loop consumes, and it now crosses an
/// isolate boundary: a field rename or a non-sendable value would only show up
/// as a broken paste on device.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('paste_plan_test');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File writeFile(String relative, int bytes) {
    final file = File(p.join(root.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 0));
    return file;
  }

  test('describes a single file with its size', () {
    final file = writeFile('movie.mkv', 32);

    final plan = buildPastePlan([file.path]);

    expect(plan, hasLength(1));
    expect(plan.single['path'], file.path);
    expect(plan.single['kind'], 'file');
    expect(plan.single['size'], 32);
    expect(plan.single['entries'], isEmpty);
  });

  test('walks a directory recursively and sums the file sizes', () {
    writeFile('show/s01e01.mkv', 10);
    writeFile('show/s01e02.mkv', 20);
    writeFile('show/extras/trailer.mkv', 5);
    Directory(p.join(root.path, 'show', 'empty')).createSync(recursive: true);

    final plan = buildPastePlan([p.join(root.path, 'show')]);

    expect(plan, hasLength(1));
    final item = plan.single;
    expect(item['kind'], 'dir');
    expect(item['size'], 35);

    final entries = (item['entries'] as List).cast<Map<String, dynamic>>();
    final files = entries.where((e) => e['isDir'] == false).toList();
    final dirs = entries.where((e) => e['isDir'] == true).toList();

    expect(files.map((e) => e['rel']), containsAll(<String>[
      's01e01.mkv',
      's01e02.mkv',
      p.join('extras', 'trailer.mkv'),
    ]));
    expect(files.every((e) => e['rel'] is String && e['size'] is int), isTrue);
    expect(dirs.map((e) => e['rel']), contains(p.join('extras')));
  });

  test('keeps clipboard order and skips paths that no longer exist', () {
    final first = writeFile('a.mkv', 1);
    final second = writeFile('b.mkv', 2);

    final plan = buildPastePlan([
      first.path,
      p.join(root.path, 'gone.mkv'),
      second.path,
    ]);

    expect(plan.map((e) => e['path']), [first.path, second.path]);
  });

  test('returns an empty plan for an empty clipboard', () {
    expect(buildPastePlan(const []), isEmpty);
  });
}
