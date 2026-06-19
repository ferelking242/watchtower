import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Telegram colour palette
// ─────────────────────────────────────────────────────────────────────────────

const _tgBlue = Color(0xFF2AABEE);
const _tgDark = Color(0xFF17212B);
const _tgCard = Color(0xFF1E2C3A);
const _tgBorder = Color(0xFF2B5278);
const _tgText = Color(0xFFFFFFFF);
const _tgSubtext = Color(0xFF8A9CB1);

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum _TgStep { phone, code, password, home }

class _Channel {
  final String name;
  final String username;
  final String lastMessage;
  final int unread;
  final String avatarLabel;
  final Color avatarColor;

  const _Channel({
    required this.name,
    required this.username,
    required this.lastMessage,
    required this.unread,
    required this.avatarLabel,
    required this.avatarColor,
  });
}

const _mockChannels = [
  _Channel(
    name: 'Watchtower Annonces',
    username: '@watchtower_ann',
    lastMessage: 'Mise à jour v8.2 disponible',
    unread: 3,
    avatarLabel: 'W',
    avatarColor: Color(0xFF6C3CE1),
  ),
  _Channel(
    name: 'Anime FR',
    username: '@anime_fr_hub',
    lastMessage: 'Chainsaw Man EP 12 VOSTFR',
    unread: 12,
    avatarLabel: 'A',
    avatarColor: Color(0xFFE14040),
  ),
  _Channel(
    name: 'Films HD VOSTFR',
    username: '@films_hd_vf',
    lastMessage: 'Dune Part 2 4K HDR',
    unread: 0,
    avatarLabel: 'F',
    avatarColor: Color(0xFF40A2E1),
  ),
  _Channel(
    name: 'Manga Direct',
    username: '@manga_direct',
    lastMessage: 'One Piece CH.1110 RAW',
    unread: 5,
    avatarLabel: 'M',
    avatarColor: Color(0xFF2EC050),
  ),
  _Channel(
    name: 'Series Zone',
    username: '@series_zone',
    lastMessage: 'Breaking Bad S01 Complet',
    unread: 1,
    avatarLabel: 'S',
    avatarColor: Color(0xFFE1A040),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});

  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  _TgStep _step = _TgStep.phone;
  bool _loading = false;
  String? _error;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doAction() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (_step == _TgStep.phone) {
        _step = _TgStep.code;
      } else if (_step == _TgStep.code) {
        _step = _TgStep.home;
      } else if (_step == _TgStep.password) {
        _step = _TgStep.home;
      }
    });
  }

  void _logout() {
    setState(() {
      _step = _TgStep.phone;
      _phoneCtrl.clear();
      _codeCtrl.clear();
      _passCtrl.clear();
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _tgField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? action,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: action,
      onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
      style: const TextStyle(color: _tgText, fontSize: 16),
      cursorColor: _tgBlue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _tgSubtext),
        hintStyle: const TextStyle(color: _tgSubtext),
        suffixIcon: suffix,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _tgBorder),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _tgBlue, width: 2),
        ),
      ),
    );
  }

  Widget _tgButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _tgBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Login scaffold wrapper ─────────────────────────────────────────────────

  Widget _loginShell({required Widget child, required String title}) {
    return Scaffold(
      backgroundColor: _tgDark,
      appBar: AppBar(
        backgroundColor: _tgDark,
        foregroundColor: _tgText,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _tgBlue, size: 22),
            SizedBox(width: 10),
            Text('Telegram', style: TextStyle(color: _tgText)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone step ─────────────────────────────────────────────────────────────

  Widget _buildPhone() {
    return _loginShell(
      title: 'Connexion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_iphone_rounded,
              color: _tgBlue, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Votre numéro',
            style: TextStyle(
                color: _tgText, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Confirmez votre pays et entrez votre numéro de téléphone.',
            style: TextStyle(color: _tgSubtext, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          _tgField(
            ctrl: _phoneCtrl,
            label: 'Numéro de téléphone',
            hint: '+33 6 00 00 00 00',
            keyboardType: TextInputType.phone,
            action: TextInputAction.go,
            onSubmit: _loading ? null : _doAction,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13)),
          ],
          const SizedBox(height: 36),
          _tgButton('Suivant', _loading ? null : _doAction),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'En continuant vous acceptez les\nConditions d\'utilisation de Telegram.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _tgSubtext.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Code step ─────────────────────────────────────────────────────────────

  Widget _buildCode() {
    return _loginShell(
      title: 'Code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: _tgBlue, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Code de vérification',
            style: TextStyle(
                color: _tgText, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Telegram a envoyé un code au ${_phoneCtrl.text.isEmpty ? 'votre numéro' : _phoneCtrl.text}.',
            style:
                const TextStyle(color: _tgSubtext, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          _tgField(
            ctrl: _codeCtrl,
            label: 'Code',
            hint: '- - - - -',
            keyboardType: TextInputType.number,
            action: TextInputAction.go,
            onSubmit: _loading ? null : _doAction,
          ),
          const SizedBox(height: 36),
          _tgButton('Valider', _loading ? null : _doAction),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = _TgStep.phone),
              style: TextButton.styleFrom(foregroundColor: _tgBlue),
              child: const Text('Modifier le numéro'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2FA password step ─────────────────────────────────────────────────────

  Widget _buildPassword() {
    return _loginShell(
      title: '2FA',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: _tgBlue, size: 64),
          const SizedBox(height: 24),
          const Text(
            'Vérification en 2 étapes',
            style: TextStyle(
                color: _tgText, fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Votre compte est protégé par un mot de passe.',
            style: TextStyle(color: _tgSubtext, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          _tgField(
            ctrl: _passCtrl,
            label: 'Mot de passe',
            hint: '••••••••',
            obscure: !_showPass,
            suffix: IconButton(
              icon: Icon(
                _showPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _tgSubtext,
              ),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
            action: TextInputAction.go,
            onSubmit: _loading ? null : _doAction,
          ),
          const SizedBox(height: 36),
          _tgButton('Confirmer', _loading ? null : _doAction),
        ],
      ),
    );
  }

  // ── Home: channel browser ─────────────────────────────────────────────────

  Widget _buildHome() {
    final filtered = _mockChannels
        .where((c) =>
            _searchQuery.isEmpty ||
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.username.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: _tgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2733),
        foregroundColor: _tgText,
        elevation: 0.5,
        shadowColor: _tgBorder,
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _tgBlue, size: 20),
            SizedBox(width: 8),
            Text('Telegram',
                style: TextStyle(color: _tgText, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            color: _tgSubtext,
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _tgSubtext),
            color: _tgCard,
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Color(0xFFFF5252), size: 18),
                    SizedBox(width: 8),
                    Text('Déconnexion',
                        style: TextStyle(color: Color(0xFFFF5252))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              decoration: BoxDecoration(
                color: _tgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _tgBorder.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: _tgText, fontSize: 15),
                cursorColor: _tgBlue,
                decoration: const InputDecoration(
                  hintText: 'Rechercher',
                  hintStyle: TextStyle(color: _tgSubtext),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: _tgSubtext, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),

          // Channel list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Aucun résultat',
                      style: TextStyle(color: _tgSubtext),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 72,
                          color: _tgBorder.withValues(alpha: 0.4),
                        ),
                    itemBuilder: (context, i) {
                      final ch = filtered[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showChannelSheet(ch),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: ch.avatarColor,
                                  child: Text(
                                    ch.avatarLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ch.name,
                                              style: const TextStyle(
                                                color: _tgText,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (ch.unread > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _tgBlue,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                ch.unread.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        ch.lastMessage,
                                        style: const TextStyle(
                                          color: _tgSubtext,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showChannelSheet(_Channel ch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _tgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: ch.avatarColor,
              child: Text(
                ch.avatarLabel,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(ch.name,
                style: const TextStyle(
                    color: _tgText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(ch.username,
                style:
                    const TextStyle(color: _tgBlue, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Utiliser comme source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tgBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tgSubtext,
                  side: const BorderSide(color: _tgBorder),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Annuler'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _TgStep.phone => _buildPhone(),
      _TgStep.code => _buildCode(),
      _TgStep.password => _buildPassword(),
      _TgStep.home => _buildHome(),
    };
  }
}
