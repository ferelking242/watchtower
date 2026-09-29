import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart';
import 'package:watchtower/modules/more/about/providers/download_file_screen.dart';
import 'package:watchtower/services/fetch_sources_list.dart' show compareVersions;
import 'package:watchtower/modules/more/about/providers/get_package_info.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/utils/constant.dart';

// Generic release/asset types used by binary download helpers (e.g. aria2).
class GithubRelease {
  final String version;
  final String htmlUrl;
  final String publishedAt;
  final bool isNightly;
  final List<GithubReleaseAsset> assets;
  const GithubRelease({
    required this.version,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isNightly,
    required this.assets,
  });
}

class GithubReleaseAsset {
  final String name;
  final String downloadUrl;
  final int size;
  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });
}

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  bool _isCheckingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final checkForUpdates = ref.watch(checkForAppUpdatesProvider);
    final enableLogs = ref.watch(logsStateProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ref.watch(getPackageInfoProvider).when(
            data: (data) => CustomScrollView(
              slivers: [
                // ── Hero header ─────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  floating: true,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.tertiary.withValues(alpha: 0.8),
                            cs.secondary.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: -30,
                            right: -30,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -20,
                            left: -20,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.04),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Watchtower',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'v${data.version} · Beta',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Body content ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── App updates ────────────────────────────────────
                        _SectionLabel(label: 'Updates', cs: cs),
                        const SizedBox(height: 8),
                        _GlassCard(
                          cs: cs,
                          isDark: isDark,
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(14, 0, 8, 0),
                                dense: true,
                                title: Text(
                                  l10n.check_for_app_updates,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: checkForUpdates,
                                onChanged: (value) {
                                  isar.writeTxnSync(() {
                                    final settings = isar.settings.getSync(kSettingsId);
                                    isar.settings.putSync(
                                      settings!
                                        ..checkForAppUpdates = value
                                        ..updatedAt = DateTime.now()
                                            .millisecondsSinceEpoch,
                                    );
                                  });
                                  ref.invalidate(checkForAppUpdatesProvider);
                                },
                              ),
                              const Divider(height: 1, indent: 14),
                              ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                                dense: true,
                                leading: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.system_update_alt_rounded,
                                      color: cs.primary, size: 16),
                                ),
                                title: Text(
                                  'Vérifier maintenant',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Rechercher la dernière version disponible',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                trailing: _isCheckingUpdate
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      )
                                    : Icon(Icons.chevron_right_rounded,
                                        size: 16, color: cs.onSurface.withValues(alpha: 0.3)),
                                onTap: _isCheckingUpdate
                                    ? null
                                    : () async {
                                        setState(() => _isCheckingUpdate = true);
                                        botToast(l10n.searching_for_updates);
                                        PackageInfo? info;
                                        try {
                                          info = await PackageInfo.fromPlatform();
                                          final result = await checkLatestRelease(forceRefresh: true);
                                          if (result.$1 == '0.0.0' || result.$1.isEmpty) {
                                            if (mounted) botToast('Vous avez la dernière version : ${info.version}');
                                          } else if (compareVersions(info.version, result.$1) < 0) {
                                            if (mounted) botToast(l10n.new_update_available);
                                            await Future.delayed(const Duration(seconds: 1));
                                            if (mounted) {
                                              Navigator.of(context, rootNavigator: true).push(
                                                MaterialPageRoute(
                                                  fullscreenDialog: true,
                                                  builder: (_) => DownloadFileScreen(updateAvailable: result),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (mounted) botToast('Vous avez la dernière version : ${info.version}');
                                          }
                                        } catch (_) {
                                          if (mounted) botToast(info != null ? 'Vous avez la dernière version : ${info.version}' : l10n.no_new_updates_available);
                                        } finally {
                                          if (mounted) setState(() => _isCheckingUpdate = false);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Logs ───────────────────────────────────────────
                        _SectionLabel(label: 'Developer', cs: cs),
                        const SizedBox(height: 8),
                        _GlassCard(
                          cs: cs,
                          isDark: isDark,
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(14, 0, 8, 0),
                                dense: true,
                                title: Text(
                                  l10n.logs_on,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                secondary: Icon(
                                  Icons.bug_report_outlined,
                                  size: 20,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                                value: enableLogs,
                                onChanged: (value) {
                                  isar.writeTxnSync(() {
                                    final settings = isar.settings.getSync(kSettingsId);
                                    isar.settings.putSync(
                                      settings!..enableLogs = value,
                                    );
                                  });
                                  ref.invalidate(logsStateProvider);
                                  if (value) {
                                    AppLogger.init();
                                  } else {
                                    AppLogger.dispose();
                                  }
                                },
                              ),
                              if (enableLogs) ...[
                                const Divider(height: 1, indent: 14),
                                ListTile(
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                  dense: true,
                                  leading: Icon(
                                    Icons.share_outlined,
                                    size: 20,
                                    color: cs.primary,
                                  ),
                                  title: Text(
                                    l10n.share_app_logs,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () async {
                                    final storage = StorageProvider();
                                    final directory = await storage
                                        .getDefaultDirectory();
                                    final file = File(
                                      path.join(directory!.path, 'logs.txt'),
                                    );
                                    if (await file.exists()) {
                                      if (!kIsWeb && Platform.isLinux) {
                                        await Clipboard.setData(
                                          ClipboardData(text: file.path),
                                        );
                                      }
                                      if (context.mounted) {
                                        final box = context
                                            .findRenderObject() as RenderBox?;
                                        SharePlus.instance.share(
                                          ShareParams(
                                            files: [XFile(file.path)],
                                            text: 'log.txt',
                                            sharePositionOrigin:
                                                box!.localToGlobal(
                                                      Offset.zero,
                                                    ) &
                                                box.size,
                                          ),
                                        );
                                      }
                                    } else {
                                      botToast(l10n.no_app_logs);
                                    }
                                  },
                                ),
                                const Divider(height: 1, indent: 14),
                                ListTile(
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                  dense: true,
                                  leading: Icon(
                                    Icons.article_outlined,
                                    size: 20,
                                    color: cs.primary,
                                  ),
                                  title: Text(
                                    'Lire les logs',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Affichage complet, coloré et filtrable',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: cs.onSurface.withValues(alpha: 0.3),
                                  ),
                                  onTap: () => context.push('/logViewer'),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Social links ───────────────────────────────────
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SocialButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.github,
                                  size: 18,
                                ),
                                label: 'GitHub',
                                cs: cs,
                                isDark: isDark,
                                onTap: () => _launchInBrowser(
                                  Uri.parse(
                                    'https://github.com/ferelking242/watchtower',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SocialButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.discord,
                                  size: 18,
                                ),
                                label: 'Discord',
                                cs: cs,
                                isDark: isDark,
                                onTap: () => _launchInBrowser(
                                  Uri.parse(
                                    'https://discord.com/invite/EjfBuYahsP',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _SocialButton(
                                icon: const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                ),
                                label: 'Email',
                                cs: cs,
                                isDark: isDark,
                                onTap: () => _launchInBrowser(
                                  Uri.parse('mailto:contact@watchtowerapp.dev'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            error: (error, stackTrace) => ErrorWidget(error),
            loading: () => const ProgressCenter(),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme cs;

  const _SectionLabel({required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glassmorphism card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final bool isDark;

  const _GlassCard({
    required this.child,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHigh.withValues(alpha: 0.7)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Binary engine store sheet
// ─────────────────────────────────────────────────────────────────────────────

void _showBinaryStoreSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _BinaryStoreSheet(),
  );
}

class _BinaryStoreSheet extends StatelessWidget {
  const _BinaryStoreSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'MOTEURS BINAIRES',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              'Choisissez les moteurs à installer selon vos besoins.',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 16),
            _StoreEngineRow(
              icon: Icons.account_tree_rounded,
              iconColor: cs.tertiary,
              name: 'Aria2',
              badge: 'Téléchargement',
              badgeColor: cs.tertiary,
              description: 'Moteur multi-connexion pour HTTP, FTP, BitTorrent et Magnet.',
              installed: false,
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                "D'autres moteurs seront disponibles prochainement.",
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreEngineRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String badge;
  final Color badgeColor;
  final String description;
  final bool installed;

  const _StoreEngineRow({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.description,
    required this.installed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.55)),
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: installed
                ? Colors.green.withValues(alpha: 0.12)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            installed ? 'Installé' : 'Disponible',
            style: TextStyle(
              fontSize: 11,
              color: installed ? Colors.green : cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Aria2Card extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isDark;

  const _Aria2Card({required this.colorScheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  cs.tertiaryContainer.withValues(alpha: 0.25),
                  cs.secondaryContainer.withValues(alpha: 0.15),
                ]
              : [
                  cs.tertiaryContainer.withValues(alpha: 0.45),
                  cs.secondaryContainer.withValues(alpha: 0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.tertiary.withValues(alpha: isDark ? 0.2 : 0.15),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.tertiary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.tertiary.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.account_tree_rounded,
                  size: 22,
                  color: cs.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Aria2',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Stable',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.blue,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Moteur de téléchargement multi-connexion haute performance',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Features
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: const [
              _Aria2Feature(icon: Icons.speed_outlined, label: 'Multi-connexions'),
              _Aria2Feature(
                  icon: Icons.pause_circle_outline, label: 'Reprise'),
              _Aria2Feature(
                  icon: Icons.link_outlined, label: 'HTTP / FTP'),
              _Aria2Feature(
                  icon: Icons.share_outlined, label: 'BitTorrent'),
              _Aria2Feature(
                  icon: Icons.cloud_download_outlined, label: 'Magnet'),
              _Aria2Feature(icon: Icons.code_outlined, label: 'Open source'),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Télécharger',
                    style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.tertiary.withValues(alpha: 0.18),
                  foregroundColor: cs.tertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _autoFetchAria2Download(context),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: cs.tertiary.withValues(alpha: 0.3),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                tooltip: 'Importer un binaire local',
                onPressed: () => _importAria2Binary(context),
                icon: Icon(Icons.file_upload_outlined, size: 16, color: cs.tertiary),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('aria2.github.io',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: cs.tertiary),
                onPressed: () => launchUrl(
                  Uri.parse('https://aria2.github.io'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Aria2Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Aria2Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.tertiary.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Social button
// ─────────────────────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceContainerHigh.withValues(alpha: 0.8)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outline.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: cs.onSurface.withValues(alpha: 0.75),
                  size: 18,
                ),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _launchInBrowser(Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw 'Could not launch $url';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Binary download helpers (Aria2)
// ─────────────────────────────────────────────────────────────────────────────

/// Detect the platform/arch identifier the binary asset name should contain
/// so we can prefilter releases. Returns a list of ABI tokens by priority.
Future<List<String>> _currentPlatformAbiTokens() async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      // Map android ABI to common asset name tokens used by binary releases.
      final mapped = <String>[];
      for (final abi in info.supportedAbis) {
        final lower = abi.toLowerCase();
        mapped.add(lower);
        if (lower == 'arm64-v8a') mapped.addAll(['arm64', 'aarch64', 'android-arm64']);
        if (lower == 'armeabi-v7a') mapped.addAll(['armv7', 'arm', 'android-arm']);
        if (lower == 'x86_64') mapped.addAll(['amd64', 'android-x86_64']);
        if (lower == 'x86') mapped.addAll(['i386', 'i686', 'android-x86']);
      }
      // Always exclude desktop tokens
      return mapped;
    } catch (_) {
      return ['arm64', 'arm64-v8a', 'aarch64'];
    }
  }
  if (!kIsWeb && Platform.isLinux) return ['linux', 'x86_64', 'amd64'];
  if (!kIsWeb && Platform.isWindows) return ['windows', 'win', 'x86_64', 'amd64'];
  if (!kIsWeb && Platform.isMacOS) return ['darwin', 'macos', 'arm64', 'x86_64'];
  return const [];
}

bool _isWrongPlatform(String name) {
  final n = name.toLowerCase();
  if (!kIsWeb && Platform.isAndroid) {
    // Reject obvious desktop builds when running on Android.
    return n.contains('linux') ||
        n.contains('windows') ||
        n.endsWith('.exe') ||
        n.contains('darwin') ||
        n.contains('macos');
  }
  return false;
}



Future<void> _autoFetchAria2Download(BuildContext context) async {
  try {
    final http = MClient.init(reqcopyWith: {'useDartHttpClient': true});
    final res = await http.get(
      Uri.parse('https://api.github.com/repos/aria2/aria2/releases/latest'),
    );
    if (res.statusCode != 200) {
      if (context.mounted) {
        botToast('Impossible de récupérer la release aria2 (${res.statusCode})');
      }
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString();
    final rawAssets = (data['assets'] as List?) ?? const [];
    final assets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((a) => GithubReleaseAsset(
              name: (a['name'] ?? '').toString(),
              downloadUrl: (a['browser_download_url'] ?? '').toString(),
              size: (a['size'] is int) ? a['size'] as int : 0,
            ))
        .where((a) => a.downloadUrl.isNotEmpty && !a.name.endsWith('.sha256'))
        .toList();

    if (assets.isEmpty) {
      if (context.mounted) botToast('Aucun binaire aria2 disponible');
      return;
    }

    final release = GithubRelease(
      version: tag,
      htmlUrl: (data['html_url'] ?? '').toString(),
      publishedAt: (data['published_at'] ?? '').toString(),
      isNightly: false,
      assets: assets,
    );

    if (!context.mounted) return;
    await _startAria2Download(context, release);
  } catch (e) {
    if (context.mounted) botToast('Erreur récupération aria2 : $e');
  }
}

Future<void> _startAria2Download(
  BuildContext context,
  GithubRelease release,
) async {
  final abiTokens = await _currentPlatformAbiTokens();
  List<GithubReleaseAsset> compatible = release.assets.where((a) {
    if (_isWrongPlatform(a.name)) return false;
    if (abiTokens.isEmpty) return true;
    final n = a.name.toLowerCase();
    return abiTokens.any((tok) => n.contains(tok));
  }).toList();

  if (compatible.isEmpty) compatible = release.assets;

  GithubReleaseAsset picked = compatible.first;

  if (release.assets.length > 1 && context.mounted) {
    final selected = await showModalBottomSheet<GithubReleaseAsset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => _AssetPickerSheet(
        compatible: compatible,
        allAssets: release.assets,
        initial: picked,
      ),
    );
    if (selected != null) picked = selected;
  }

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BinaryDownloadDialog(
      title: 'Télécharger aria2c',
      subtitle: picked.name,
      url: picked.downloadUrl,
      installer: (u, onProgress) =>
          Aria2BinaryManager.instance.downloadFromUrl(u, onProgress: onProgress),
    ),
  );
}

Future<void> _importAria2Binary(BuildContext context) async {
  try {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choisir un binaire aria2c',
    );
    if (result == null || result.files.isEmpty) return;
    final source = result.files.single.path;
    if (source == null) {
      botToast('Fichier inaccessible');
      return;
    }
    final userOverride = await Aria2BinaryManager.instance.userOverrideDisplayPath();
    final dest = File(userOverride);
    await dest.parent.create(recursive: true);
    if (await dest.exists()) await dest.delete();
    await File(source).copy(userOverride);
    if (!kIsWeb && (Platform.isAndroid || Platform.isLinux || Platform.isMacOS)) {
      try {
        await Process.run('chmod', ['+x', userOverride]);
      } catch (_) {}
    }
    try {
      await Aria2BinaryManager.instance.resolveExecutable();
    } catch (_) {}
    botToast('Binaire aria2c importé : ${source.split('/').last}');
  } catch (e) {
    botToast('Import échoué : $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Asset picker bottom sheet (shared by binary download helpers)
// ─────────────────────────────────────────────────────────────────────────────

class _AssetPickerSheet extends StatefulWidget {
  final List<GithubReleaseAsset> compatible;
  final List<GithubReleaseAsset> allAssets;
  final GithubReleaseAsset initial;

  const _AssetPickerSheet({
    required this.compatible,
    required this.allAssets,
    required this.initial,
  });

  @override
  State<_AssetPickerSheet> createState() => _AssetPickerSheetState();
}

class _AssetPickerSheetState extends State<_AssetPickerSheet> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final list = _showAll ? widget.allAssets : widget.compatible;
    final hasMore = widget.allAssets.length > widget.compatible.length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choisir le binaire',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (hasMore)
                    TextButton.icon(
                      icon: Icon(
                        _showAll
                            ? Icons.filter_list_off_rounded
                            : Icons.public_rounded,
                        size: 15,
                      ),
                      label: Text(
                        _showAll ? 'Compatible' : 'Toutes plateformes',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => setState(() => _showAll = !_showAll),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final a = list[i];
                  final isDefault = a == widget.initial;
                  return ListTile(
                    leading: const Icon(Icons.memory_rounded),
                    title: Text(a.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: a.size > 0
                        ? Text(
                            '${(a.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: const TextStyle(fontSize: 11))
                        : null,
                    trailing: isDefault
                        ? const Icon(Icons.check_circle,
                            color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BinaryDownloadDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String url;
  final Future<bool> Function(
    String url,
    void Function(int received, int total) onProgress,
  ) installer;

  const _BinaryDownloadDialog({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.installer,
  });

  @override
  State<_BinaryDownloadDialog> createState() => _BinaryDownloadDialogState();
}

class _BinaryDownloadDialogState extends State<_BinaryDownloadDialog> {
  int _received = 0;
  int _total = 0;
  bool _running = false;
  bool _done = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _running = true);
    final ok = await widget.installer(widget.url, (r, t) {
      if (mounted) setState(() { _received = r; _total = t; });
    });
    if (mounted) {
      setState(() {
        _running = false;
        _done = true;
        _success = ok;
      });
    }
  }

  String _mb(num b) => (b / (1024 * 1024)).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final pct = _total > 0 ? _received / _total : null;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          if (!_done) ...[
            LinearProgressIndicator(value: pct),
            const SizedBox(height: 8),
            Text(
              _total > 0
                  ? '${_mb(_received)} / ${_mb(_total)} MB'
                  : '${_mb(_received)} MB',
              style: const TextStyle(fontSize: 11),
            ),
          ] else
            Row(
              children: [
                Icon(
                  _success ? Icons.check_circle : Icons.error_outline,
                  color: _success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_success
                    ? 'Téléchargement terminé'
                    : 'Échec du téléchargement'),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _running
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(_done ? 'Fermer' : 'Annuler'),
        ),
      ],
    );
  }
}
