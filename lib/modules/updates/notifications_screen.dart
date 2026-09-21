import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/fetch_sources_list.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<_NotificationData> _load() async {
    final sources = await isar.sources.buildQuery<Source>().findAll();
    final extensionUpdates =
        sources
            .where(
              (source) =>
                  source.isAdded == true &&
                  source.version != null &&
                  source.versionLast != null &&
                  compareVersions(source.version!, source.versionLast!) < 0,
            )
            .toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    final libraryUpdates = await isar.updates.count();
    return _NotificationData(
      extensionUpdates: extensionUpdates,
      libraryUpdates: libraryUpdates,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Broken.arrow_left),
        ),
      ),
      body: FutureBuilder<_NotificationData>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Impossible de charger les notifications.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }
          final data = snapshot.data!;
          if (data.extensionUpdates.isEmpty && data.libraryUpdates == 0) {
            return _EmptyNotifications(color: cs.onSurfaceVariant);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            children: [
              if (data.extensionUpdates.isNotEmpty)
                _NotificationCard(
                  icon: Broken.refresh_2,
                  color: Colors.orange.shade700,
                  title:
                      '${data.extensionUpdates.length} mise${data.extensionUpdates.length == 1 ? '' : 's'} à jour disponible${data.extensionUpdates.length == 1 ? '' : 's'}',
                  subtitle:
                      'Tes extensions installées ont une nouvelle version.',
                  child: Column(
                    children: data.extensionUpdates
                        .map(
                          (source) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _SourceIcon(source: source),
                            title: Text(source.name ?? 'Extension'),
                            subtitle: Text(
                              'v${source.version} → v${source.versionLast}',
                            ),
                            trailing: Icon(
                              Broken.arrow_right,
                              color: cs.onSurfaceVariant,
                            ),
                            onTap: () => context.push(
                              '/extension_detail',
                              extra: source,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              if (data.libraryUpdates > 0) ...[
                const SizedBox(height: 12),
                _NotificationCard(
                  icon: Broken.bookmark,
                  color: cs.primary,
                  title:
                      '${data.libraryUpdates} mise${data.libraryUpdates == 1 ? '' : 's'} de bibliothèque',
                  subtitle: 'De nouveaux chapitres sont disponibles.',
                  action: TextButton.icon(
                    onPressed: () => context.push('/updates'),
                    icon: const Icon(Broken.arrow_right),
                    label: const Text('Voir les mises à jour'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationData {
  final List<Source> extensionUpdates;
  final int libraryUpdates;

  const _NotificationData({
    required this.extensionUpdates,
    required this.libraryUpdates,
  });
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? child;
  final Widget? action;

  const _NotificationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 8), child!],
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final Color color;
  const _EmptyNotifications({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Broken.notification,
            size: 46,
            color: color.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 12),
          Text('Aucune nouvelle notification', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final Source source;
  const _SourceIcon({required this.source});

  @override
  Widget build(BuildContext context) {
    final url = source.iconUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Broken.box));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}
