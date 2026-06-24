import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:watchtower/services/transfer/transfer_models.dart';
import 'package:watchtower/services/transfer/transfer_notifier.dart';
import 'package:watchtower/services/transfer/transfer_server.dart';

// ──────────────────────────────────────────────
// Colours
// ──────────────────────────────────────────────
const _bg = Color(0xFF0E0E0E);
const _card = Color(0xFF1A1A1A);
const _border = Color(0xFF2A2A2A);
const _teal = Color(0xFF1DB954);
const _tealDim = Color(0xFF17A349);
const _red = Color(0xFFE53935);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9E9E9E);
const _textDim = Color(0xFF555555);

// ──────────────────────────────────────────────
// File scanner
// ──────────────────────────────────────────────
Future<List<TransferFile>> _scanDownloads() async {
  if (kIsWeb) return [];
  Directory base;
  if (Platform.isAndroid) {
    base = Directory('/storage/emulated/0/Watchtower');
  } else {
    final docs = await getApplicationDocumentsDirectory();
    base = Directory(p.join(docs.path, 'Watchtower'));
  }
  if (!await base.exists()) return [];

  const _allowed = {
    'cbz', 'cbr', 'zip',
    'mp4', 'mkv', 'avi', 'webm', 'm4v',
    'epub', 'fb2', 'mobi',
    'pdf',
  };

  final results = <TransferFile>[];
  final rng = Random();

  try {
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
      if (!_allowed.contains(ext)) continue;
      final stat = await entity.stat();
      if (stat.size == 0) continue;
      results.add(TransferFile(
        id: List.generate(12, (_) => rng.nextInt(16).toRadixString(16)).join(),
        name: p.basename(entity.path),
        size: stat.size,
        type: TransferFile.typeFromExtension(entity.path),
        localPath: entity.path,
      ));
    }
  } catch (_) {}

  results.sort((a, b) => a.name.compareTo(b.name));
  return results;
}

// ──────────────────────────────────────────────
// Main screen
// ──────────────────────────────────────────────
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () {
            ref.read(transferProvider.notifier).stopAll();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Transfert Local',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: _textPrimary),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _ChipTabBar(controller: _tabs),
          const SizedBox(height: 4),
          // Incoming offers banner
          if (state.pendingOffers.isNotEmpty)
            _OfferBanner(
              offers: state.pendingOffers,
              onAccept: (o) =>
                  ref.read(transferProvider.notifier).acceptOffer(o),
              onReject: (o) =>
                  ref.read(transferProvider.notifier).rejectOffer(o),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SendTab(onTabSwitch: () => _tabs.animateTo(1)),
                const _ReceiveTab(),
                const _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comment transférer ?',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              '• Les deux appareils doivent être sur le même réseau Wi-Fi,\n'
              '  OU l\'un crée un Hotspot et l\'autre s\'y connecte.\n\n'
              '• Sur l\'appareil destinataire : onglet Recevoir → "Activer".\n\n'
              '• Sur l\'appareil source : onglet Envoyer → sélectionner\n'
              '  l\'appareil → choisir les fichiers → Envoyer.\n\n'
              '• Le destinataire voit une notification d\'acceptation.\n'
              '  Les fichiers reçus s\'enregistrent dans Watchtower/received/.',
              style: TextStyle(
                  color: _textSecondary, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Chip tab bar
// ──────────────────────────────────────────────
class _ChipTabBar extends StatelessWidget {
  final TabController controller;
  const _ChipTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final labels = ['Envoyer', 'Recevoir', 'Historique'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Row(
          children: List.generate(labels.length, (i) {
            final sel = controller.index == i;
            return Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => controller.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _textPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: sel ? _textPrimary : Colors.white38,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: sel ? Colors.black : _textSecondary,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Offer banner
// ──────────────────────────────────────────────
class _OfferBanner extends StatelessWidget {
  final List<IncomingOffer> offers;
  final void Function(IncomingOffer) onAccept;
  final void Function(IncomingOffer) onReject;

  const _OfferBanner({
    required this.offers,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: offers
          .map((o) => _OfferCard(
                offer: o,
                onAccept: () => onAccept(o),
                onReject: () => onReject(o),
              ))
          .toList(),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final IncomingOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final o = offer.offer;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, color: _teal, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.from.name,
                    style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(
                  '${o.files.length} fichier${o.files.length > 1 ? 's' : ''} · ${o.totalSizeLabel}',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReject,
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Refuser'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Accepter',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// SEND TAB
// ──────────────────────────────────────────────
class _SendTab extends ConsumerStatefulWidget {
  final VoidCallback onTabSwitch;
  const _SendTab({required this.onTabSwitch});

  @override
  ConsumerState<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<_SendTab> {
  bool _scanning = false;

  Future<void> _startScanning() async {
    await ref.read(transferProvider.notifier).startSending();
    if (mounted) setState(() => _scanning = true);
  }

  void _stopScanning() {
    ref.read(transferProvider.notifier).stopAll();
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider);
    final peers = state.peers;
    final activeSessions =
        state.sessions.where((s) => s.isSender).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status card
        _StatusCard(
          active: _scanning,
          icon: _scanning
              ? Icons.radar_rounded
              : Icons.wifi_find_rounded,
          title: _scanning
              ? 'Recherche d\'appareils…'
              : 'Trouver un appareil',
          subtitle: _scanning
              ? 'Les appareils avec Watchtower en mode Recevoir apparaissent ici'
              : 'Assurez-vous que les deux appareils sont sur le même réseau Wi-Fi',
          actionLabel: _scanning ? 'Arrêter' : 'Démarrer',
          onAction: _scanning ? _stopScanning : _startScanning,
          trailing: _scanning ? const _RadarAnimation() : null,
        ),
        const SizedBox(height: 16),

        // Peers list
        if (_scanning && peers.isEmpty)
          const _EmptyHint(
            icon: Icons.devices_other_rounded,
            text: 'Aucun appareil trouvé\nVérifiez que l\'autre appareil a activé la réception',
          ),

        ...peers.map((peer) => _PeerCard(
              peer: peer,
              onTap: () => _openFilePicker(context, peer),
            )),

        // Active send sessions
        if (activeSessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader('Transferts en cours'),
          ...activeSessions.map((s) => _SessionCard(session: s)),
        ],
      ],
    );
  }

  Future<void> _openFilePicker(BuildContext context, PeerDevice peer) async {
    final files = await showModalBottomSheet<List<TransferFile>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FilePickerSheet(peer: peer),
    );

    if (files == null || files.isEmpty) return;
    if (!mounted) return;

    ref.read(transferProvider.notifier).sendFiles(peer, files);
  }
}

// ──────────────────────────────────────────────
// RECEIVE TAB
// ──────────────────────────────────────────────
class _ReceiveTab extends ConsumerWidget {
  const _ReceiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferProvider);
    final active = state.mode == TransferMode.receiving;
    final incomingSessions =
        state.sessions.where((s) => !s.isSender).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(
          active: active,
          icon: active
              ? Icons.wifi_tethering_rounded
              : Icons.download_rounded,
          title: active ? 'En écoute…' : 'Activer la réception',
          subtitle: active
              ? 'Cet appareil est visible sur le réseau local\nIP: ${state.localIp ?? '—'}  Port: ${state.serverPort ?? '—'}'
              : 'Ouvre le serveur de réception et diffuse votre présence sur le Wi-Fi',
          actionLabel: active ? 'Désactiver' : 'Activer',
          onAction: active
              ? () => ref.read(transferProvider.notifier).stopAll()
              : () => ref.read(transferProvider.notifier).startReceiving(),
          trailing: active ? const _PulseAnimation() : null,
        ),
        const SizedBox(height: 16),

        if (active && state.pendingOffers.isEmpty && incomingSessions.isEmpty)
          const _EmptyHint(
            icon: Icons.inbox_rounded,
            text: 'En attente d\'un envoi entrant\nDemandez à l\'autre appareil d\'envoyer',
          ),

        if (incomingSessions.isNotEmpty) ...[
          const _SectionHeader('Fichiers reçus'),
          ...incomingSessions.map((s) => _SessionCard(session: s)),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────
// HISTORY TAB
// ──────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transferProvider);
    final done = state.sessions
        .where((s) =>
            s.status == TransferStatus.done ||
            s.status == TransferStatus.failed ||
            s.status == TransferStatus.rejected)
        .toList()
        .reversed
        .toList();

    if (done.isEmpty) {
      return const _EmptyHint(
        icon: Icons.history_rounded,
        text: 'Aucun transfert récent',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: done.map((s) => _SessionCard(session: s)).toList(),
    );
  }
}

// ──────────────────────────────────────────────
// Status card
// ──────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? trailing;

  const _StatusCard({
    required this.active,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? _teal.withValues(alpha: 0.4) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: active ? _teal : _textSecondary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
                color: _textSecondary, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? const Color(0xFF2A1A1A) : _teal,
                foregroundColor: active ? _red : Colors.black,
                side: active
                    ? const BorderSide(color: _red)
                    : BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Peer card
// ──────────────────────────────────────────────
class _PeerCard extends StatelessWidget {
  final PeerDevice peer;
  final VoidCallback onTap;

  const _PeerCard({required this.peer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_android_rounded,
                  color: _teal, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(peer.name,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(peer.ip,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _textDim, size: 20),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Session progress card
// ──────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final TransferSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final isDone = session.status == TransferStatus.done;
    final isFailed = session.status == TransferStatus.failed;
    final isRejected = session.status == TransferStatus.rejected;
    final isActive = session.status == TransferStatus.inProgress;

    Color statusColor = _textSecondary;
    IconData statusIcon = Icons.hourglass_empty_rounded;
    String statusLabel = 'En attente';

    if (isDone) {
      statusColor = _teal;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Terminé';
    } else if (isFailed) {
      statusColor = _red;
      statusIcon = Icons.error_rounded;
      statusLabel = 'Échoué';
    } else if (isRejected) {
      statusColor = _red;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Refusé';
    } else if (isActive) {
      statusColor = _teal;
      statusIcon = Icons.sync_rounded;
      statusLabel = session.isSender ? 'Envoi…' : 'Réception…';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.isSender
                    ? Icons.upload_rounded
                    : Icons.download_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.peer.name,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 4),
              Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${session.files.length} fichier${session.files.length > 1 ? 's' : ''} · '
            '${_fmtSize(session.totalSize)}',
            style: const TextStyle(color: _textSecondary, fontSize: 12),
          ),
          if (isActive) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: session.totalProgress,
                backgroundColor: _border,
                color: _teal,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(session.totalProgress * 100).toStringAsFixed(0)} %',
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ],
          if (session.files.length > 1 && isActive) ...[
            const SizedBox(height: 8),
            ...session.files.take(5).map((f) {
              final prog = session.fileProgress[f.id] ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.name,
                        style: const TextStyle(
                            color: _textDim, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(prog * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 10),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ──────────────────────────────────────────────
// File picker bottom sheet
// ──────────────────────────────────────────────
class _FilePickerSheet extends StatefulWidget {
  final PeerDevice peer;
  const _FilePickerSheet({required this.peer});

  @override
  State<_FilePickerSheet> createState() => _FilePickerSheetState();
}

class _FilePickerSheetState extends State<_FilePickerSheet> {
  bool _loading = true;
  List<TransferFile> _allFiles = [];
  final Set<String> _selected = {};
  TransferItemType? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final files = await _scanDownloads();
    if (mounted) setState(() { _allFiles = files; _loading = false; });
  }

  List<TransferFile> get _filtered {
    if (_filter == null) return _allFiles;
    return _allFiles.where((f) => f.type == _filter).toList();
  }

  List<TransferFile> get _selectedFiles =>
      _allFiles.where((f) => _selected.contains(f.id)).toList();

  int get _selectedSize =>
      _selectedFiles.fold(0, (s, f) => s + f.size);

  void _toggleAll() {
    final ids = _filtered.map((f) => f.id).toSet();
    if (ids.every(_selected.contains)) {
      setState(() => _selected.removeAll(ids));
    } else {
      setState(() => _selected.addAll(ids));
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Envoyer à ${widget.peer.name}',
                          style: const TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      if (_selected.isNotEmpty)
                        Text(
                          '${_selected.length} sélectionné(s) · ${_fmtSize(_selectedSize)}',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (!_loading && _filtered.isNotEmpty)
                  TextButton(
                    onPressed: _toggleAll,
                    child: const Text('Tout',
                        style: TextStyle(color: _teal, fontSize: 13)),
                  ),
              ],
            ),
          ),
          // Type filter chips
          if (!_loading && _allFiles.isNotEmpty)
            _TypeFilterRow(
              current: _filter,
              onChanged: (t) => setState(() => _filter = t),
            ),
          const Divider(color: _border, height: 1),
          // File list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _teal))
                : _filtered.isEmpty
                    ? const _EmptyHint(
                        icon: Icons.folder_open_outlined,
                        text: 'Aucun fichier téléchargé trouvé')
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: _border, height: 1),
                        itemBuilder: (_, i) {
                          final f = _filtered[i];
                          final sel = _selected.contains(f.id);
                          return ListTile(
                            tileColor: sel
                                ? _teal.withValues(alpha: 0.08)
                                : null,
                            leading: _TypeIcon(type: f.type),
                            title: Text(f.name,
                                style: const TextStyle(
                                    color: _textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(f.sizeLabel,
                                style: const TextStyle(
                                    color: _textSecondary, fontSize: 11)),
                            trailing: Checkbox(
                              value: sel,
                              activeColor: _teal,
                              checkColor: Colors.black,
                              side: const BorderSide(color: _textSecondary),
                              onChanged: (_) => setState(() {
                                if (sel) {
                                  _selected.remove(f.id);
                                } else {
                                  _selected.add(f.id);
                                }
                              }),
                            ),
                            onTap: () => setState(() {
                              if (sel) {
                                _selected.remove(f.id);
                              } else {
                                _selected.add(f.id);
                              }
                            }),
                          );
                        },
                      ),
          ),
          // Bottom action
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selectedFiles),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _border,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _selected.isEmpty
                        ? 'Sélectionner des fichiers'
                        : 'Envoyer ${_selected.length} fichier${_selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _TypeFilterRow extends StatelessWidget {
  final TransferItemType? current;
  final void Function(TransferItemType?) onChanged;

  const _TypeFilterRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = [
      (null, 'Tout', Icons.all_inclusive_rounded),
      (TransferItemType.manga, 'Manga', Icons.menu_book_rounded),
      (TransferItemType.anime, 'Anime', Icons.movie_rounded),
      (TransferItemType.novel, 'Roman', Icons.article_rounded),
      (TransferItemType.other, 'Autre', Icons.insert_drive_file_rounded),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: types.map(((TransferItemType?, String, IconData) e) {
          final sel = current == e.$1;
          return GestureDetector(
            onTap: () => onChanged(e.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: sel ? _teal.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? _teal : _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(e.$3,
                      size: 14,
                      color: sel ? _teal : _textSecondary),
                  const SizedBox(width: 4),
                  Text(e.$2,
                      style: TextStyle(
                          fontSize: 12,
                          color: sel ? _teal : _textSecondary)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final TransferItemType type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      TransferItemType.manga => (Icons.menu_book_rounded, const Color(0xFF9C27B0)),
      TransferItemType.anime => (Icons.movie_rounded, const Color(0xFF1565C0)),
      TransferItemType.novel => (Icons.article_rounded, const Color(0xFF00796B)),
      TransferItemType.other => (Icons.insert_drive_file_rounded, _textDim),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ──────────────────────────────────────────────
// Animations
// ──────────────────────────────────────────────
class _RadarAnimation extends StatefulWidget {
  const _RadarAnimation();
  @override
  State<_RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<_RadarAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _RadarPainter(_ctrl.value),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final t = ((progress + i / 3) % 1.0);
      final r = maxR * t;
      final opacity = (1 - t) * 0.8;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = _teal.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawCircle(
      center,
      4,
      Paint()..color = _teal,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();
  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const Icon(Icons.wifi_tethering_rounded, color: _teal, size: 28),
    );
  }
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 56, color: _textPrimary.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(text,
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 13, height: 1.6),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
