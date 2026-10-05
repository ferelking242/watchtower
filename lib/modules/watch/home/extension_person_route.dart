import 'package:flutter/material.dart';

import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/media/tmdb_people_screen.dart';

/// Opens creator/studio pages in the shared people-profile screen while
/// keeping the extension's own detail URL and metadata attached.
bool isExtensionPersonItem(MManga item) {
  final link = item.link?.trim();
  if (link == null || link.isEmpty) return false;
  final path = Uri.tryParse(link)?.path.toLowerCase();
  if (path == null) return false;
  return RegExp(
    r'/(pornstar|pornstars|studio|studios|channel|channels)/',
  ).hasMatch('$path/');
}

void openExtensionPersonScreen({
  required BuildContext context,
  required Source source,
  required MManga item,
}) {
  final name = item.name?.trim().isNotEmpty == true
      ? item.name!.trim()
      : 'Profil';
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TmdbPersonScreen(
        person: TmdbPersonRef(id: 0, name: name),
        extensionSource: source,
        extensionPerson: item,
      ),
    ),
  );
}
