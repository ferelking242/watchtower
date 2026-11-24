import 'dart:convert';

import 'package:reel/remote/reel_transport.dart';
import 'package:shelf/shelf.dart';

import 'package:watchtower/remote/remote_api_handler.dart';

/// Answers Reel's Watchtower API calls from the extensions running in this app.
///
/// Reel normally talks to a Watchtower server. Inside the app there is no
/// server, so this transport replays the same paths through
/// [RemoteApiHandler], the handler that already backs the embedded HTTP API.
/// One code path for both callers: the JSON Reel parses is the JSON the server
/// would have produced.
class ReelLocalTransport implements ReelTransport {
  ReelLocalTransport(this._handler, {this.sourceId});

  final RemoteApiHandler _handler;

  /// Extension the shell is mounted for. When set, `/api/sources` is narrowed
  /// to it so Reel cannot fall back to another installed extension.
  final String? sourceId;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('http://reel.local$path')
        .replace(queryParameters: query);
    final response = await _dispatch(uri.pathSegments, Request('GET', uri));
    final body = await response.readAsString();

    if (response.statusCode != 200) {
      throw StateError(
        'Reel transport: ${response.statusCode} on $path — $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is List) return _scoped({'list': decoded});
    if (decoded is Map<String, dynamic>) return _scoped(decoded);
    return _scoped({'data': decoded});
  }

  Map<String, dynamic> _scoped(Map<String, dynamic> payload) {
    final id = sourceId;
    final sources = payload['sources'];
    if (id == null || sources is! List) return payload;
    final mine = sources
        .whereType<Map>()
        .where((s) => s['id']?.toString() == id)
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    // An id mismatch must not empty the feed: keep the full list in that case.
    return mine.isEmpty ? payload : {...payload, 'sources': mine};
  }

  Future<Response> _dispatch(
    List<String> segments,
    Request request,
  ) async {
    // /api/sources
    if (segments.length == 2 && segments[1] == 'sources') {
      return _handler.getSources(request);
    }
    // /api/sources/<id>/<operation>
    if (segments.length >= 4 && segments[1] == 'sources') {
      final sourceId = segments[2];
      switch (segments[3]) {
        case 'popular':
          return _handler.getPopular(request, sourceId);
        case 'latest':
          return _handler.getLatest(request, sourceId);
        case 'search':
          return _handler.search(request, sourceId);
        case 'detail':
          return _handler.getDetailByUrl(request, sourceId);
        case 'videos':
          return _handler.getVideos(request, sourceId);
        case 'filters':
          return _handler.getFilters(request, sourceId);
        case 'custom':
          return _handler.getCustomList(request, sourceId);
        default:
          return Response.notFound('Reel transport: unknown operation');
      }
    }
    return Response.notFound('Reel transport: unknown path /${segments.join('/')}');
  }

  @override
  void close() {}
}
