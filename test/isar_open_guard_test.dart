import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/services/isar_open_guard.dart';

CollectionSchema<Object> _collection(
  String name, {
  int id = 1,
  List<PropertySchema> properties = const [],
  Map<String, LinkSchema> links = const {},
  Map<String, IndexSchema> indexes = const {},
  Map<String, Schema<dynamic>> embedded = const {},
}) {
  return CollectionSchema<Object>(
    id: id,
    name: name,
    properties: {for (final p in properties) p.name: p},
    idName: 'id',
    indexes: indexes,
    links: links,
    embeddedSchemas: embedded,
    estimateSize: (_, _, _) => 0,
    serialize: (_, _, _, _) {},
    deserialize: (_, _, _, _) => Object(),
    deserializeProp: (_, _, _, _) => null,
    getId: (_) => 0,
    getLinks: (_) => const [],
    attach: (_, _, _) {},
    version: Isar.version,
  );
}

PropertySchema _property(
  String name, {
  int id = 0,
  IsarType type = IsarType.string,
  String? target,
}) {
  return PropertySchema(id: id, name: name, type: type, target: target);
}

Schema<dynamic> _embeddedSchema(String name, {int id = 7}) {
  return Schema<dynamic>(
    id: id,
    name: name,
    properties: {'value': _property('value')},
    estimateSize: (_, _, _) => 0,
    serialize: (_, _, _, _) {},
    deserialize: (_, _, _, _) => null,
    deserializeProp: (_, _, _, _) => null,
  );
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('isar_open_guard_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  File dbFile(Directory dir, [String suffix = '.isar']) =>
      File('${dir.path}/watchtowerDb$suffix');

  Future<void> writeDb(Directory dir) async {
    await dbFile(dir).writeAsString('db');
    await dbFile(dir, '.isar.lock').writeAsString('lock');
  }

  group('fingerprint', () {
    test('is stable for the same schema', () {
      final a = [
        _collection('Manga', properties: [_property('title'), _property('n')]),
      ];
      final b = [
        _collection('Manga', properties: [_property('title'), _property('n')]),
      ];
      expect(IsarOpenGuard.fingerprint(a), IsarOpenGuard.fingerprint(b));
    });

    test('ignores declaration order', () {
      final a = [
        _collection(
          'Manga',
          properties: [_property('title'), _property('author')],
        ),
      ];
      final b = [
        _collection(
          'Manga',
          properties: [_property('author'), _property('title')],
        ),
      ];
      expect(IsarOpenGuard.fingerprint(a), IsarOpenGuard.fingerprint(b));
    });

    test('changes when a property is added or retyped', () {
      final base = IsarOpenGuard.fingerprint([
        _collection('Manga', properties: [_property('title')]),
      ]);
      final added = IsarOpenGuard.fingerprint([
        _collection(
          'Manga',
          properties: [_property('title'), _property('author')],
        ),
      ]);
      final retyped = IsarOpenGuard.fingerprint([
        _collection(
          'Manga',
          properties: [_property('title', type: IsarType.stringList)],
        ),
      ]);
      expect(added, isNot(base));
      expect(retyped, isNot(base));
    });

    test('changes with the salt so a manual bump still wipes', () {
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      expect(
        IsarOpenGuard.fingerprint(schemas, salt: '14'),
        isNot(IsarOpenGuard.fingerprint(schemas, salt: '15')),
      );
    });
  });

  group('prepareOpen', () {
    test('adopts the schema on the first launch without wiping', () async {
      await writeDb(temp);
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];

      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.none);
      expect(await dbFile(temp).exists(), isTrue);
      expect(
        await File('${temp.path}/watchtowerDb.schema_fingerprint').exists(),
        isTrue,
      );
    });

    test('honours the manual version carried by an old snapshot', () async {
      final guard = IsarOpenGuard(temp, salt: '14');
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await writeDb(temp);
      await File(
        '${temp.path}/watchtowerDb.schema_version',
      ).writeAsString('13');

      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.schemaChanged);
      expect(await dbFile(temp).exists(), isFalse);
      expect(
        await File('${temp.path}/watchtowerDb.schema_version').readAsString(),
        '14',
      );
    });

    test('keeps a database whose manual version matches', () async {
      final guard = IsarOpenGuard(temp, salt: '14');
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await writeDb(temp);
      await File(
        '${temp.path}/watchtowerDb.schema_version',
      ).writeAsString('14');

      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.none);
      expect(await dbFile(temp).exists(), isTrue);
    });

    test('sets a database from another schema aside', () async {
      final guard = IsarOpenGuard(temp);
      await guard.prepareOpen([
        _collection('Manga', properties: [_property('title')]),
      ]);
      await writeDb(temp);

      final recovery = await guard.prepareOpen([
        _collection(
          'Manga',
          properties: [_property('title'), _property('author')],
        ),
      ]);

      expect(recovery, IsarOpenRecovery.schemaChanged);
      expect(await dbFile(temp).exists(), isFalse);
      final quarantined = Directory('${temp.path}/isar-quarantine');
      expect(await quarantined.list().length, 1);
      final kept = await quarantined.list().first;
      expect(await File('${kept.path}/watchtowerDb.isar').readAsString(), 'db');
    });

    test('sets a database aside after an aborted open', () async {
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await guard.prepareOpen(schemas);
      await writeDb(temp);

      // Simulate a launch that died inside Isar.open.
      await guard.markOpening();

      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.abortedOpen);
      expect(await dbFile(temp).exists(), isFalse);
      expect(
        await File('${temp.path}/watchtowerDb.open_inflight').exists(),
        isFalse,
      );
    });

    test('keeps the database when it aborts the open again', () async {
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await guard.prepareOpen(schemas);
      await writeDb(temp);
      await guard.markOpening();
      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.abortedOpen);

      await writeDb(temp);
      await guard.markOpening();

      expect(
        await guard.prepareOpen(schemas),
        IsarOpenRecovery.repeatedAbortedOpen,
      );
      expect(await dbFile(temp).exists(), isTrue);
    });

    test('does not treat a Dart-level open failure as a crash', () async {
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await guard.prepareOpen(schemas);
      await guard.markOpening();
      await guard.openFailed();

      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.none);
    });
  });

  group('openSucceeded', () {
    test('clears the marker and the crash counter', () async {
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];
      await guard.prepareOpen(schemas);
      await guard.markOpening();
      await guard.openSucceeded();

      expect(
        await File('${temp.path}/watchtowerDb.open_inflight').exists(),
        isFalse,
      );
      expect(
        await File('${temp.path}/watchtowerDb.open_failures').exists(),
        isFalse,
      );
      expect(await guard.prepareOpen(schemas), IsarOpenRecovery.none);
    });
  });

  group('quarantine', () {
    test('keeps at most two database sets', () async {
      final guard = IsarOpenGuard(temp);
      final schemas = [
        _collection('Manga', properties: [_property('title')]),
      ];

      for (var i = 0; i < 4; i++) {
        await writeDb(temp);
        await File(
          '${temp.path}/watchtowerDb.schema_fingerprint',
        ).writeAsString('stale-$i');
        await guard.prepareOpen(schemas);
      }

      final quarantined = Directory('${temp.path}/isar-quarantine');
      expect(await quarantined.list().length, lessThanOrEqualTo(2));
    });

    test('changes when an embedded target is dropped', () {
      final withEmbedded = [
        _collection(
          'Source',
          properties: [
            _property('repo', type: IsarType.object, target: 'Repo'),
          ],
          embedded: {'Repo': _embeddedSchema('Repo')},
        ),
      ];
      final withoutTarget = [
        _collection(
          'Source',
          properties: [_property('repo', type: IsarType.object)],
          embedded: {'Repo': _embeddedSchema('Repo')},
        ),
      ];
      expect(
        IsarOpenGuard.fingerprint(withEmbedded),
        isNot(IsarOpenGuard.fingerprint(withoutTarget)),
      );
    });
  });
}
