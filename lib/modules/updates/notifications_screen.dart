import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/services/fetch_sources_list.dart'
    show
        extensionUpdateLabel,
        hasPendingExtensionUpdate,
        installExtensionUpdate;
import 'package:watchtower/services/layout_registry.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<_NotificationData> _future;
  final Set<int> _installing = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NotificationData> _load() async {
    List<Source> sources = const [];
    Object? sourceError;
    try {
      sources = await isar.sources.buildQuery<Source>().findAll();
    } catch (error) {
      sourceError = error;
    }
    final extensionUpdates =
        sources
            .where(
              (source) =>
                  source.isAdded == true &&
                  hasPendingExtensionUpdate(source),
            )
            .toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    var libraryUpdates = 0;
    Object? libraryError;
    try {
      libraryUpdates = await isar.updates.count();
    } catch (error) {
      libraryError = error;
    }
    return _NotificationData(
      extensionUpdates: extensionUpdates,
      libraryUpdates: libraryUpdates,
      errorMessage: sourceError != null || libraryError != null
          ? 'Certaines notifications sont momentanément indisponibles.'
          : null,
    );
  }

  void _retry() {
    setState(() => _future = _load());
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
              data.libraryUpdates == 0) {
            return _NotificationError(
              message: data.errorMessage!,
              onRetry: _retry,
            );
          }
          if (data.extensionUpdates.isEmpty && data.libraryUpdates == 0) {
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
                            subtitle: Text(
                               extensionUpdateLabel(source),
                            ),
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

  Future<void> _install(Source source) async {
    final id = source.id;
    if (id == null) return;
    setState(() => _installing.add(id));
    try {
      await installExtensionUpdate(source);
      final installed = await isar.sources.get(id);
      if (installed == null) {
        throw StateError('La source installée est introuvable après téléchargement.');
      }
      await LayoutRegistry.instance.load(installed);
      if (installed.uiLayout?.isNotEmpty == true &&
          !LayoutRegistry.instance.has(installed)) {
        throw StateError('Le layout UI n’a pas été installé.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${source.name ?? 'Extension'} installée')),
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
}

class _NotificationData {
  final List<Source> extensionUpdates;
  final int libraryUpdates;
  final String? errorMessage;

  const _NotificationData({
    required this.extensionUpdates,
    required this.libraryUpdates,
    this.errorMessage,
  });
}

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
