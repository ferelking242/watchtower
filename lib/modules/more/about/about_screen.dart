import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/more/about/providers/check_for_update.dart';
import 'package:watchtower/modules/more/about/providers/check_zeus_update.dart';
import 'package:watchtower/modules/more/about/providers/get_package_info.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/modules/widgets/progress_center.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/download_manager/engines/aria2_binary_manager.dart';
import 'package:watchtower/services/download_manager/engines/zeus_dl_binary_manager.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _zeusReleasesUrl =
    'https://github.com/ferelking242/zeusdl/releases';
String? _zeusInstalledVersion;
bool _zeusInstalledIsNightly = false;

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nLocalizations(context)!;
    final checkForUpdates = ref.watch(checkForAppUpdatesProvider);
    final enableLogs = ref.watch(logsStateProvider);
    final zeusAsync = ref.watch(zeusLatestReleaseProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ref.watch(getPackageInfoProvider).when(
            data: (data) => CustomScrollView(
              slivers: [
                // ── Hero header ─────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary,
                            cs.tertiary.withOpacity(0.8),
                            cs.secondary.withOpacity(0.6),
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
                                color: Colors.white.withOpacity(0.06),
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
                                color: Colors.white.withOpacity(0.04),
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
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
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
                                    color: Colors.white.withOpacity(0.78),
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
                        // ── Binary engines (swipeable: Zeus / Aria2) ──────
                        _SectionLabel(label: 'Moteurs binaires', cs: cs),
                        const SizedBox(height: 8),
                        _BinaryEnginesSection(
                          zeusAsync: zeusAsync,
                          colorScheme: cs,
                          isDark: isDark,
                          onZeusCheckTap: () {
                            // User explicitly requested a fresh check —
                            // bypass the in-memory 5-minute cache.
                            invalidateZeusReleaseCache();
                            ref.invalidate(zeusLatestReleaseProvider);
                          },
                        ),

                        const SizedBox(height: 20),

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
                                    final settings = isar.settings.getSync(227);
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
                                  color: cs.onSurface.withOpacity(0.5),
                                ),
                                value: enableLogs,
                                onChanged: (value) {
                                  isar.writeTxnSync(() {
                                    final settings = isar.settings.getSync(227);
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
                                      if (Platform.isLinux) {
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
                                      color: cs.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: cs.onSurface.withOpacity(0.3),
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
                                icon: Icon(
                                  Icons.rocket_launch_outlined,
                                  size: 18,
                                  color: cs.onSurface.withOpacity(0.75),
                                ),
                                label: 'ZeusDL',
                                cs: cs,
                                isDark: isDark,
                                onTap: () =>
                                    _launchInBrowser(Uri.parse(_zeusReleasesUrl)),
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
            ? cs.surfaceContainerHigh.withOpacity(0.7)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outline.withOpacity(0.12),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
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
// Binary Engines Section (swipeable: ZeusDL + Aria2)
// ─────────────────────────────────────────────────────────────────────────────

class _BinaryEnginesSection extends StatefulWidget {
  final AsyncValue<ZeusRelease?> zeusAsync;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onZeusCheckTap;

  const _BinaryEnginesSection({
    required this.zeusAsync,
    required this.colorScheme,
    required this.isDark,
    required this.onZeusCheckTap,
  });

  @override
  State<_BinaryEnginesSection> createState() => _BinaryEnginesSectionState();
}

class _BinaryEnginesSectionState extends State<_BinaryEnginesSection> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Column(
      children: [
        // Swipe hint row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageDot(active: _currentPage == 0, cs: cs),
            const SizedBox(width: 6),
            _PageDot(active: _currentPage == 1, cs: cs),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 270,
          child: PageView(
            controller: _pageController,
            onPageChanged: (p) => setState(() => _currentPage = p),
            children: [
              _ZeusDLCard(
                zeusAsync: widget.zeusAsync,
                colorScheme: cs,
                isDark: widget.isDark,
                onCheckTap: widget.onZeusCheckTap,
              ),
              _Aria2Card(
                colorScheme: cs,
                isDark: widget.isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Balayez pour voir ${_currentPage == 0 ? 'Aria2 →' : '← ZeusDL'}',
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}

class _PageDot extends StatelessWidget {
  final bool active;
  final ColorScheme cs;
  const _PageDot({required this.active, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.primary.withOpacity(0.25),
        borderRadius: BorderRadius.circular(3),
      ),
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
                  cs.tertiaryContainer.withOpacity(0.25),
                  cs.secondaryContainer.withOpacity(0.15),
                ]
              : [
                  cs.tertiaryContainer.withOpacity(0.45),
                  cs.secondaryContainer.withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.tertiary.withOpacity(isDark ? 0.2 : 0.15),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.tertiary.withOpacity(0.08),
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
                  color: cs.tertiary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.tertiary.withOpacity(0.2),
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
                            color: Colors.blue.withOpacity(0.15),
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
                        color: cs.onSurface.withOpacity(0.55),
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
                  backgroundColor: cs.tertiary.withOpacity(0.18),
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
                    color: cs.tertiary.withOpacity(0.3),
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
        color: cs.tertiary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.tertiary.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ZeusDL Card
// ─────────────────────────────────────────────────────────────────────────────

class _ZeusDLCard extends StatelessWidget {
  final AsyncValue<ZeusRelease?> zeusAsync;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onCheckTap;

  const _ZeusDLCard({
    required this.zeusAsync,
    required this.colorScheme,
    required this.isDark,
    required this.onCheckTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final isLoading = zeusAsync.isLoading;
    final ZeusRelease? latest = zeusAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (_, __) => null,
    );
    final hasError = zeusAsync.hasError;
    final bool displayNightly = _zeusInstalledIsNightly;
    final String statusLabel = displayNightly ? 'Nightly' : 'Stable';
    final Color statusColor = displayNightly ? Colors.orange : Colors.green;

    String updateLabel = '';
    Color updateColor = cs.onSurface.withOpacity(0.4);
    bool hasUpdate = false;

    if (latest != null) {
      if (_zeusInstalledVersion == null) {
        updateLabel = 'Installed version unknown — tap Download to update';
        updateColor = cs.onSurface.withOpacity(0.4);
        hasUpdate = true;
      } else if (latest.version != _zeusInstalledVersion) {
        updateLabel = 'Update available — ${latest.version}';
        updateColor = Colors.orange;
        hasUpdate = true;
      } else {
        updateLabel = 'Up to date';
        updateColor = Colors.green;
      }
    } else if (hasError) {
      updateLabel = 'Check failed';
      updateColor = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  cs.primaryContainer.withOpacity(0.25),
                  cs.secondaryContainer.withOpacity(0.15),
                ]
              : [
                  cs.primaryContainer.withOpacity(0.45),
                  cs.secondaryContainer.withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withOpacity(isDark ? 0.2 : 0.15),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.2),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 22,
                  color: cs.primary,
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
                          'ZeusDL',
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
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _zeusInstalledVersion != null
                          ? 'v$_zeusInstalledVersion · Download engine'
                          : 'Download engine',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (latest != null || hasError) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  hasUpdate
                      ? Icons.upgrade_rounded
                      : (hasError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_rounded),
                  size: 13,
                  color: updateColor,
                ),
                const SizedBox(width: 5),
                Text(
                  updateLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: updateColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isLoading ? null : onCheckTap,
                  child: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Check for update',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: cs.outline.withOpacity(0.3),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                tooltip: 'Reset bundled binary',
                onPressed: () async {
                  await ZeusDlBinaryManager.instance.clearCache();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: cs.outline.withOpacity(0.3),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                tooltip: 'Importer un binaire local',
                onPressed: () => _importZeusDLBinary(context),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
              ),
              if (hasUpdate && latest != null) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  tooltip: 'Télécharger ce binaire',
                  onPressed: () => _startZeusDownload(context, latest),
                  icon: const Icon(Icons.download_rounded, size: 16),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: cs.outline.withOpacity(0.3),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  tooltip: 'Open release page',
                  onPressed: () => _launchInBrowser(
                    Uri.parse(
                      latest.htmlUrl.isNotEmpty
                          ? latest.htmlUrl
                          : _zeusReleasesUrl,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                ),
              ],
            ],
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
                ? cs.surfaceContainerHigh.withOpacity(0.8)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outline.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme(
                data: IconThemeData(
                  color: cs.onSurface.withOpacity(0.75),
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
                  color: cs.onSurface.withOpacity(0.55),
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
// Binary download helpers (ZeusDL + Aria2)
// ─────────────────────────────────────────────────────────────────────────────

/// Detect the platform/arch identifier the binary asset name should contain
/// so we can prefilter releases. Returns a list of ABI tokens by priority.
Future<List<String>> _currentPlatformAbiTokens() async {
  if (Platform.isAndroid) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      // Map android ABI to common asset name tokens used by zeusdl releases.
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
  if (Platform.isLinux) return ['linux', 'x86_64', 'amd64'];
  if (Platform.isWindows) return ['windows', 'win', 'x86_64', 'amd64'];
  if (Platform.isMacOS) return ['darwin', 'macos', 'arm64', 'x86_64'];
  return const [];
}

bool _isWrongPlatform(String name) {
  final n = name.toLowerCase();
  if (Platform.isAndroid) {
    // Reject obvious desktop builds when running on Android.
    return n.contains('linux') ||
        n.contains('windows') ||
        n.endsWith('.exe') ||
        n.contains('darwin') ||
        n.contains('macos');
  }
  return false;
}

Future<void> _startZeusDownload(
  BuildContext context,
  ZeusRelease release,
) async {
  // Filter out .sha256 checksum files upfront
  final allAssets = release.assets
      .where((a) => !a.name.endsWith('.sha256'))
      .toList();

  if (allAssets.isEmpty) {
    botToast('Aucun binaire disponible dans cette release');
    return;
  }

  // ── Filter to current platform/arch only ─────────────────────────────────
  final abiTokens = await _currentPlatformAbiTokens();
  List<ZeusReleaseAsset> compatible = allAssets.where((a) {
    if (_isWrongPlatform(a.name)) return false;
    if (abiTokens.isEmpty) return true;
    final n = a.name.toLowerCase();
    return abiTokens.any((tok) => n.contains(tok));
  }).toList();

  if (compatible.isEmpty) compatible = allAssets;

  ZeusReleaseAsset picked = compatible.first;

  if (allAssets.length > 1 && context.mounted) {
    final selected = await showModalBottomSheet<ZeusReleaseAsset>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetPickerSheet(
        compatible: compatible,
        allAssets: allAssets,
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
      title: 'Télécharger ZeusDL',
      subtitle: picked.name,
      url: picked.downloadUrl,
      installer: (url, onProgress) =>
          ZeusDlBinaryManager.instance.downloadFromUrl(url, onProgress: onProgress),
    ),
  );

  try {
    await ZeusDlBinaryManager.instance.resolveExecutable();
  } catch (_) {}

  _zeusInstalledVersion = release.version;
  _zeusInstalledIsNightly = release.isNightly;
}

/// Lets the user pick a local binary file and installs it as the user
/// override (Android external storage) so ZeusDL picks it up immediately.
Future<void> _importZeusDLBinary(BuildContext context) async {
  try {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choisir un binaire ZeusDL',
    );
    if (result == null || result.files.isEmpty) return;
    final source = result.files.single.path;
    if (source == null) {
      botToast('Fichier inaccessible');
      return;
    }
    final overridePath =
        await ZeusDlBinaryManager.instance.userOverrideDisplayPath();
    final dest = File(overridePath);
    await dest.parent.create(recursive: true);
    if (await dest.exists()) await dest.delete();
    await File(source).copy(overridePath);
    if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
      try {
        await Process.run('chmod', ['+x', overridePath]);
      } catch (_) {}
    }
    // Force re-resolve so install detection picks up the new file
    try {
      await ZeusDlBinaryManager.instance.resolveExecutable();
    } catch (_) {}
    botToast('Binaire importé : ${source.split('/').last}');
  } catch (e) {
    botToast('Import échoué : $e');
  }
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
        .map((a) => ZeusReleaseAsset(
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

    final release = ZeusRelease(
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
  ZeusRelease release,
) async {
  final abiTokens = await _currentPlatformAbiTokens();
  List<ZeusReleaseAsset> compatible = release.assets.where((a) {
    if (_isWrongPlatform(a.name)) return false;
    if (abiTokens.isEmpty) return true;
    final n = a.name.toLowerCase();
    return abiTokens.any((tok) => n.contains(tok));
  }).toList();

  if (compatible.isEmpty) compatible = release.assets;

  ZeusReleaseAsset picked = compatible.first;

  if (release.assets.length > 1 && context.mounted) {
    final selected = await showModalBottomSheet<ZeusReleaseAsset>(
      context: context,
      isScrollControlled: true,
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
    if (Platform.isAndroid || Platform.isLinux || Platform.isMacOS) {
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
// Asset picker bottom sheet (shared by ZeusDL + Aria2)
// ─────────────────────────────────────────────────────────────────────────────

class _AssetPickerSheet extends StatefulWidget {
  final List<ZeusReleaseAsset> compatible;
  final List<ZeusReleaseAsset> allAssets;
  final ZeusReleaseAsset initial;

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
