import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/layout_component_registry.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/eval/lib.dart' show withExtensionService;
import 'package:watchtower/eval/model/extension_account.dart';
import 'package:watchtower/modules/browse/extension/providers/extension_preferences_providers.dart';
import 'package:watchtower/modules/browse/extension/widgets/source_preference_widget.dart';
import 'package:watchtower/modules/dev/component_gallery_screen.dart';
import 'package:watchtower/modules/manga/home/manga_home_screen.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/get_source_preference.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/http/extension_session_manager.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/services/layout_registry.dart';
import 'package:watchtower/services/fetch_sources_list.dart'
    show compareVersions;

enum _SiteSessionStatus {
  checking,
  loggingIn,
  sessionSaved,
  authenticated,
  notConnected,
  unavailable,
}

class ExtensionDetail extends ConsumerStatefulWidget {
  final Source source;
  const ExtensionDetail({super.key, required this.source});

  @override
  ConsumerState<ExtensionDetail> createState() => _ExtensionDetailState();
}

class _ExtensionDetailState extends ConsumerState<ExtensionDetail> {
  late Source source = isar.sources.getSync(widget.source.id!)!;
  late List<SourcePreference>? sourcePreference = _loadPreferences();
  late final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;
  _SiteSessionStatus _siteSessionStatus = _SiteSessionStatus.checking;
  ExtensionAccount? _accountInfo;
  List<Map<String, dynamic>> _extensionFavorites = [];
  Map<String, dynamic>? _extensionSubscription;
  bool? _extensionPremiumStatus;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed = _scrollController.hasClients &&
          _scrollController.offset > (270 - kToolbarHeight - 16);
      if (collapsed != _isCollapsed) setState(() => _isCollapsed = collapsed);
    });
    unawaited(_refreshSiteSessionStatus());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<SourcePreference>? _loadPreferences() {
    try {
      return getSourcePreference(source: source)
          .map((e) => getSourcePreferenceEntry(e.key!, source.id!))
          .toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  void _copyBaseUrl() {
    final url = source.baseUrl ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    botToast('URL copiée !');
  }

  Future<void> _editSearchResultCard() async {
    final component = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ComponentGalleryScreen(
          selectionMode: true,
          selectionContext: LayoutComponentContext.search,
          onSelectLayoutComponent: (id) => Navigator.of(context).pop(id),
        ),
      ),
    );
    if (component == null || !mounted) return;

    try {
      var content = await LayoutRegistry.instance.readJson(source);
      if (content == null) {
        await LayoutDownloader.instance.download(source);
        content = await LayoutRegistry.instance.readJson(source);
      }
      if (content == null) {
        botToast('Aucun layout local disponible pour cette extension.');
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('La racine du layout doit être un objet.');
      }
      final layout = Map<String, dynamic>.from(decoded);
      final browse = _copyLayoutObject(layout['browse'], 'browse');
      final search = _copyLayoutObject(browse['search'], 'browse.search');
      final results = _copyLayoutObject(
        search['results'],
        'browse.search.results',
      );
      results['cardComponent'] = component;
      search['results'] = results;
      browse['search'] = search;
      layout['browse'] = browse;

      final saved = await LayoutRegistry.instance.save(
        source,
        const JsonEncoder.withIndent('  ').convert(layout),
      );
      if (!mounted) return;
      if (!saved) {
        botToast('Impossible d’enregistrer la carte de recherche.');
        return;
      }
      setState(() {});
      botToast('Carte de recherche enregistrée.');
    } catch (error) {
      if (mounted) botToast('Layout de recherche invalide : $error');
    }
  }

  Future<void> _signInToSite() async {
    final url = Uri.tryParse(source.loginUrl ?? source.baseUrl ?? '');
    if (url == null || !url.hasAuthority ||
        (url.scheme != 'https' && url.scheme != 'http')) {
      botToast('URL du site invalide.');
      return;
    }
    setState(() => _siteSessionStatus = _SiteSessionStatus.loggingIn);
    try {
      await context.push('/mangawebview', extra: {
        'url': url.toString(),
        'sourceId': source.id.toString(),
        'title': '${source.name ?? 'Extension'} — connexion',
      });
    } finally {
      if (mounted) await _refreshSiteSessionStatus();
    }
  }

  Future<void> _signOutFromSite() async {
    final id = source.id;
    final baseUrl = source.baseUrl ?? '';
    if (id == null || baseUrl.isEmpty) return;
    await MClient.logoutExtension(id, baseUrl);
    if (!mounted) return;
    setState(() {
      _accountInfo = null;
      _extensionFavorites = [];
      _extensionSubscription = null;
      _extensionPremiumStatus = null;
      _siteSessionStatus = _SiteSessionStatus.notConnected;
    });
    botToast('Session effacée pour cette extension.');
  }

  Future<void> _refreshSiteSessionStatus() async {
    if (!mounted) return;
    if (_siteSessionStatus != _SiteSessionStatus.checking) {
      setState(() => _siteSessionStatus = _SiteSessionStatus.checking);
    }
    try {
      await ExtensionSessionManager.load(source.id);
      final hasSessionData = ExtensionSessionManager.hasSessionDataForUrl(
        source.id,
        source.baseUrl ?? '',
      );
      ExtensionAccount? account;
      if (hasSessionData && source.accountAvailable) {
        try {
          account = await withExtensionService(
            source,
            (service) => service.getAccount(),
          );
        } catch (_) {
          // A profile endpoint can be temporarily unavailable while the
          // browser session itself remains valid.
        }
      }
      var favorites = <Map<String, dynamic>>[];
      Map<String, dynamic>? subscription;
      bool? premiumStatus;
      if (source.favoritesAvailable ||
          source.subscriptionAvailable ||
          source.premiumAvailable) {
        try {
          await withExtensionService(source, (service) async {
            if (source.favoritesAvailable) {
              try {
                favorites = await service.getFavorites();
              } catch (_) {}
            }
            if (source.subscriptionAvailable) {
              try {
                subscription = await service.getSubscription();
              } catch (_) {}
            }
            if (source.premiumAvailable) {
              try {
                premiumStatus = await service.getPremiumStatus();
              } catch (_) {}
            }
          });
        } catch (_) {
          // One unavailable capability must not hide the other account data.
        }
      }
      if (mounted) {
        setState(() {
          _accountInfo = account;
          _extensionFavorites = favorites;
          _extensionSubscription = subscription;
          _extensionPremiumStatus = premiumStatus;
          _siteSessionStatus = account != null
              ? _SiteSessionStatus.authenticated
              : hasSessionData
              ? _SiteSessionStatus.sessionSaved
              : _SiteSessionStatus.notConnected;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accountInfo = null;
          _extensionFavorites = [];
          _extensionSubscription = null;
          _extensionPremiumStatus = null;
          _siteSessionStatus = _SiteSessionStatus.unavailable;
        });
      }
    }
  }

  Widget _buildSiteSessionStatus(ColorScheme colors) {
    late final String label;
    late final IconData? icon;
    late final Color color;
    switch (_siteSessionStatus) {
      case _SiteSessionStatus.checking:
        label = 'Vérification de la connexion…';
        icon = null;
        color = colors.onSurfaceVariant;
        break;
      case _SiteSessionStatus.loggingIn:
        label = 'Connexion en cours…';
        icon = Icons.check_circle_rounded;
        color = colors.onSurfaceVariant;
        break;
      case _SiteSessionStatus.sessionSaved:
        label = 'Session du site enregistrée';
        icon = Icons.cookie_outlined;
        color = colors.primary;
        break;
      case _SiteSessionStatus.authenticated:
        final identity =
            _accountInfo?.displayName ?? _accountInfo?.username ?? 'Compte';
        label = 'Connecté : $identity';
        icon = Icons.verified_user_rounded;
        color = colors.primary;
        break;
      case _SiteSessionStatus.notConnected:
        label = 'Non connecté';
        icon = Icons.info_outline_rounded;
        color = colors.onSurfaceVariant;
        break;
      case _SiteSessionStatus.unavailable:
        label = 'État de connexion indisponible';
        icon = Icons.warning_amber_rounded;
        color = colors.error;
        break;
    }
    return Row(
      children: [
        if (_siteSessionStatus == _SiteSessionStatus.checking ||
            _siteSessionStatus == _SiteSessionStatus.loggingIn)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
        else
          Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          tooltip: 'Vérifier la connexion',
          visualDensity: VisualDensity.compact,
          onPressed: _siteSessionStatus == _SiteSessionStatus.checking ||
                  _siteSessionStatus == _SiteSessionStatus.loggingIn
              ? null
              : _refreshSiteSessionStatus,
          icon: const Icon(Icons.refresh_rounded, size: 19),
        ),
      ],
    );
  }

  Widget _buildAccountProfile(ColorScheme colors) {
    final account = _accountInfo;
    if (account == null) return const SizedBox.shrink();
    final avatarUri = Uri.tryParse(account.avatarUrl ?? '');
    final hasAvatar = avatarUri != null &&
        (avatarUri.scheme == 'https' || avatarUri.scheme == 'http');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.primaryContainer,
            child: hasAvatar
                ? ClipOval(
                    child: Image.network(
                      avatarUri.toString(),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.person_rounded, color: colors.primary),
                    ),
                  )
                : Icon(Icons.person_rounded, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName ?? account.username ?? 'Compte connecté',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (account.email != null)
                  Text(
                    account.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCapabilities(ColorScheme colors) {
    final sections = <Widget>[];
    if (source.favoritesAvailable) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const _SectionHeader(
              label: 'Favoris',
              icon: Icons.favorite_outline_rounded,
            ),
            if (_extensionFavorites.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Aucun favori disponible.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else
              ..._extensionFavorites.take(5).map((favorite) {
                final title = favorite['name']?.toString() ??
                    favorite['title']?.toString() ??
                    'Sans titre';
                final imageUrl = favorite['imageUrl']?.toString() ??
                    favorite['coverUrl']?.toString();
                final imageUri = Uri.tryParse(imageUrl ?? '');
                final validImage = imageUri != null &&
                    (imageUri.scheme == 'https' || imageUri.scheme == 'http');
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: validImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            imageUri.toString(),
                            width: 36,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.book_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.book_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            if (_extensionFavorites.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  '+${_extensionFavorites.length - 5} autres favoris',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      );
    }
    if (source.subscriptionAvailable) {
      final subscription = _extensionSubscription;
      final plan = subscription?['plan']?.toString() ??
          subscription?['name']?.toString() ??
          'Abonnement';
      final status = subscription?['status']?.toString();
      final expiresAt = subscription?['expiresAt']?.toString() ??
          subscription?['expires_at']?.toString();
      sections.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(Icons.card_membership_rounded, color: colors.primary),
          title: Text(plan),
          subtitle: Text(
            [
              if (status != null && status.isNotEmpty) status,
              if (expiresAt != null && expiresAt.isNotEmpty)
                'Expire le $expiresAt',
              if (subscription == null) 'Détails indisponibles',
            ].join(' · '),
          ),
        ),
      );
    }
    if (source.premiumAvailable) {
      final status = _extensionPremiumStatus;
      sections.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
            status == true ? Icons.workspace_premium : Icons.stars_outlined,
            color: status == true ? colors.tertiary : colors.onSurfaceVariant,
          ),
          title: const Text('Statut Premium'),
          subtitle: Text(
            status == null
                ? 'Statut indisponible'
                : status
                ? 'Actif'
                : 'Inactif',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Future<void> _editBaseUrl() async {
    final controller = TextEditingController(text: source.baseUrl ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, size: 20),
            SizedBox(width: 8),
            Text('Modifier l\'URL de base'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL de base',
            hintText: 'https://exemple.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link_rounded),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final val = controller.text.trim();
              Navigator.pop(ctx, val.isEmpty ? null : val);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    isar.writeTxnSync(() {
      isar.sources.putSync(widget.source..baseUrl = result);
    });
    setState(() {
      source = isar.sources.getSync(widget.source.id!)!;
    });
    botToast('URL mise à jour !');
  }

  Future<void> _importCookies() async {
    final controller = TextEditingController();
    final url = source.baseUrl ?? '';
    if (url.isEmpty) {
      botToast('URL de base non définie.');
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cookie_rounded, size: 20),
            SizedBox(width: 8),
            Text('Importer des cookies'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collez les cookies au format: clé=valeur; clé2=valeur2',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Cookies',
                hintText: 'session=abc123; token=xyz789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cookie_outlined),
              ),
              maxLines: 4,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final val = controller.text.trim();
              Navigator.pop(ctx, val.isEmpty ? null : val);
            },
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    try {
      await MClient.setCookie(url, '', null, cookie: result);
      botToast('Cookies importés !');
    } catch (e) {
      botToast('Erreur lors de l\'import des cookies.');
    }
  }

  Future<void> _exportCookies() async {
    final url = source.baseUrl ?? '';
    if (url.isEmpty) {
      botToast('URL de base non définie.');
      return;
    }
    final cookies = MClient.getCookiesPref(url);
    if (cookies.isEmpty) {
      botToast('Aucun cookie disponible pour cette extension.');
      return;
    }
    final cookieStr = cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.upload_rounded, size: 20),
            SizedBox(width: 8),
            Text('Exporter les cookies'),
          ],
        ),
        content: SelectableText(
          cookieStr,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cookieStr));
              Navigator.pop(ctx);
              botToast('Cookies copiés !');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _viewCurrentCookies() async {
    final url = source.baseUrl ?? '';
    if (url.isEmpty) {
      botToast('URL de base non définie.');
      return;
    }
    final cookies = MClient.getCookiesPref(url);
    if (cookies.isEmpty) {
      botToast('Aucun cookie stocké pour cette extension.');
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cookie_rounded, size: 20),
              SizedBox(width: 8),
              Text('Cookies stockés'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: cookies.entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeUserAgent() async {
    final current = source.customUserAgent ?? '';
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.device_hub_rounded, size: 20),
            SizedBox(width: 8),
            Text('User-Agent'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laissez vide pour utiliser le User-Agent par défaut.',
              style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'User-Agent',
                hintText: 'Mozilla/5.0 ...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.device_hub_rounded),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Réinitialiser'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    isar.writeTxnSync(() {
      isar.sources.putSync(source..customUserAgent = result.isEmpty ? null : result);
    });
    setState(() { source = isar.sources.getSync(source.id!)!; });
    botToast(result.isEmpty ? 'User-Agent réinitialisé.' : 'User-Agent mis à jour !');
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Effacer les données ?'),
        content: const Text(
          'Cela supprimera toutes les préférences, cookies et données '
          'associés à cette extension.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final url = source.baseUrl ?? '';
    if (url.isNotEmpty) await MClient.deleteAllCookies(url);
    final prefsIds = isar.sourcePreferences
        .filter()
        .sourceIdEqualTo(source.id!)
        .findAllSync()
        .map((e) => e.id!)
        .toList();
    final prefsStrIds = isar.sourcePreferenceStringValues
        .filter()
        .sourceIdEqualTo(source.id!)
        .findAllSync()
        .map((e) => e.id)
        .toList();
    isar.writeTxnSync(() {
      isar.sourcePreferences.deleteAllSync(prefsIds);
      isar.sourcePreferenceStringValues.deleteAllSync(prefsStrIds);
    });
    setState(() { sourcePreference = _loadPreferences(); });
    botToast('Données effacées !');
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vider le cache ?'),
        content: const Text(
          'Cela rechargera les préférences de l\u2019extension depuis la base locale '
          'et tentera d\u2019invalider le cache HTTP de cette source. '
          'Les cookies ne sont pas affectés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // MClient ne fournit pas d'API de vidage du cache HTTP (géré en mémoire
    // par l'extension JS côté isolate). On recharge les préférences persistées,
    // ce qui force un redémarrage propre de la configuration côté app.
    if (mounted) {
      setState(() {
        sourcePreference = _loadPreferences();
      });
    }
    botToast('Préférences rechargées. Rouvrez la source pour actualiser le cache.');
  }

  Future<void> _viewHeaders() async {
    final rawHeaders = source.headers ?? '';
    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.http_rounded, size: 20),
              SizedBox(width: 8),
              Text('En-têtes HTTP'),
            ],
          ),
          content: rawHeaders.isEmpty
              ? const Text('Aucun en-tête défini.')
              : SelectableText(
                  rawHeaders,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
            if (rawHeaders.isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rawHeaders));
                  Navigator.pop(ctx);
                  botToast('En-têtes copiés !');
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmUninstall() async {
    final l10n = l10nLocalizations(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(ctx).colorScheme.error, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(source.name!)),
          ],
        ),
        content: Text(l10n.uninstall_extension(source.name!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.uninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final current = await isar.sources.get(source.id!);
    if (current == null) {
      if (mounted) {
        botToast('Cette extension n’existe plus dans le stockage local.');
        Navigator.pop(context);
      }
      return;
    }
    final sourcePrefsIds = await isar.sourcePreferences
        .filter()
        .sourceIdEqualTo(current.id!)
        .findAll()
        .then((items) => items.map((e) => e.id!).toList());
    final sourcePrefsStringIds = await isar.sourcePreferenceStringValues
        .filter()
        .sourceIdEqualTo(current.id!)
        .findAll()
        .then((items) => items.map((e) => e.id).toList());
    try {
      await isar.writeTxn(() async {
        if (current.isObsolete ?? false) {
          await isar.sources.delete(current.id!);
          ref
              .read(synchingProvider(syncId: 1).notifier)
              .addChangedPart(
                ActionType.removeExtension,
                current.id,
                '{}',
                false,
              );
        } else {
          await isar.sources.put(
            current
              ..sourceCode = ''
              ..isAdded = false
              ..isPinned = false
              ..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
        }
        await isar.sourcePreferences.deleteAll(sourcePrefsIds);
        await isar.sourcePreferenceStringValues.deleteAll(sourcePrefsStringIds);
      });
      await LayoutDownloader.instance.remove(current);
      if (mounted) {
        botToast('Extension désinstallée.');
        Navigator.pop(context, current);
      }
    } catch (error) {
      if (mounted) {
        botToast('Erreur lors de la désinstallation : $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final langCode = source.lang ?? 'unknown';
    final langName = completeLanguageName(langCode);
    final baseUrl = source.baseUrl ?? '';
    final isObsolete = source.isObsolete ?? false;
    final isAdded = source.isAdded ?? false;
    final hasCodeUpdate =
        source.version != null &&
        source.versionLast != null &&
        compareVersions(source.version!, source.versionLast!) < 0;

    String? typeBadge;
    IconData typeIcon = Icons.extension_rounded;
    if (source.itemType == ItemType.anime) {
      typeBadge = 'Watch';
      typeIcon = Icons.play_circle_outline_rounded;
    } else if (source.itemType == ItemType.manga) {
      typeBadge = 'Manga';
      typeIcon = Icons.menu_book_outlined;
    } else if (source.itemType == ItemType.novel) {
      typeBadge = 'Novel';
      typeIcon = Icons.auto_stories_outlined;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Hero app bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: cs.surface,
            centerTitle: true,
            title: _isCollapsed
                ? Text(
                    source.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            leading: BackButton(onPressed: () => Navigator.pop(context, source)),
            actions: [
              // Tap = WebView, long press = navigateur externe
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final url = baseUrl.isNotEmpty
                      ? baseUrl
                      : (source.repo?.website ?? '');
                  if (url.isNotEmpty) {
                    context.push('/mangawebview', extra: {
                      'url': url,
                      'sourceId': source.id.toString(),
                      'title': source.name ?? '',
                    });
                  }
                },
                onLongPress: () {
                  final url = baseUrl.isNotEmpty
                      ? baseUrl
                      : (source.repo?.website ?? '');
                  if (url.isNotEmpty) {
                    _launchInBrowser(Uri.parse(url));
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Icon(Broken.global, color: cs.onSurface),
                ),
              ),
              // Supprimer l'extension
              IconButton(
                tooltip: 'Désinstaller l\'extension',
                icon: Icon(Broken.trash, color: cs.error),
                onPressed: _confirmUninstall,
              ),
              // Menu 3 points — actions avancées
              PopupMenuButton<String>(
                icon: Icon(Broken.more, color: cs.onSurface),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (value) async {
                  switch (value) {
                    case 'import_cookie':
                      await _importCookies();
                      if (mounted) await _refreshSiteSessionStatus();
                    case 'clear_cookies':
                      if (baseUrl.isNotEmpty) {
                        await MClient.deleteAllCookies(baseUrl);
                        if (mounted) await _refreshSiteSessionStatus();
                        botToast('Cookies supprimés !');
                      }
                    case 'view_cookies':
                      await _viewCurrentCookies();
                    case 'clear_cache':
                      await _clearCache();
                    case 'clear_data':
                      await _clearData();
                    case 'edit_url':
                      await _editBaseUrl();
                    case 'view_headers':
                      await _viewHeaders();
                    case 'user_agent':
                      await _changeUserAgent();
                  }
                },
                itemBuilder: (ctx) => [
                  _popItem('import_cookie', Icons.cookie_rounded,
                      'Importer cookie'),
                  _popItem('view_cookies', Icons.manage_search_rounded,
                      'Voir cookies'),
                  _popItem('clear_cookies', Icons.cookie_outlined,
                      'Effacer cookies'),
                  _popItem('clear_cache', Icons.cleaning_services_rounded,
                      'Effacer le cache'),
                  _popItem('clear_data', Icons.delete_sweep_rounded,
                      'Effacer les données'),
                  const PopupMenuDivider(),
                  _popItem('edit_url', Icons.link_rounded, 'Modifier l\'URL'),
                  _popItem('view_headers', Icons.http_rounded,
                      'Voir les en-têtes'),
                  _popItem('user_agent', Icons.device_hub_rounded,
                      'Modifier User-Agent'),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primaryContainer.withValues(alpha: isDark ? 0.4 : 0.25),
                      cs.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 52),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: source.iconUrl?.isNotEmpty == true
                                ? cachedNetworkImage(
                                    imageUrl: source.iconUrl!,
                                    fit: BoxFit.contain,
                                    width: 96,
                                    height: 96,
                                    errorWidget: Icon(typeIcon,
                                        size: 48, color: cs.primary),
                                    headers: {},
                                  )
                                : Icon(typeIcon, size: 48, color: cs.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            source.name ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        children: [
                          if (typeBadge != null)
                            _Chip(icon: typeIcon, label: typeBadge, color: cs.primary),
                          _Chip(
                            icon: Icons.translate_rounded,
                            label: langName,
                            color: cs.tertiary,
                          ),
                          _Chip(
                            icon: Icons.info_outline_rounded,
                            label: 'v${source.version ?? '?'}',
                            color: cs.secondary,
                          ),
                          if (isObsolete)
                            _Chip(
                              icon: Icons.warning_amber_rounded,
                              label: 'Obsolète',
                              color: cs.error,
                            ),
                          if (!isAdded)
                            _Chip(
                              icon: Icons.download_done_rounded,
                              label: 'Non installée',
                              color: cs.onSurfaceVariant,
                            ),
                          // B5: show manifest-declared metadata
                          if (source.requiresAccount == true)
                            _Chip(
                              icon: Icons.account_circle_rounded,
                              label: 'Compte requis',
                              color: const Color(0xFF5C6BC0),
                            ),
                          if (source.hasCloudflare == true)
                            _Chip(
                              icon: Icons.cloud_rounded,
                              label: 'Cloudflare',
                              color: const Color(0xFFFF9800),
                            ),
                          if (hasCodeUpdate)
                            _Chip(
                              icon: Icons.system_update_rounded,
                              label: 'v${source.versionLast}',
                              color: cs.error,
                            ),
                        ],
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Info card ───────────────────────────────────────────
                  _InfoCard(
                    children: [
                      // Editable base URL row
                      if (baseUrl.isNotEmpty)
                        _EditableInfoRow(
                          icon: Icons.link_rounded,
                          label: 'URL de base',
                          value: baseUrl,
                          monospace: true,
                          onEdit: _editBaseUrl,
                          onCopy: () {
                            Clipboard.setData(ClipboardData(text: baseUrl));
                            botToast('URL copiée !');
                          },
                        ),
                      if (source.repo?.name != null)
                        _InfoRow(
                          icon: Icons.source_rounded,
                          label: 'Dépôt',
                          value: source.repo!.name!,
                        ),
                      if (source.version != null)
                        _InfoRow(
                          icon: Icons.verified_rounded,
                          label: 'Version',
                          value: source.version!,
                        ),
                      if (hasCodeUpdate)
                        _InfoRow(
                          icon: Icons.system_update_rounded,
                          label: 'Disponible',
                          value: source.versionLast!,
                        ),
                      if (source.lang != null)
                        _InfoRow(
                          icon: Icons.language_rounded,
                          label: 'Langue',
                          value: langName,
                        ),
                    ],
                  ),

                  // ── Notes (B5) ─────────────────────────────────────────
                  if ((source.notes ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 15, color: cs.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                source.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Manifest metadata — B10 ────────────────────────────
                  Builder(builder: (ctx2) {
                    final qualities = source.videoQualities ?? [];
                    final subtype   = source.contentSubtype ?? [];
                    final pw        = source.paywall;
                    if (qualities.isEmpty && subtype.isEmpty && pw == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Paywall badge
                          if (pw != null && pw.isNotEmpty) ...[
                            _MetaBadge(
                              label: pw == 'free'
                                  ? 'Gratuit'
                                  : pw == 'freemium'
                                      ? 'Freemium'
                                      : 'Payant',
                              icon: pw == 'free'
                                  ? Icons.lock_open_rounded
                                  : pw == 'freemium'
                                      ? Icons.lock_clock_rounded
                                      : Icons.lock_rounded,
                              color: pw == 'free'
                                  ? const Color(0xFF4CAF50)
                                  : pw == 'freemium'
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFFF44336),
                            ),
                          ],
                          // Content subtypes
                          for (final s in subtype)
                            _MetaBadge(
                              label: s,
                              icon: Icons.label_rounded,
                              color: cs.secondary,
                            ),
                          // Video quality chips
                          for (final q in qualities)
                            _MetaBadge(
                              label: q,
                              icon: Icons.hd_rounded,
                              color: cs.tertiary,
                            ),
                        ],
                      ),
                    );
                  }),

                  if (source.loginAvailable ||
                      source.accountAvailable ||
                      source.favoritesAvailable ||
                      source.subscriptionAvailable ||
                      source.premiumAvailable) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      label: 'Compte et fonctionnalités',
                      icon: Icons.manage_accounts_outlined,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.loginAvailable
                                ? 'La connexion et les informations affichées sont propres à cette extension. '
                                    'Les cookies et le stockage du site restent isolés.'
                                : 'Les informations affichées sont fournies par les méthodes déclarées par cette extension.',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (source.loginAvailable || source.accountAvailable)
                            _buildSiteSessionStatus(cs),
                          _buildAccountProfile(cs),
                          _buildAccountCapabilities(cs),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (source.loginAvailable)
                                FilledButton.tonalIcon(
                                  onPressed: _siteSessionStatus ==
                                          _SiteSessionStatus.loggingIn
                                      ? null
                                      : _signInToSite,
                                  icon: const Icon(
                                    Icons.login_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Se connecter'),
                                ),
                              if (source.loginAvailable ||
                                  source.accountAvailable)
                                OutlinedButton.icon(
                                  onPressed: _siteSessionStatus ==
                                          _SiteSessionStatus.notConnected
                                      ? null
                                      : _signOutFromSite,
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Effacer la session'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Source preferences ──────────────────────────────────
                  if (sourcePreference != null && sourcePreference!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      label: 'Paramètres de l\'extension',
                      icon: Icons.tune_rounded,
                    ),
                    const SizedBox(height: 8),
                    SourcePreferenceWidget(
                      sourcePreference: sourcePreference!,
                      source: source,
                    ),
                  ],

                  if (source.providesHome) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      label: 'Disposition de l’accueil',
                      icon: Icons.dashboard_customize_outlined,
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MangaHomeScreen(
                                  source: source,
                                  isLayoutEditing: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dashboard_customize_outlined),
                          label: const Text('Éditer visuellement'),
                        ),
                      ],
                    ),
                  ],

                  if (source.providesHome) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      label: 'Résultats de recherche',
                      icon: Icons.search_rounded,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _editSearchResultCard,
                      icon: const Icon(Icons.style_outlined),
                      label: const Text('Choisir une carte de résultat'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _copyLayoutObject(Object? value, String path) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
  throw FormatException('$path doit être un objet JSON.');
}

PopupMenuItem<String> _popItem(String value, IconData icon, String label) =>
    PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ]),
    );

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

/// Compact metadata badge used for videoQualities, paywall, contentSubtype.
class _MetaBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _MetaBadge({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  const _EditableInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
    required this.onEdit,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: onCopy,
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: monospace ? 'monospace' : null,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.edit_rounded, size: 14, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

