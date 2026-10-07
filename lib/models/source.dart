import 'dart:convert';

import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/filter.dart';
import 'package:watchtower/eval/model/m_source.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
part 'source.g.dart';

@collection
@Name("Sources")
class Source {
  Id? id;

  String? name;

  String? baseUrl;

  String? lang;

  bool? isActive;

  bool? isAdded;

  bool? isPinned;

  bool? isNsfw;

  String? sourceCode;

  String? sourceCodeUrl;

  String? typeSource;

  String? iconUrl;

  bool? isFullData;

  bool? hasCloudflare;

  bool? lastUsed;

  String? dateFormat;

  String? dateFormatLocale;

  String? apiUrl;

  String? version;

  String? versionLast;

  String? headers;

  /// Legacy extension metadata retained for existing stored records.
  bool? supportLatest;

  /// Legacy extension metadata retained for existing stored records.
  String? filterList;

  /// Legacy extension metadata retained for existing stored records.
  String? preferenceList;

  bool? isManga;

  @enumerated
  late ItemType itemType;

  String? appMinVerReq;

  String? additionalParams;

  bool? isLocal;

  bool? isObsolete;

  @enumerated
  SourceCodeLanguage sourceCodeLanguage = SourceCodeLanguage.dart;

  String? notes;

  String? customUserAgent;

  Repo? repo;

  int? updatedAt;

  // ── Extended metadata (catalogue fields persisted in additionalParams) ─────
  List<String>? subCategories;
  bool? supportsComments;
  bool? requiresAccount;
  bool? supportsLogin;
  bool? hasDRM;
  bool? isAggregator;
  String? paywall;
  String? upstream;
  List<String>? videoQualities;
  List<String>? contentSubtype;

  /// Path to the ui-layout JSON in the extensions repo.
  /// Example: "ui-layouts/redgifs.json"
  /// Null = no custom layout (standard Popular/Latest/Search only).
  String? uiLayout;

  /// Version of the downloaded layout file, compared against catalogue.
  String? uiLayoutVersion;

  /// Newer layout metadata waiting to be installed.
  ///
  /// The current Isar schema predates the marketplace metadata fields, so
  /// this value is persisted in the metadata envelope inside
  /// [additionalParams] rather than being added as a second schema migration.
  String? pendingUiLayoutVersion;

  Source({
    this.id = 0,
    this.name = '',
    this.baseUrl = '',
    this.lang = '',
    this.typeSource = '',
    this.iconUrl = '',
    this.dateFormat = '',
    this.dateFormatLocale = '',
    this.isActive = true,
    this.isAdded = false,
    this.isNsfw = false,
    this.isFullData = false,
    this.hasCloudflare = false,
    this.isPinned = false,
    this.lastUsed = false,
    this.apiUrl = "",
    this.sourceCodeUrl = "",
    this.version = "0.0.1",
    this.versionLast = "0.0.1",
    this.sourceCode = '',
    this.headers = '',
    this.supportLatest,
    this.filterList,
    this.preferenceList,
    this.isManga,
    this.itemType = ItemType.manga,
    this.appMinVerReq = "",
    this.additionalParams = "",
    this.isLocal = false,
    this.isObsolete = false,
    this.notes = '',
    this.customUserAgent,
    this.repo,
    this.updatedAt = 0,
    this.subCategories,
    this.supportsComments,
    this.requiresAccount,
    this.supportsLogin,
    this.hasDRM,
    this.isAggregator,
    this.paywall,
    this.upstream,
    this.videoQualities,
    this.contentSubtype,
  }) {
    hydrateExtendedMetadata();
  }

  static const _metadataMarker = '__watchtower_metadata__=';

  Map<String, dynamic> _metadataValues() {
    final value = additionalParams;
    if (value == null) return <String, dynamic>{};
    final match = RegExp(
      r'(?:^|\n)__watchtower_metadata__=([A-Za-z0-9_-]+)',
    ).firstMatch(value);
    if (match == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(match.group(1)!))),
      );
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Languages supported by the extension's catalogue entry.
  ///
  /// The index uses `langs`, while the persisted Source model predates that
  /// field. Store it in the existing metadata envelope so no Isar migration
  /// is needed.
  List<String> get supportedLanguages {
    final values = _metadataValues()['languages'];
    if (values is! List) return const [];
    return values
        .whereType<String>()
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  /// Enables tapping an extension card to play its short preview before
  /// opening the full detail/player screen.
  bool get touchToPreview => _metadataValues()['touchToPreview'] == true;

  void setTouchToPreview(bool? enabled) {
    final raw = (additionalParams ?? '')
        .split('\n$_metadataMarker')
        .first
        .trimRight();
    final metadata = _metadataValues();
    if (enabled == true) {
      metadata['touchToPreview'] = true;
    } else {
      metadata.remove('touchToPreview');
    }
    if (metadata.isEmpty) {
      additionalParams = raw;
      return;
    }
    final encoded = base64Url.encode(utf8.encode(jsonEncode(metadata)));
    additionalParams = raw.isEmpty
        ? '$_metadataMarker$encoded'
        : '$raw\n$_metadataMarker$encoded';
  }

  /// Optional website login page supplied by the extension catalogue.
  ///
  /// This stays in the existing metadata envelope to avoid changing the Isar
  /// schema for a catalogue-only field.
  String? get loginUrl {
    final value = _metadataValues()['loginUrl'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  void setLoginUrl(String? value) {
    final normalized = value?.trim();
    final raw = (additionalParams ?? '')
        .split('\n$_metadataMarker')
        .first
        .trimRight();
    final metadata = _metadataValues();
    if (normalized == null || normalized.isEmpty) {
      metadata.remove('loginUrl');
    } else {
      metadata['loginUrl'] = normalized;
    }
    if (metadata.isEmpty) {
      additionalParams = raw;
      return;
    }
    final encoded = base64Url.encode(utf8.encode(jsonEncode(metadata)));
    additionalParams = raw.isEmpty
        ? '$_metadataMarker$encoded'
        : '$raw\n$_metadataMarker$encoded';
  }

  void setSupportedLanguages(Iterable<String>? values) {
    final normalized = (values ?? const <String>[])
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final raw = (additionalParams ?? '')
        .split('\n$_metadataMarker')
        .first
        .trimRight();
    final metadata = _metadataValues();
    if (normalized.isEmpty) {
      metadata.remove('languages');
    } else {
      metadata['languages'] = normalized;
    }
    if (metadata.isEmpty) {
      additionalParams = raw;
      return;
    }
    final encoded = base64Url.encode(utf8.encode(jsonEncode(metadata)));
    additionalParams = raw.isEmpty
        ? '$_metadataMarker$encoded'
        : '$raw\n$_metadataMarker$encoded';
  }

  /// Rehydrates marketplace metadata after an Isar read.
  ///
  /// The extension runtime only relies on the existing free-form
  /// `additionalParams` string, so the envelope is appended on its own line
  /// and does not change legacy checks such as `contains('type=reel')`.
  void hydrateExtendedMetadata() {
    final value = additionalParams;
    if (value == null) return;
    final match = RegExp(
      r'(?:^|\n)__watchtower_metadata__=([A-Za-z0-9_-]+)',
    ).firstMatch(value);
    if (match == null) return;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(match.group(1)!))),
      );
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      subCategories ??= (data['subCategories'] as List?)
          ?.whereType<String>()
          .toList(growable: false);
      contentSubtype ??= (data['contentSubtype'] as List?)
          ?.whereType<String>()
          .toList(growable: false);
      supportsLogin ??= data['login'] as bool?;
      uiLayout ??= data['uiLayout'] as String?;
      uiLayoutVersion ??= data['uiLayoutVersion'] as String?;
      pendingUiLayoutVersion ??= data['pendingUiLayoutVersion'] as String?;
    } catch (_) {
      // Keep the original additionalParams value usable if an older build
      // left malformed metadata behind.
    }
  }

  /// Returns the value written to Isar while preserving legacy parameters.
  String get persistedAdditionalParams {
    final raw = (additionalParams ?? '')
        .split('\n$_metadataMarker')
        .first
        .trimRight();
    final metadata = <String, dynamic>{
      if (subCategories != null) 'subCategories': subCategories,
      if (contentSubtype != null) 'contentSubtype': contentSubtype,
      if (supportedLanguages.isNotEmpty) 'languages': supportedLanguages,
      if (supportsLogin != null) 'login': supportsLogin,
      if (uiLayout != null) 'uiLayout': uiLayout,
      if (uiLayoutVersion != null) 'uiLayoutVersion': uiLayoutVersion,
      if (pendingUiLayoutVersion != null)
        'pendingUiLayoutVersion': pendingUiLayoutVersion,
      if (touchToPreview) 'touchToPreview': true,
      if (loginUrl != null) 'loginUrl': loginUrl,
    };
    if (metadata.isEmpty) return raw;
    final encoded = base64Url.encode(utf8.encode(jsonEncode(metadata)));
    return '$raw\n$_metadataMarker$encoded';
  }

  FilterList? getFilterList() => filterList != null
      ? FilterList.fromJson(jsonDecode(filterList!) as Map<String, dynamic>)
      : null;

  Source.fromJson(Map<String, dynamic> json) {
    apiUrl = json['apiUrl'];
    appMinVerReq = json['appMinVerReq'];
    baseUrl = json['baseUrl'];
    dateFormat = json['dateFormat'];
    dateFormatLocale = json['dateFormatLocale'];
    hasCloudflare = json['hasCloudflare'];
    headers = json['headers'];
    supportLatest = json['supportLatest'];
    filterList = json['filterList'];
    preferenceList = json['preferenceList'];
    iconUrl = json['iconUrl'];
    id = json['id'] is int ? json['id'] : null;
    isActive = json['isActive'];
    isAdded = json['isAdded'];
    isFullData = json['isFullData'];
    isManga = json['isManga'];
    final itemTypeIndex = json['itemType'] is num
        ? (json['itemType'] as num).toInt()
        : 0;
    itemType = itemTypeIndex >= 0 && itemTypeIndex < ItemType.values.length
        ? ItemType.values[itemTypeIndex]
        : ItemType.manga;
    isNsfw = json['isNsfw'];
    isPinned = json['isPinned'];
    lang = (json['lang'] as String?)?.toLowerCase();
    lastUsed = json['lastUsed'];
    name = json['name'];
    sourceCode = json['sourceCode'];
    sourceCodeUrl = json['sourceCodeUrl'];
    typeSource = json['typeSource'];
    version = json['version'];
    versionLast = json['versionLast'];
    additionalParams = json['additionalParams'] ?? "";
    if (json.containsKey('loginUrl')) {
      final value = json['loginUrl'];
      setLoginUrl(value is String ? value : null);
    }
    final languages = json['langs'];
    if (languages is List) {
      setSupportedLanguages(languages.whereType<String>());
    }
    if (json['touchToPreview'] is bool) {
      setTouchToPreview(json['touchToPreview'] as bool);
    }
    isObsolete = json['isObsolete'];
    isLocal = json['isLocal'];
    final sourceCodeLanguageIndex = json['sourceCodeLanguage'] is num
        ? (json['sourceCodeLanguage'] as num).toInt()
        : 0;
    sourceCodeLanguage =
        sourceCodeLanguageIndex >= 0 &&
            sourceCodeLanguageIndex < SourceCodeLanguage.values.length
        ? SourceCodeLanguage.values[sourceCodeLanguageIndex]
        : SourceCodeLanguage.dart;
    notes = json['notes'] ?? "";
    customUserAgent = json['customUserAgent'] as String?;
    repo = json['repo'] != null ? Repo.fromJson(json['repo']) : null;
    updatedAt = json['updatedAt'];
    subCategories = (json['subCategories'] as List<dynamic>?)?.cast<String>();
    supportsComments = json['supportsComments'] as bool?;
    requiresAccount = json['requiresAccount'] as bool?;
    supportsLogin = json['login'] as bool?;
    hasDRM = json['hasDRM'] as bool?;
    isAggregator = json['isAggregator'] as bool?;
    paywall = json['paywall'] as String?;
    upstream = json['upstream'] as String?;
    videoQualities = (json['videoQualities'] as List<dynamic>?)?.cast<String>();
    contentSubtype = (json['contentSubtype'] as List<dynamic>?)?.cast<String>();
    uiLayout = json['uiLayout'] as String?;
    uiLayoutVersion = json['uiLayoutVersion'] as String?;
    pendingUiLayoutVersion = json['pendingUiLayoutVersion'] as String?;
    hydrateExtendedMetadata();
  }

  Map<String, dynamic> toJson() => {
    'apiUrl': apiUrl,
    'appMinVerReq': appMinVerReq,
    'baseUrl': baseUrl,
    'dateFormat': dateFormat,
    'dateFormatLocale': dateFormatLocale,
    'hasCloudflare': hasCloudflare,
    'headers': headers,
    'supportLatest': supportLatest,
    'filterList': filterList,
    'preferenceList': preferenceList,
    'iconUrl': iconUrl,
    'id': id,
    'isActive': isActive,
    'isAdded': isAdded,
    'isFullData': isFullData,
    'isManga': isManga,
    'itemType': itemType.index,
    'isNsfw': isNsfw,
    'isPinned': isPinned,
    'lang': lang,
    'lastUsed': lastUsed,
    'name': name,
    'sourceCode': sourceCode,
    'sourceCodeUrl': sourceCodeUrl,
    'typeSource': typeSource,
    'version': version,
    'versionLast': versionLast,
    'additionalParams': persistedAdditionalParams,
    'loginUrl': loginUrl,
    if (touchToPreview) 'touchToPreview': true,
    'sourceCodeLanguage': sourceCodeLanguage.index,
    'isObsolete': isObsolete,
    'isLocal': isLocal,
    'notes': notes,
    'customUserAgent': customUserAgent,
    'repo': repo?.toJson(),
    'updatedAt': updatedAt ?? 0,
    'subCategories': subCategories,
    'supportsComments': supportsComments,
    'requiresAccount': requiresAccount,
    'login': supportsLogin,
    'hasDRM': hasDRM,
    'isAggregator': isAggregator,
    'paywall': paywall,
    'upstream': upstream,
    'videoQualities': videoQualities,
    'contentSubtype': contentSubtype,
    'uiLayout': uiLayout,
    'uiLayoutVersion': uiLayoutVersion,
    'pendingUiLayoutVersion': pendingUiLayoutVersion,
  };

  bool get isTorrent => (typeSource?.toLowerCase() ?? "") == "torrent";

  /// True when the extension ships a ui-layout JSON that declares home sections.
  /// Mirrors Aidoku's `source.features.providesHome`.
  /// Used to show/hide the "Accueil" pill tab in every source home screen.
  bool get providesHome => uiLayout != null && uiLayout!.isNotEmpty;

  /// Older installed sources predate the catalogue flag. A usable site URL
  /// is not proof that they support an account flow. Absence is opt-out.
  bool get loginAvailable => supportsLogin == true;

  MSource toMSource() {
    return MSource(
      id: id,
      name: name,
      hasCloudflare: hasCloudflare,
      isFullData: isFullData,
      lang: lang,
      baseUrl: baseUrl,
      apiUrl: apiUrl,
      dateFormat: dateFormat,
      dateFormatLocale: dateFormatLocale,
      additionalParams: additionalParams,
    );
  }

  /// Riverpod provider families receive freshly deserialized Source instances
  /// after returning to an extension. Compare the stable source identity so
  /// their existing short-lived provider cache remains usable.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Source) return false;
    return id == other.id &&
        name == other.name &&
        lang == other.lang &&
        baseUrl == other.baseUrl &&
        sourceCodeUrl == other.sourceCodeUrl &&
        version == other.version;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, lang, baseUrl, sourceCodeUrl, version);
}

enum SourceCodeLanguage { dart, javascript, unsupported }
