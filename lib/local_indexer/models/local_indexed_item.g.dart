// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_indexed_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalIndexedItemCollection on Isar {
  IsarCollection<LocalIndexedItem> get localIndexedItems => this.collection();
}

const LocalIndexedItemSchema = CollectionSchema(
  name: r'LocalIndexedItem',
  id: 6736314745990097625,
  properties: {
    r'audioCodec': PropertySchema(
      id: 0,
      name: r'audioCodec',
      type: IsarType.string,
    ),
    r'canonicalKey': PropertySchema(
      id: 1,
      name: r'canonicalKey',
      type: IsarType.string,
    ),
    r'chapter': PropertySchema(id: 2, name: r'chapter', type: IsarType.long),
    r'codec': PropertySchema(id: 3, name: r'codec', type: IsarType.string),
    r'confidence': PropertySchema(
      id: 4,
      name: r'confidence',
      type: IsarType.double,
    ),
    r'duplicateIds': PropertySchema(
      id: 5,
      name: r'duplicateIds',
      type: IsarType.longList,
    ),
    r'episode': PropertySchema(id: 6, name: r'episode', type: IsarType.long),
    r'filePath': PropertySchema(
      id: 7,
      name: r'filePath',
      type: IsarType.string,
    ),
    r'fileSize': PropertySchema(
      id: 8,
      name: r'fileSize',
      type: IsarType.long,
    ),
    r'indexedAt': PropertySchema(
      id: 9,
      name: r'indexedAt',
      type: IsarType.long,
    ),
    r'kind': PropertySchema(
      id: 10,
      name: r'kind',
      type: IsarType.byte,
      enumMap: _LocalIndexedItemkindEnumValueMap,
    ),
    r'language': PropertySchema(
      id: 11,
      name: r'language',
      type: IsarType.string,
    ),
    r'mimeType': PropertySchema(
      id: 12,
      name: r'mimeType',
      type: IsarType.string,
    ),
    r'modifiedAt': PropertySchema(
      id: 13,
      name: r'modifiedAt',
      type: IsarType.long,
    ),
    r'part': PropertySchema(id: 14, name: r'part', type: IsarType.long),
    r'quality': PropertySchema(id: 15, name: r'quality', type: IsarType.string),
    r'rawFilename': PropertySchema(
      id: 16,
      name: r'rawFilename',
      type: IsarType.string,
    ),
    r'releaseGroup': PropertySchema(
      id: 17,
      name: r'releaseGroup',
      type: IsarType.string,
    ),
    r'season': PropertySchema(id: 18, name: r'season', type: IsarType.long),
    r'title': PropertySchema(id: 19, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.long,
    ),
    r'volume': PropertySchema(id: 21, name: r'volume', type: IsarType.long),
  },

  estimateSize: _localIndexedItemEstimateSize,
  serialize: _localIndexedItemSerialize,
  deserialize: _localIndexedItemDeserialize,
  deserializeProp: _localIndexedItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'canonicalKey': IndexSchema(
      id: 2718281828459045235,
      name: r'canonicalKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'canonicalKey',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'filePath': IndexSchema(
      id: 1618033988749894848,
      name: r'filePath',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'filePath',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'title': IndexSchema(
      id: 1234567890123456789,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _localIndexedItemGetId,
  getLinks: _localIndexedItemGetLinks,
  attach: _localIndexedItemAttach,
  version: '3.3.2',
);

int _localIndexedItemEstimateSize(
  LocalIndexedItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.audioCodec;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    bytesCount += 3 + object.canonicalKey.length * 3;
  }
  {
    final value = object.codec;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    bytesCount += 3 + object.duplicateIds.length * 8;
  }
  {
    bytesCount += 3 + object.filePath.length * 3;
  }
  {
    final value = object.language;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.mimeType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.quality;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    bytesCount += 3 + object.rawFilename.length * 3;
  }
  {
    final value = object.releaseGroup;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    bytesCount += 3 + object.title.length * 3;
  }
  return bytesCount;
}

void _localIndexedItemSerialize(
  LocalIndexedItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.audioCodec);
  writer.writeString(offsets[1], object.canonicalKey);
  writer.writeLong(offsets[2], object.chapter);
  writer.writeString(offsets[3], object.codec);
  writer.writeDouble(offsets[4], object.confidence);
  writer.writeLongList(offsets[5], object.duplicateIds);
  writer.writeLong(offsets[6], object.episode);
  writer.writeString(offsets[7], object.filePath);
  writer.writeLong(offsets[8], object.fileSize);
  writer.writeLong(offsets[9], object.indexedAt);
  writer.writeByte(offsets[10], object.kind.index);
  writer.writeString(offsets[11], object.language);
  writer.writeString(offsets[12], object.mimeType);
  writer.writeLong(offsets[13], object.modifiedAt);
  writer.writeLong(offsets[14], object.part);
  writer.writeString(offsets[15], object.quality);
  writer.writeString(offsets[16], object.rawFilename);
  writer.writeString(offsets[17], object.releaseGroup);
  writer.writeLong(offsets[18], object.season);
  writer.writeString(offsets[19], object.title);
  writer.writeLong(offsets[20], object.updatedAt);
  writer.writeLong(offsets[21], object.volume);
}

LocalIndexedItem _localIndexedItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalIndexedItem();
  object.audioCodec = reader.readStringOrNull(offsets[0]);
  object.canonicalKey = reader.readString(offsets[1]);
  object.chapter = reader.readLongOrNull(offsets[2]);
  object.codec = reader.readStringOrNull(offsets[3]);
  object.confidence = reader.readDouble(offsets[4]);
  object.duplicateIds = reader.readLongList(offsets[5]) ?? [];
  object.episode = reader.readLongOrNull(offsets[6]);
  object.filePath = reader.readString(offsets[7]);
  object.fileSize = reader.readLong(offsets[8]);
  object.id = id;
  object.indexedAt = reader.readLong(offsets[9]);
  object.kind =
      _LocalIndexedItemkindValueEnumMap[reader.readByteOrNull(offsets[10])] ??
      LocalMediaKind.unknown;
  object.language = reader.readStringOrNull(offsets[11]);
  object.mimeType = reader.readStringOrNull(offsets[12]);
  object.modifiedAt = reader.readLong(offsets[13]);
  object.part = reader.readLongOrNull(offsets[14]);
  object.quality = reader.readStringOrNull(offsets[15]);
  object.rawFilename = reader.readString(offsets[16]);
  object.releaseGroup = reader.readStringOrNull(offsets[17]);
  object.season = reader.readLongOrNull(offsets[18]);
  object.title = reader.readString(offsets[19]);
  object.updatedAt = reader.readLongOrNull(offsets[20]);
  object.volume = reader.readLongOrNull(offsets[21]);
  return object;
}

P _localIndexedItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readLongList(offset) ?? []) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (_LocalIndexedItemkindValueEnumMap[reader.readByteOrNull(offset)] ??
              LocalMediaKind.unknown) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readStringOrNull(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readLongOrNull(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readLongOrNull(offset)) as P;
    case 21:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _LocalIndexedItemkindEnumValueMap = {
  'anime': 0,
  'series': 1,
  'movie': 2,
  'manga': 3,
  'novel': 4,
  'unknown': 5,
};
const _LocalIndexedItemkindValueEnumMap = {
  0: LocalMediaKind.anime,
  1: LocalMediaKind.series,
  2: LocalMediaKind.movie,
  3: LocalMediaKind.manga,
  4: LocalMediaKind.novel,
  5: LocalMediaKind.unknown,
};

Id _localIndexedItemGetId(LocalIndexedItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localIndexedItemGetLinks(LocalIndexedItem object) {
  return [];
}

void _localIndexedItemAttach(
    IsarCollection<dynamic> col, Id id, LocalIndexedItem object) {
  object.id = id;
}

extension LocalIndexedItemQueryWhereSort
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QWhere> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalIndexedItemQueryWhere
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QWhereClause> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query
          .addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterWhereClause>
      filePathEqualTo(String filePath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'filePath',
          value: [filePath],
        ),
      );
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterWhereClause>
      canonicalKeyEqualTo(String canonicalKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'canonicalKey',
          value: [canonicalKey],
        ),
      );
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterWhereClause>
      titleEqualTo(String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'title',
          value: [title],
        ),
      );
    });
  }
}

extension LocalIndexedItemQueryFilter
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QFilterCondition> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      canonicalKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      filePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      kindEqualTo(LocalMediaKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
          FilterCondition.equalTo(property: r'kind', value: value));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      indexedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'indexedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      seasonEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
          FilterCondition.equalTo(property: r'season', value: value));
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterFilterCondition>
      episodeEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
          FilterCondition.equalTo(property: r'episode', value: value));
    });
  }
}

extension LocalIndexedItemQueryObject
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QFilterCondition> {}

extension LocalIndexedItemQueryLinks
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QFilterCondition> {}

extension LocalIndexedItemQuerySortBy
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QSortBy> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'title', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'title', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByIndexedAt() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'indexedAt', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByIndexedAtDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'indexedAt', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByKind() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'kind', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByKindDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'kind', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByCanonicalKey() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'canonicalKey', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      sortByCanonicalKeyDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'canonicalKey', Sort.desc));
  }
}

extension LocalIndexedItemQuerySortThenBy
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QSortThenBy> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'id', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'id', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'title', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'title', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByIndexedAt() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'indexedAt', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByIndexedAtDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'indexedAt', Sort.desc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'kind', Sort.asc));
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QAfterSortBy>
      thenByKindDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'kind', Sort.desc));
  }
}

extension LocalIndexedItemQueryWhereDistinct
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QDistinct> {
  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QDistinct>
      distinctByCanonicalKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'canonicalKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LocalIndexedItem, LocalIndexedItem, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }
}

extension LocalIndexedItemQueryProperty
    on QueryBuilder<LocalIndexedItem, LocalIndexedItem, QQueryProperty> {
  QueryBuilder<LocalIndexedItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalIndexedItem, String, QQueryOperations>
      canonicalKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'canonicalKey');
    });
  }

  QueryBuilder<LocalIndexedItem, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<LocalIndexedItem, LocalMediaKind, QQueryOperations>
      kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<LocalIndexedItem, String, QQueryOperations> filePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filePath');
    });
  }

  QueryBuilder<LocalIndexedItem, int, QQueryOperations> indexedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'indexedAt');
    });
  }
}
