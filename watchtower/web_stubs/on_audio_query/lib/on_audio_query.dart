// Web stub for on_audio_query — audio query not available on Flutter Web.

class SongModel {
  final Map<String, dynamic> _data;
  SongModel(Map<String, dynamic> data) : _data = data;

  int? get id => _data['id'] as int?;
  String? get title => _data['title'] as String?;
  String? get displayName => _data['display_name'] as String?;
  String? get data => _data['data'] as String?;
  String? get album => _data['album'] as String?;
  String? get artist => _data['artist'] as String?;
  int? get duration => _data['duration'] as int?;
  int? get size => _data['size'] as int?;
  Map<String, dynamic> getMap() => _data;
}

enum OrderType { ASC_OR_SMALLER, DESC_OR_GREATER }
enum SortType { TITLE, DATE_ADDED, SIZE, DURATION, DISPLAY_NAME }
enum AudiosFrom { ALBUM, ARTIST, GENRE, PLAYLIST }

class OnAudioQuery {
  Future<bool> permissionsStatus() async => false;
  Future<bool> permissionsRequest() async => false;
  Future<List<SongModel>> querySongs({
    OrderType? orderType,
    SortType? sortType,
    bool? ignoreCase,
    UriType? uriType,
  }) async => [];
  Future<List<Map<String, dynamic>>> queryAudiosFrom(AudiosFrom type, Object filter) async => [];
}

enum UriType { EXTERNAL, INTERNAL }
