// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_file_cache.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetLocalFileCacheCollection on Isar {
  IsarCollection<LocalFileCache> get localFileCaches => this.collection();
}

const LocalFileCacheSchema = CollectionSchema(
  name: r'LocalFileCache',
  id: -7414987195037502886,
  properties: {
    r'cachedAt': PropertySchema(
      id: 0,
      name: r'cachedAt',
      type: IsarType.long,
    ),
    r'filePath': PropertySchema(
      id: 1,
      name: r'filePath',
      type: IsarType.string,
    ),
    r'fileSize': PropertySchema(
      id: 2,
      name: r'fileSize',
      type: IsarType.long,
    ),
    r'indexedItemId': PropertySchema(
      id: 3,
      name: r'indexedItemId',
      type: IsarType.long,
    ),
    r'modifiedAt': PropertySchema(
      id: 4,
      name: r'modifiedAt',
      type: IsarType.long,
    ),
    r'quickHash': PropertySchema(
      id: 5,
      name: r'quickHash',
      type: IsarType.string,
    ),
    r'scanCount': PropertySchema(
      id: 6,
      name: r'scanCount',
      type: IsarType.long,
    ),
  },

  estimateSize: _localFileCacheEstimateSize,
  serialize: _localFileCacheSerialize,
  deserialize: _localFileCacheDeserialize,
  deserializeProp: _localFileCacheDeserializeProp,
  idName: r'id',
  indexes: {
    r'filePath': IndexSchema(
      id: 5678901234567890123,
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
  },
  links: {},
  embeddedSchemas: {},

  getId: _localFileCacheGetId,
  getLinks: _localFileCacheGetLinks,
  attach: _localFileCacheAttach,
  version: '3.3.2',
);

int _localFileCacheEstimateSize(
  LocalFileCache object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    bytesCount += 3 + object.filePath.length * 3;
  }
  {
    final value = object.quickHash;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _localFileCacheSerialize(
  LocalFileCache object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.cachedAt);
  writer.writeString(offsets[1], object.filePath);
  writer.writeLong(offsets[2], object.fileSize);
  writer.writeLong(offsets[3], object.indexedItemId);
  writer.writeLong(offsets[4], object.modifiedAt);
  writer.writeString(offsets[5], object.quickHash);
  writer.writeLong(offsets[6], object.scanCount);
}

LocalFileCache _localFileCacheDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = LocalFileCache();
  object.cachedAt = reader.readLong(offsets[0]);
  object.filePath = reader.readString(offsets[1]);
  object.fileSize = reader.readLong(offsets[2]);
  object.id = id;
  object.indexedItemId = reader.readLongOrNull(offsets[3]);
  object.modifiedAt = reader.readLong(offsets[4]);
  object.quickHash = reader.readStringOrNull(offsets[5]);
  object.scanCount = reader.readLong(offsets[6]);
  return object;
}

P _localFileCacheDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _localFileCacheGetId(LocalFileCache object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _localFileCacheGetLinks(LocalFileCache object) {
  return [];
}

void _localFileCacheAttach(
    IsarCollection<dynamic> col, Id id, LocalFileCache object) {
  object.id = id;
}

extension LocalFileCacheQueryWhereSort
    on QueryBuilder<LocalFileCache, LocalFileCache, QWhere> {
  QueryBuilder<LocalFileCache, LocalFileCache, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension LocalFileCacheQueryWhere
    on QueryBuilder<LocalFileCache, LocalFileCache, QWhereClause> {
  QueryBuilder<LocalFileCache, LocalFileCache, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query
          .addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterWhereClause>
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
}

extension LocalFileCacheQueryFilter
    on QueryBuilder<LocalFileCache, LocalFileCache, QFilterCondition> {
  QueryBuilder<LocalFileCache, LocalFileCache, QAfterFilterCondition>
      filePathEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterFilterCondition>
      filePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'filePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterFilterCondition>
      cachedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
          FilterCondition.equalTo(property: r'cachedAt', value: value));
    });
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterFilterCondition>
      modifiedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
          FilterCondition.equalTo(property: r'modifiedAt', value: value));
    });
  }
}

extension LocalFileCacheQueryObject
    on QueryBuilder<LocalFileCache, LocalFileCache, QFilterCondition> {}

extension LocalFileCacheQueryLinks
    on QueryBuilder<LocalFileCache, LocalFileCache, QFilterCondition> {}

extension LocalFileCacheQuerySortBy
    on QueryBuilder<LocalFileCache, LocalFileCache, QSortBy> {
  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      sortByFilePath() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'filePath', Sort.asc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      sortByFilePathDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'filePath', Sort.desc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      sortByCachedAt() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'cachedAt', Sort.asc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      sortByCachedAtDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'cachedAt', Sort.desc));
  }
}

extension LocalFileCacheQuerySortThenBy
    on QueryBuilder<LocalFileCache, LocalFileCache, QSortThenBy> {
  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy> thenById() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'id', Sort.asc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'id', Sort.desc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      thenByFilePath() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'filePath', Sort.asc));
  }

  QueryBuilder<LocalFileCache, LocalFileCache, QAfterSortBy>
      thenByFilePathDesc() {
    return QueryBuilder.apply(
        this, (query) => query.addSortBy(r'filePath', Sort.desc));
  }
}

extension LocalFileCacheQueryWhereDistinct
    on QueryBuilder<LocalFileCache, LocalFileCache, QDistinct> {
  QueryBuilder<LocalFileCache, LocalFileCache, QDistinct>
      distinctByFilePath({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filePath', caseSensitive: caseSensitive);
    });
  }
}

extension LocalFileCacheQueryProperty
    on QueryBuilder<LocalFileCache, LocalFileCache, QQueryProperty> {
  QueryBuilder<LocalFileCache, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<LocalFileCache, String, QQueryOperations> filePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filePath');
    });
  }

  QueryBuilder<LocalFileCache, int, QQueryOperations> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileSize');
    });
  }

  QueryBuilder<LocalFileCache, int, QQueryOperations> modifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'modifiedAt');
    });
  }

  QueryBuilder<LocalFileCache, int, QQueryOperations> cachedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cachedAt');
    });
  }
}
