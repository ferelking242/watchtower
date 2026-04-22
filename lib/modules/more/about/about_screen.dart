import 'dart:io';

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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const String _zeusReleasesUrl =
    'https://github.com/ferelking242/zeusdl/releases';
const String _zeusCurrentVersion = 'nightly-20260409-3c50518';
const bool _zeusIsNightly = true;

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
                          onZeusCheckTap: () =>
                              ref.invalidate(zeusLatestReleaseProvider),
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
                              const Divider(height: 1, indent: 14),
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(14, 0, 14, 0),
                                dense: true,
                                leading: Icon(
                                  Icons.system_update_alt_rounded,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                title: Text(
                                  l10n.check_for_update,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  'App + ZeusDL engine',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: cs.onSurface.withOpacity(0.3),
                                  size: 18,
                                ),
                                onTap: () {
                                  ref.read(
                                    checkForUpdateProvider(
                                      context: context,
                                      manualUpdate: true,
                                    ),
                                  );
                                  ref.invalidate(zeusLatestReleaseProvider);
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
                                    'https://github.com/kodjodevf/watchtower',
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

                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Built with ♥ · ZeusDL fork',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.35),
                              letterSpacing: 0.4,
                            ),
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
          height: 200,
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
                  icon: Icons.link_outlined, label: 'Magnet / Direct'),
              _Aria2Feature(icon: Icons.code_outlined, label: 'Open source'),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Importer URL',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: cs.tertiary),
                onPressed: () => _promptAria2Download(context),
              ),
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
    final String statusLabel = _zeusIsNightly ? 'Nightly' : 'Stable';
    final Color statusColor = _zeusIsNightly ? Colors.orange : Colors.green;

    final isLoading = zeusAsync.isLoading;
    final ZeusRelease? latest = zeusAsync.when(
      data: (v) => v,
      loading: () => null,
      error: (_, __) => null,
    );
    final hasError = zeusAsync.hasError;

    String updateLabel = '';
    Color updateColor = cs.onSurface.withOpacity(0.4);
    bool hasUpdate = false;

    if (latest != null) {
      if (latest.version != _zeusCurrentVersion) {
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
                      'v$_zeusCurrentVersion · Download engine',
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

          // ── Custom binary path (Android only) ──────────────────────
          if (Platform.isAndroid) ...[
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: ZeusDlBinaryManager.instance.userOverrideDisplayPath(),
              builder: (context, snap) {
                final overridePath = snap.data ?? '';
                if (overridePath.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outline.withOpacity(0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 13,
                            color: cs.primary.withOpacity(0.7),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Custom binary path',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: cs.primary.withOpacity(0.8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              overridePath,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'monospace',
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: overridePath),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: cs.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Drop a custom zeusdl binary here to override the bundled version.',
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurface.withOpacity(0.4),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
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

Future<void> _startZeusDownload(
  BuildContext context,
  ZeusRelease release,
) async {
  if (release.assets.isEmpty) {
    botToast('Aucun binaire disponible dans cette release');
    return;
  }
  String? abi;
  if (Platform.isAndroid) {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      abi = info.supportedAbis.firstOrNull;
    } catch (_) {}
  }
  ZeusReleaseAsset? picked;
  if (abi != null) {
    for (final a in release.assets) {
      if (a.name.contains(abi)) {
        picked = a;
        break;
      }
    }
  }
  picked ??= release.assets.first;

  if (release.assets.length > 1 && context.mounted) {
    final selected = await showModalBottomSheet<ZeusReleaseAsset>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Choisir l\'ABI',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            for (final a in release.assets)
              ListTile(
                leading: const Icon(Icons.memory_rounded),
                title: Text(a.name, style: const TextStyle(fontSize: 13)),
                subtitle: a.size > 0
                    ? Text('${(a.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: const TextStyle(fontSize: 11))
                    : null,
                trailing: a == picked
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
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
      subtitle: picked!.name,
      url: picked.downloadUrl,
      installer: (url, onProgress) =>
          ZeusDlBinaryManager.instance.downloadFromUrl(url, onProgress: onProgress),
    ),
  );
}

Future<void> _promptAria2Download(BuildContext context) async {
  final ctrl = TextEditingController();
  final url = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Télécharger un binaire aria2c'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coller l\'URL d\'un binaire aria2c compatible Android :',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://…/aria2c',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('Télécharger'),
        ),
      ],
    ),
  );
  if (url == null || url.isEmpty || !context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BinaryDownloadDialog(
      title: 'Télécharger aria2c',
      subtitle: url.split('/').last,
      url: url,
      installer: (u, onProgress) =>
          Aria2BinaryManager.instance.downloadFromUrl(u, onProgress: onProgress),
    ),
  );
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
