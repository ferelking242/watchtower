import 'package:watchtower/models/page.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/video.dart';

import 'model/filter.dart';
import 'model/m_manga.dart';
import 'model/m_pages.dart';
import 'model/source_preference.dart';

abstract interface class ExtensionService {
  late Source source;

  ExtensionService(this.source);

  String get sourceBaseUrl;
  bool get supportsLatest;

  void dispose();

  Map<String, String> getHeaders();

  Future<MPages> getPopular(int page);

  Future<MPages> getLatestUpdates(int page);

  Future<MPages> search(String query, int page, List<dynamic> filters);

  Future<MManga> getDetail(String url);

  Future<List<PageUrl>> getPageList(String url);

  Future<List<Video>> getVideoList(String url);

  Future<String> getHtmlContent(String name, String url);

  Future<String> cleanHtmlContent(String html);

  FilterList getFilterList();

  List<SourcePreference> getSourcePreferences();

  /// Returns named browse tabs beyond Popular/Latest.
  /// Each map must have "id" and "name" keys.
  /// Default: empty list (no extra tabs).
  List<Map<String, dynamic>> getCustomLists();

  /// Fetches items for a custom browse tab identified by [id].
  Future<MPages> getCustomList(String id, int page);
}
