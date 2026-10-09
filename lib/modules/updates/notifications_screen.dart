import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/services/fetch_sources_list.dart'
    show
        extensionUpdateLabel,
        fetchSourcesList,
        hasPendingExtensionUpdate,
        installExtensionUpdate;
import 'package:watchtower/services/layout_registry.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<_NotificationData> _future;
  final Set<int> _installing = {};
  bool _refreshingCatalog = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCatalog();
    });
  }

  Future<_NotificationData> _load({Object? sourceError}) async {
    List<Source> sources = const [];
    try {
      sources = await isar.sources.buildQuery<Source>().findAll();
      for (final source in sources) {
        source.hydrateExtendedMetadata();
      }
    } catch (error) {
      sourceError = error;
    }
    final savedExtensionUpdates =
        await ExtensionCatalogNotifications.pendingUpdates();
    final savedUpdateKeys = savedExtensionUpdates
        .map((notice) => notice.key)
        .toSet();
    final extensionUpdates = sources
        .where(
          (source) =>
              source.isAdded == true &&
              source.id != null &&
              (hasPendingExtensionUpdate(source) ||
                  savedUpdateKeys.contains(
                    '${source.itemType.index}:${source.id}',
                  )),
        )
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    final newExtensions = await ExtensionCatalogNotifications.pending();
    var libraryUpdates = 0;
    Object? libraryError;
    try {
      libraryUpdates = await isar.updates.count();
    } catch (error) {
      libraryError = error;
    }
    return _NotificationData(
      extensionUpdates: extensionUpdates,
      newExtensions: newExtensions,
      libraryUpdates: libraryUpdates,
      errorMessage: sourceError != null || libraryError != null
          ? 'Certaines notifications sont momentanément indisponibles.'
          : null,
    );
  }

  Future<void> _refreshCatalog() async {
    if (_refreshingCatalog == false && mounted) {
      setState(() => _refreshingCatalog = true);
    }

    Object? sourceError;
    try {
      final sources = await isar.sources.buildQuery<Source>().findAll();
      sourceError = await _refreshInstalledCatalog(sources);
    } catch (error) {
      sourceError = error;
    }

    if (!mounted) return;
    setState(() {
      _refreshingCatalog = false;
      _future = _load(sourceError: sourceError);
    });
  }

  /// Refreshes catalogue metadata only. Notifications must never install an
  /// extension as a side effect of being opened, even when automatic updates
  /// are enabled globally.
  Future<Object?> _refreshInstalledCatalog(List<Source> sources) async {
    final types = sources
        .where(
          (source) =>
              source.isAdded == true &&
              source.isLocal != true &&
              source.sourceCodeLanguage != SourceCodeLanguage.dart,
        )
        .map((source) => source.itemType)
        .toSet();
    if (types.isEmpty) return null;

    Object? firstError;
    await Future.wait(
      types.map((type) async {
        final repos = ref.read(extensionsRepoStateProvider(type));
        for (final repo in repos) {
          try {
            await fetchSourcesList(
              repo: repo,
              refresh: true,
              id: null,
              autoUpdateExtensions: false,
              itemType: type,
            );
          } catch (error) {
            firstError ??= error;
          }
        }
      }),
    );
    return firstError;
  }

  Future<void> _retry() async {
    setState(() {
      _future = _load();
      _refreshingCatalog = true;
    });
    await _refreshCatalog();
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
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _refreshingCatalog ? null : _refreshCatalog,
            icon: _refreshingCatalog
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Broken.refresh_2),
          ),
        ],
      ),
      body: FutureBuilder<_NotificationData>(
        future: _future,
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
          if (data.errorMessage != null &&
              data.extensionUpdates.isEmpty &&
              data.newExtensions.isEmpty &&
              data.libraryUpdates == 0) {
            return _NotificationError(
              message: data.errorMessage!,
              onRetry: _retry,
            );
          }
          if (data.extensionUpdates.isEmpty &&
              data.newExtensions.isEmpty &&
              data.libraryUpdates == 0) {
            if (_refreshingCatalog) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Vérification des mises à jour…',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }
            return _EmptyNotifications(color: cs.onSurfaceVariant);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            children: [
              if (data.errorMessage != null)
                _NotificationWarning(message: data.errorMessage!),
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
                            subtitle: Text(extensionUpdateLabel(source)),
                            trailing: FilledButton(
                              onPressed:
                                  source.id == null ||
                                      _installing.contains(source.id)
                                  ? null
                                  : () => _install(source),
                              child: _installing.contains(source.id)
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Installer'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
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
              if (data.newExtensions.isNotEmpty) ...[
                if (data.extensionUpdates.isNotEmpty)
                  const SizedBox(height: 12),
                _NotificationCard(
                  icon: Icons.new_releases_rounded,
                  color: cs.tertiary,
                  title:
                      '${data.newExtensions.length} nouvelle${data.newExtensions.length == 1 ? '' : 's'} extension${data.newExtensions.length == 1 ? '' : 's'} publiée${data.newExtensions.length == 1 ? '' : 's'}',
                  subtitle: 'Découvre les dernières extensions du catalogue.',
                  child: Column(
                    children: data.newExtensions
                        .map(
                          (notice) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _PublicationIcon(notice: notice),
                            title: Text(notice.name),
                            subtitle: Text(
                              [
                                _publicationTypeLabel(notice.itemType),
                                if (notice.lang.isNotEmpty)
                                  notice.lang.toUpperCase(),
                                if (notice.version.isNotEmpty)
                                  'v${notice.version}',
                              ].join(' · '),
                            ),
                            trailing: IconButton(
                              tooltip: 'Masquer cette notification',
                              onPressed: () => _dismissPublication(notice),
                              icon: const Icon(Icons.close_rounded, size: 19),
                            ),
                            onTap: () => context.push('/marketplace/search'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  action: TextButton.icon(
                    onPressed: () => context.push('/marketplace'),
                    icon: const Icon(Broken.arrow_right),
                    label: const Text('Parcourir le Marketplace'),
                  ),
                ),
              ],
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

  Future<void> _install(Source source) async {
    final id = source.id;
    if (id == null) return;
    setState(() => _installing.add(id));
    try {
      await installExtensionUpdate(source);
      final installed = await isar.sources.get(id);
      if (installed == null) {
        throw StateError(
          'La source installée est introuvable après téléchargement.',
        );
      }
      await LayoutRegistry.instance.load(installed);
      if (installed.uiLayout?.isNotEmpty == true &&
          !LayoutRegistry.instance.has(installed)) {
        throw StateError('Le layout UI n’a pas été installé.');
      }
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: id,
        itemType: installed.itemType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${source.name ?? 'Extension'} mise à jour')),
      );
      setState(() => _future = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Installation impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _installing.remove(id));
    }
  }

  Future<void> _dismissPublication(
    ExtensionPublicationNotice notice,
  ) async {
    await ExtensionCatalogNotifications.dismiss(notice);
    if (!mounted) return;
    setState(() => _future = _load());
  }
}

class _NotificationData {
  final List<Source> extensionUpdates;
  final List<ExtensionPublicationNotice> newExtensions;
  final int libraryUpdates;
  final String? errorMessage;

  const _NotificationData({
    required this.extensionUpdates,
    required this.newExtensions,
    required this.libraryUpdates,
    this.errorMessage,
  });
}

String _publicationTypeLabel(ItemType type) => switch (type) {
  ItemType.anime => 'Watch',
  ItemType.manga => 'Manga',
  ItemType.novel => 'Roman',
  ItemType.music => 'Musique',
  ItemType.game => 'Jeu',
  ItemType.plugin => 'Plugin',
};

class _NotificationWarning extends StatelessWidget {
  final String message;
  const _NotificationWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _NotificationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.notification, color: color, size: 46),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Broken.refresh_2),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
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

class _PublicationIcon extends StatelessWidget {
  final ExtensionPublicationNotice notice;

  const _PublicationIcon({required this.notice});

  @override
  Widget build(BuildContext context) {
    final url = notice.iconUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Broken.box));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}
