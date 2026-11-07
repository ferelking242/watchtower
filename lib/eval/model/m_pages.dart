import 'package:watchtower/eval/model/m_manga.dart';

class MPages {
  List<MManga> list;
  bool hasNextPage;

  /// Total number of items the listing declares, when the extension knows it.
  ///
  /// XVideos profile pages expose `nb_videos`; most extensions leave it null.
  /// A non-null total lets a surface show the real catalogue size and stop
  /// paging at the announced end instead of inferring it from `hasNextPage`.
  int? total;

  MPages({required this.list, this.hasNextPage = false, this.total});

  factory MPages.fromJson(Map<String, dynamic> json) {
    final rawTotal = json['total'];
    return MPages(
      list: json['list'] != null
          ? (json['list'] as List).map((e) => MManga.fromJson(e)).toList()
          : [],
      hasNextPage: json['hasNextPage'],
      total: rawTotal is int ? rawTotal : int.tryParse('$rawTotal'),
    );
  }

  Map<String, dynamic> toJson() => {
    'list': list.map((v) => v.toJson()).toList(),
    'hasNextPage': hasNextPage,
    'total': total,
  };
}
