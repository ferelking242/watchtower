import 'dart:async';
import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watchtower/services/transfer/transfer_library.dart';
import 'package:watchtower/services/transfer/transfer_models.dart';
import 'package:watchtower/services/transfer/transfer_notifier.dart';
import 'package:watchtower/services/transfer/transfer_server.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bg         = Color(0xFF080B10);
const _surface    = Color(0xFF111520);
const _card       = Color(0xFF161B27);
const _cardBright = Color(0xFF1E2537);
const _border     = Color(0xFF252D3F);
const _teal       = Color(0xFF00E5A0);
const _tealDim    = Color(0xFF00C488);
const _tealGlow   = Color(0x2200E5A0);
const _red        = Color(0xFFFF4D4D);
const _redGlow    = Color(0x22FF4D4D);
const _amber      = Color(0xFFFFB347);
const _primary    = Colors.white;
const _secondary  = Color(0xFF8B95B0);
const _dim        = Color(0xFF3E4560);

// ── Screen ───────────────────────────────────────────────────────────────────

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen>
    with SingleTickerProviderStateMixin {

  List<LibraryEntry> _myEntries = [];
  bool _loadingLib = true;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadLib();
  }

  Future<void> _loadLib() async {
    final entries = await loadLibraryDownloads();
    if (!mounted) return;
    setState(() { _myEntries = entries; _loadingLib = false; });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  int get _myChapterCount =>
      _myEntries.fold(0, (s, e) => s + e.chapters.length);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider);
    final inRoom = state.mode == TransferMode.room;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: inRoom ? _RoomView(
          state: state,
          myEntries: _myEntries,
          pulseCtrl: _pulseCtrl,
        ) : _LobbyView(
          myChapterCount: _myChapterCount,
          loadingLib: _loadingLib,
          onJoin: () => ref.read(transferProvider.notifier).joinRoom(),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOBBY
// ═════════════════════════════════════════════════════════════════════════════

class _LobbyView extends StatelessWidget {
  final int myChapterCount;
  final bool loadingLib;
  final VoidCallback onJoin;

  const _LobbyView({
    required this.myChapterCount,
    required this.loadingLib,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Positioned.fill(
          child: CustomPaint(painter: _BlobPainter()),
        ),

        Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: _secondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Icon pulsing
            _WifiRingsIcon(),

            const SizedBox(height: 32),

            const Text(
              'Salle de partage',
              style: TextStyle(
                color: _primary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Partagez vos téléchargements avec d\'autres appareils sur le même réseau WiFi, sans internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 14, height: 1.5),
              ),
            ),

            const SizedBox(height: 36),

            // Library pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _tealGlow,
                border: Border.all(color: _teal.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.library_books_rounded,
                      color: _teal, size: 18),
                  const SizedBox(width: 10),
                  loadingLib
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: _teal))
                      : Text(
                          '$myChapterCount chapitre${myChapterCount > 1 ? 's' : ''} disponible${myChapterCount > 1 ? 's' : ''} à partager',
                          style: const TextStyle(
                              color: _teal,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Join button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_teal, _tealDim],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: _teal.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: onJoin,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_rounded, color: Colors.black, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'REJOINDRE LA SALLE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline_rounded, color: _dim, size: 13),
                SizedBox(width: 5),
                Text('LAN / Hotspot uniquement · aucun serveur externe',
                    style: TextStyle(color: _dim, fontSize: 11)),
              ],
            ),

            const Spacer(flex: 3),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ROOM
// ═════════════════════════════════════════════════════════════════════════════

class _RoomView extends ConsumerWidget {
  final TransferState state;
  final List<LibraryEntry> myEntries;
  final AnimationController pulseCtrl;

  const _RoomView({
    required this.state,
    required this.myEntries,
    required this.pulseCtrl,
  });

  int get _myChapterCount =>
      myEntries.fold(0, (s, e) => s + e.chapters.length);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessions = state.activeSessions;
    final doneSessions = state.sessions
        .where((s) =>
            s.status == TransferStatus.done ||
            s.status == TransferStatus.failed)
        .toList();

    return Column(
      children: [
        // ── Top bar
        _RoomTopBar(state: state, pulseCtrl: pulseCtrl),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // My device card
              _MyDeviceCard(
                state: state,
                chapterCount: _myChapterCount,
                mangaCount: myEntries.length,
              ),

              const SizedBox(height: 20),

              // Peers section
              _SectionHeader(
                label: 'Appareils dans la salle',
                count: state.peers.length,
              ),
              const SizedBox(height: 12),

              if (state.peers.isEmpty)
                _EmptyPeers(pulseCtrl: pulseCtrl)
              else
                ...state.peers.map((peer) {
                  final catalog = state.peerCatalogs[peer.fingerprint];
                  final loading =
                      state.catalogsLoading.contains(peer.fingerprint);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PeerCard(
                      peer: peer,
                      catalog: catalog,
                      loading: loading,
                      onBrowse: () => _showCatalog(context, ref, peer, catalog),
                      onRefresh: () =>
                          ref.read(transferProvider.notifier).refreshCatalog(peer),
                    ),
                  );
                }),

              // Active downloads
              if (activeSessions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeader(label: 'Téléchargements en cours'),
                const SizedBox(height: 12),
                ...activeSessions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionTile(session: s),
                    )),
              ],

              // Done sessions (recent)
              if (doneSessions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeader(label: 'Terminés'),
                const SizedBox(height: 12),
                ...doneSessions.take(5).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SessionTile(session: s),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showCatalog(
    BuildContext context,
    WidgetRef ref,
    PeerDevice peer,
    List<PeerCatalogEntry>? catalog,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PeerCatalogSheet(
        peer: peer,
        catalog: catalog,
        onDownload: (chapters) {
          ref
              .read(transferProvider.notifier)
              .downloadFromPeer(peer, chapters);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Téléchargement de ${chapters.length} fichier${chapters.length > 1 ? 's' : ''} démarré',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: _teal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(12),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room top bar
// ─────────────────────────────────────────────────────────────────────────────

class _RoomTopBar extends ConsumerWidget {
  final TransferState state;
  final AnimationController pulseCtrl;
  const _RoomTopBar({required this.state, required this.pulseCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _secondary, size: 22),
            onPressed: () {
              ref.read(transferProvider.notifier).stopAll();
              Navigator.of(context).pop();
            },
          ),
          const Expanded(
            child: Text(
              'Salle locale',
              style: TextStyle(
                color: _primary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Active indicator
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final glow = Tween<double>(begin: 0.4, end: 1.0)
                  .evaluate(CurvedAnimation(
                      parent: pulseCtrl, curve: Curves.easeInOut));
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.15 * glow),
                  border: Border.all(
                      color: _teal.withValues(alpha: 0.5 * glow), width: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: glow),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: _teal.withValues(alpha: 0.6 * glow),
                              blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('ACTIF',
                        style: TextStyle(
                            color: _teal,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My device card
// ─────────────────────────────────────────────────────────────────────────────

class _MyDeviceCard extends StatelessWidget {
  final TransferState state;
  final int chapterCount;
  final int mangaCount;
  const _MyDeviceCard(
      {required this.state,
      required this.chapterCount,
      required this.mangaCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: _teal.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _teal.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _tealGlow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _teal.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: _teal, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Mon appareil',
                        style: TextStyle(
                            color: _primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _tealGlow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Moi',
                          style: TextStyle(
                              color: _teal,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$mangaCount manga${mangaCount > 1 ? 's' : ''} · $chapterCount chapitre${chapterCount > 1 ? 's' : ''} partagés',
                  style:
                      const TextStyle(color: _secondary, fontSize: 12),
                ),
                if (state.localIp != null)
                  Text(
                    '${state.localIp}:${state.serverPort}',
                    style: const TextStyle(color: _dim, fontSize: 11),
                  ),
              ],
            ),
          ),
          const Icon(Icons.upload_rounded, color: _teal, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty peers
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPeers extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _EmptyPeers({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final t = Tween<double>(begin: 0.3, end: 0.8)
                  .evaluate(CurvedAnimation(
                      parent: pulseCtrl, curve: Curves.easeInOut));
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _teal.withValues(alpha: 0.15 * t),
                          width: 1),
                    ),
                  ),
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _teal.withValues(alpha: 0.25 * t),
                          width: 1),
                    ),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _tealGlow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search_rounded,
                        color: _teal, size: 18),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Recherche d\'appareils…',
              style: TextStyle(
                  color: _secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'Assurez-vous d\'être sur le même WiFi\nou hotspot que les autres appareils.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _dim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Peer card
// ─────────────────────────────────────────────────────────────────────────────

class _PeerCard extends StatelessWidget {
  final PeerDevice peer;
  final List<PeerCatalogEntry>? catalog;
  final bool loading;
  final VoidCallback onBrowse;
  final VoidCallback onRefresh;

  const _PeerCard({
    required this.peer,
    required this.catalog,
    required this.loading,
    required this.onBrowse,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalChapters =
        catalog?.fold(0, (s, e) => s! + e.chapters.length) ?? 0;
    final totalMangas = catalog?.length ?? 0;
    final totalSize =
        catalog?.fold(0, (s, e) => s! + e.totalSize) ?? 0;

    return GestureDetector(
      onTap: (catalog != null && !loading) ? onBrowse : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _cardBright,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.devices_rounded,
                  color: _secondary, size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.name,
                      style: const TextStyle(
                          color: _primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  if (loading)
                    const Row(children: [
                      SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: _secondary)),
                      SizedBox(width: 6),
                      Text('Chargement du catalogue…',
                          style: TextStyle(color: _secondary, fontSize: 12)),
                    ])
                  else if (catalog == null)
                    const Text('Catalogue non disponible',
                        style: TextStyle(color: _dim, fontSize: 12))
                  else ...[
                    Text(
                      '$totalMangas manga${totalMangas > 1 ? 's' : ''} · $totalChapters chapitre${totalChapters > 1 ? 's' : ''}',
                      style:
                          const TextStyle(color: _secondary, fontSize: 12),
                    ),
                    if (totalSize > 0)
                      Text(_fmtSize(totalSize),
                          style:
                              const TextStyle(color: _dim, fontSize: 11)),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Action
            if (loading)
              const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _teal))
            else if (catalog == null)
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(Icons.refresh_rounded,
                    color: _secondary, size: 22),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _tealGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _teal.withValues(alpha: 0.4)),
                ),
                child: const Text('Parcourir',
                    style: TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session tile (download progress)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final TransferSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final prog = session.totalProgress;
    final isDone = session.status == TransferStatus.done;
    final isFailed = session.status == TransferStatus.failed;

    Color accent = isDone ? _teal : isFailed ? _red : _amber;
    Color glowColor =
        isDone ? _tealGlow : isFailed ? _redGlow : _amber.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: glowColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : isFailed
                          ? Icons.error_outline_rounded
                          : Icons.download_rounded,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.peer.name,
                      style: const TextStyle(
                          color: _primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${session.files.length} fichier${session.files.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: _secondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                isDone
                    ? 'Terminé'
                    : isFailed
                        ? 'Échec'
                        : '${(prog * 100).toInt()}%',
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (!isDone && !isFailed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: prog,
                backgroundColor: _border,
                valueColor: AlwaysStoppedAnimation(accent),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PEER CATALOG BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _PeerCatalogSheet extends StatefulWidget {
  final PeerDevice peer;
  final List<PeerCatalogEntry>? catalog;
  final void Function(List<PeerCatalogChapter>) onDownload;

  const _PeerCatalogSheet({
    required this.peer,
    required this.catalog,
    required this.onDownload,
  });

  @override
  State<_PeerCatalogSheet> createState() => _PeerCatalogSheetState();
}

class _PeerCatalogSheetState extends State<_PeerCatalogSheet> {
  final Set<String> _selected = {};
  final Set<int> _expanded = {0};

  List<PeerCatalogChapter> get _selectedChapters {
    final all = <PeerCatalogChapter>[];
    for (final entry in (widget.catalog ?? [])) {
      for (final ch in entry.chapters) {
        if (_selected.contains(ch.id)) all.add(ch);
      }
    }
    return all;
  }

  int get _selectedSize =>
      _selectedChapters.fold(0, (s, c) => s + c.size);

  void _toggle(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _toggleEntry(PeerCatalogEntry entry, bool allSelected) {
    setState(() {
      if (allSelected) {
        for (final ch in entry.chapters) _selected.remove(ch.id);
      } else {
        for (final ch in entry.chapters) _selected.add(ch.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final totalChapters =
        catalog?.fold(0, (s, e) => s! + e.chapters.length) ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _dim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _cardBright,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.devices_rounded,
                        color: _secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.peer.name,
                            style: const TextStyle(
                                color: _primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text(
                          catalog == null
                              ? 'Catalogue vide'
                              : '${catalog.length} manga${catalog.length > 1 ? 's' : ''} · $totalChapters chapitre${totalChapters > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: _secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: _border, height: 1),

            // Content
            Expanded(
              child: catalog == null || catalog.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded,
                              color: _dim, size: 48),
                          SizedBox(height: 12),
                          Text('Aucun fichier disponible',
                              style: TextStyle(color: _secondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: catalog.length,
                      itemBuilder: (_, i) {
                        final entry = catalog[i];
                        final expanded = _expanded.contains(i);
                        final allSel = entry.chapters
                            .every((c) => _selected.contains(c.id));
                        final someSel = entry.chapters
                            .any((c) => _selected.contains(c.id));

                        return Column(
                          children: [
                            // Manga header
                            InkWell(
                              onTap: () => setState(() =>
                                  expanded
                                      ? _expanded.remove(i)
                                      : _expanded.add(i)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    _TypeBadge(type: entry.itemType),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        entry.mangaName,
                                        style: const TextStyle(
                                          color: _primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${entry.chapters.length}',
                                      style: const TextStyle(
                                          color: _secondary, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    // Select all toggle
                                    GestureDetector(
                                      onTap: () =>
                                          _toggleEntry(entry, allSel),
                                      child: Container(
                                        width: 22, height: 22,
                                        decoration: BoxDecoration(
                                          color: allSel
                                              ? _teal
                                              : someSel
                                                  ? _teal.withValues(alpha: 0.3)
                                                  : Colors.transparent,
                                          border: Border.all(
                                            color: allSel || someSel
                                                ? _teal
                                                : _dim,
                                            width: 1.5,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: allSel
                                            ? const Icon(Icons.check_rounded,
                                                color: Colors.black, size: 14)
                                            : someSel
                                                ? const Icon(
                                                    Icons.remove_rounded,
                                                    color: _teal, size: 14)
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      expanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: _secondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Chapter list
                            if (expanded)
                              ...entry.chapters.map((ch) {
                                final sel = _selected.contains(ch.id);
                                return InkWell(
                                  onTap: () => _toggle(ch.id),
                                  child: Container(
                                    color: sel
                                        ? _teal.withValues(alpha: 0.06)
                                        : null,
                                    padding: const EdgeInsets.fromLTRB(
                                        48, 8, 16, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ch.name,
                                            style: TextStyle(
                                              color: sel
                                                  ? _primary
                                                  : _secondary,
                                              fontSize: 13,
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          ch.sizeLabel,
                                          style: const TextStyle(
                                              color: _dim, fontSize: 11),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 22, height: 22,
                                          child: Checkbox(
                                            value: sel,
                                            onChanged: (_) =>
                                                _toggle(ch.id),
                                            activeColor: _teal,
                                            checkColor: Colors.black,
                                            side: const BorderSide(
                                                color: _dim, width: 1.5),
                                            shape:
                                                RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                            if (i < catalog.length - 1)
                              const Divider(
                                  color: _border, height: 1,
                                  indent: 16, endIndent: 16),
                          ],
                        );
                      },
                    ),
            ),

            // Download bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _fmtSize(_selectedSize),
                        style: const TextStyle(
                            color: _secondary, fontSize: 12),
                      ),
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _selected.isEmpty
                              ? null
                              : const LinearGradient(
                                  colors: [_teal, _tealDim]),
                          color: _selected.isEmpty ? _cardBright : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _selected.isEmpty
                              ? null
                              : [
                                  BoxShadow(
                                      color:
                                          _teal.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4)),
                                ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _selected.isEmpty
                              ? null
                              : () => widget.onDownload(_selectedChapters),
                          child: Text(
                            _selected.isEmpty
                                ? 'Sélectionner des chapitres'
                                : 'Télécharger (${_selected.length})',
                            style: TextStyle(
                              color: _selected.isEmpty
                                  ? _dim
                                  : Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  const _SectionHeader({required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: _secondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _tealGlow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: _teal, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _border)),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TransferItemType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      TransferItemType.anime => ('ANIME', const Color(0xFF3B82F6)),
      TransferItemType.novel => ('ROMAN', const Color(0xFF8B5CF6)),
      TransferItemType.other => ('AUTRE', _secondary),
      _ => ('MANGA', const Color(0xFFF59E0B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WiFi rings icon (lobby)
// ─────────────────────────────────────────────────────────────────────────────

class _WifiRingsIcon extends StatefulWidget {
  @override
  State<_WifiRingsIcon> createState() => _WifiRingsIconState();
}

class _WifiRingsIconState extends State<_WifiRingsIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: const Size(120, 120),
        painter: _WifiRingsPainter(_ctrl.value),
      ),
    );
  }
}

class _WifiRingsPainter extends CustomPainter {
  final double t;
  _WifiRingsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final phase = (t - i * 0.25) % 1.0;
      final radius = 20 + phase * 45;
      final opacity = (1.0 - phase).clamp(0.0, 0.8);
      paint
        ..color = _teal.withValues(alpha: opacity * 0.5)
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Center icon
    final centerPaint = Paint()
      ..color = _tealGlow
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 22, centerPaint);

    final borderPaint = Paint()
      ..color = _teal.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 22, borderPaint);
  }

  @override
  bool shouldRepaint(_WifiRingsPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Background blob
// ─────────────────────────────────────────────────────────────────────────────

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        radius: 0.7,
        colors: [
          _teal.withValues(alpha: 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

String _fmtSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
