import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watchtower/services/telegram/telegram_service.dart';

// ── Palette Telegram Dark ──────────────────────────────────────────────────
const _tgBg     = Color(0xFF17212B);
const _tgCard   = Color(0xFF1E2C3A);
const _tgBorder = Color(0xFF2B5278);
const _tgBlue   = Color(0xFF2AABEE);
const _tgText   = Color(0xFFFFFFFF);
const _tgHint   = Color(0xFF7F8EA3);
const _tgError  = Color(0xFFFF5252);

// ═════════════════════════════════════════════════════════════════════════════
// Entry point
// ═════════════════════════════════════════════════════════════════════════════

class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});
  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  bool _checking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final ok = await TelegramService.instance.hasSession();
    if (mounted) setState(() { _hasSession = ok; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: _tgBg,
        body: Center(child: CircularProgressIndicator(color: _tgBlue)),
      );
    }
    if (!_hasSession) {
      return _LoginFlow(
        onLoginSuccess: () => setState(() => _hasSession = true),
      );
    }
    return _MainScreen(
      onLogout: () => setState(() => _hasSession = false),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOGIN FLOW — 4 steps: ApiKeys → Phone → OTP → (2FA)
// ═════════════════════════════════════════════════════════════════════════════

class _LoginFlow extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const _LoginFlow({required this.onLoginSuccess});
  @override
  State<_LoginFlow> createState() => _LoginFlowState();
}

class _LoginFlowState extends State<_LoginFlow> {
  int _step = 0;
  String _apiId        = '';
  String _apiHash      = '';
  String _phone        = '';
  String _pcoh         = '';

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => _ApiKeysScreen(
          onDone: (id, hash) => setState(() {
            _apiId = id; _apiHash = hash; _step = 1;
          }),
        ),
      1 => _PhoneScreen(
          apiId: _apiId, apiHash: _apiHash,
          onBack: () => setState(() => _step = 0),
          onDone: (phone, pcoh) => setState(() {
            _phone = phone; _pcoh = pcoh; _step = 2;
          }),
        ),
      2 => _OtpScreen(
          apiId: _apiId, apiHash: _apiHash,
          phone: _phone, pcoh: _pcoh,
          onBack: () => setState(() => _step = 1),
          onSuccess: _onAuthDone,
          onTwoFa: () => setState(() => _step = 3),
        ),
      3 => _TwoFaScreen(
          apiId: _apiId, apiHash: _apiHash,
          onBack: () => setState(() => _step = 2),
          onSuccess: _onAuthDone,
        ),
      _ => _ApiKeysScreen(
          onDone: (id, hash) => setState(() {
            _apiId = id; _apiHash = hash; _step = 1;
          }),
        ),
    };
  }

  Future<void> _onAuthDone(String session) async {
    await TelegramService.instance.saveSession(
      session: session,
      apiId: _apiId,
      apiHash: _apiHash,
      phone: _phone,
    );
    widget.onLoginSuccess();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — API ID + API HASH
// ─────────────────────────────────────────────────────────────────────────────

class _ApiKeysScreen extends StatefulWidget {
  final void Function(String apiId, String apiHash) onDone;
  const _ApiKeysScreen({required this.onDone});
  @override
  State<_ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<_ApiKeysScreen> {
  final _idCtrl   = TextEditingController();
  final _hashCtrl = TextEditingController();
  bool _showHash  = false;
  String? _error;
  bool _installing = false;
  String _installLog = '';

  @override
  void dispose() {
    _idCtrl.dispose(); _hashCtrl.dispose();
    super.dispose();
  }

  void _next() {
    final id   = _idCtrl.text.trim();
    final hash = _hashCtrl.text.trim();
    if (id.isEmpty || hash.isEmpty) {
      setState(() => _error = 'Remplis les deux champs');
      return;
    }
    if (int.tryParse(id) == null) {
      setState(() => _error = 'API ID doit être un nombre');
      return;
    }
    widget.onDone(id, hash);
  }

  Future<void> _installDeps() async {
    setState(() { _installing = true; _installLog = 'Installation de pyrogram...'; });
    final result = await TelegramService.instance.ensureDeps(
      onProgress: (msg) {
        if (mounted) setState(() => _installLog = msg);
      },
    );
    if (mounted) setState(() { _installing = false; _installLog = result; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tgBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 96, height: 96,
                decoration: const BoxDecoration(color: _tgBlue, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 28),
              const Text('Telegram Source',
                style: TextStyle(color: _tgText, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                'Entrez vos identifiants API Telegram.\nObtenez-les sur my.telegram.org',
                textAlign: TextAlign.center,
                style: TextStyle(color: _tgHint, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {},
                child: const Text('my.telegram.org/apps →',
                  style: TextStyle(color: _tgBlue, fontSize: 13, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 36),
              _TgField(ctrl: _idCtrl, label: 'API ID', hint: '1234567', keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _TgField(
                ctrl: _hashCtrl, label: 'API Hash', hint: 'a1b2c3d4...',
                obscure: !_showHash,
                suffix: IconButton(
                  icon: Icon(_showHash ? Icons.visibility_off : Icons.visibility, color: _tgHint, size: 20),
                  onPressed: () => setState(() => _showHash = !_showHash),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: _tgError, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              _TgButton(label: 'Continuer', onTap: _next),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2B3A4A)),
              const SizedBox(height: 12),
              const Text('Dépendances Python (pyrogram)',
                style: TextStyle(color: _tgHint, fontSize: 12)),
              const SizedBox(height: 8),
              _TgButton(
                label: _installing ? 'Installation...' : 'Installer pyrogram',
                loading: _installing,
                onTap: _installing ? null : _installDeps,
                outlined: true,
              ),
              if (_installLog.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_installLog,
                    style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — NUMÉRO DE TÉLÉPHONE
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneScreen extends StatefulWidget {
  final String apiId, apiHash;
  final VoidCallback onBack;
  final void Function(String phone, String pcoh) onDone;
  const _PhoneScreen({required this.apiId, required this.apiHash, required this.onBack, required this.onDone});
  @override
  State<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<_PhoneScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String _countryCode = '+1';

  static const _countries = [
    ('🇺🇸', 'United States', '+1'), ('🇬🇧', 'United Kingdom', '+44'),
    ('🇫🇷', 'France', '+33'), ('🇨🇬', 'Congo', '+242'),
    ('🇨🇩', 'Congo DRC', '+243'), ('🇨🇦', 'Canada', '+1'),
    ('🇩🇪', 'Germany', '+49'), ('🇧🇪', 'Belgium', '+32'),
    ('🇨🇭', 'Switzerland', '+41'), ('🇧🇷', 'Brazil', '+55'),
    ('🇦🇺', 'Australia', '+61'), ('🇯🇵', 'Japan', '+81'),
    ('🇷🇺', 'Russia', '+7'), ('🇮🇳', 'India', '+91'),
    ('🇨🇳', 'China', '+86'), ('🇲🇦', 'Morocco', '+212'),
    ('🇸🇳', 'Senegal', '+221'), ('🇨🇲', 'Cameroon', '+237'),
    ('🇬🇦', 'Gabon', '+241'),
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    final number = _ctrl.text.trim();
    if (number.isEmpty) { setState(() => _error = 'Entrez votre numéro'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final phone = '$_countryCode$number';
      final result = await TelegramService.instance.sendCode(
        apiId: widget.apiId, apiHash: widget.apiHash, phone: phone,
      );
      if (!mounted) return;
      if (result['status'] == 'ok') {
        final pcoh = result['data']?['phone_code_hash']?.toString() ?? '';
        await TelegramService.instance.saveTmpAuth(phone, pcoh);
        widget.onDone(phone, pcoh);
      } else {
        setState(() => _error = result['error']?.toString() ?? 'Échec de l\'envoi du code');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: _tgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: 400,
        child: ListView.builder(
          itemCount: _countries.length,
          itemBuilder: (_, i) {
            final (flag, name, code) = _countries[i];
            return ListTile(
              leading: Text(flag, style: const TextStyle(fontSize: 24)),
              title: Text(name, style: const TextStyle(color: _tgText)),
              trailing: Text(code, style: const TextStyle(color: _tgHint)),
              onTap: () { setState(() => _countryCode = code); Navigator.pop(ctx); },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _LoginShell(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phone_iphone_rounded, color: _tgBlue, size: 64),
          const SizedBox(height: 20),
          const Text('Votre numéro', style: TextStyle(color: _tgText, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Confirmez votre pays et entrez votre numéro de téléphone.',
            style: TextStyle(color: _tgHint, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          Row(
            children: [
              GestureDetector(
                onTap: _showPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _tgBorder)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_countryCode, style: const TextStyle(color: _tgText, fontSize: 16)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: _tgHint, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TgField(ctrl: _ctrl, label: 'Numéro', hint: '06 00 00 00 00',
                  keyboardType: TextInputType.phone),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _tgError, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          _TgButton(label: 'Suivant', loading: _loading, onTap: _loading ? null : _send),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'En continuant, vous acceptez les Conditions d\'utilisation de Telegram.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _tgHint.withValues(alpha: 0.7), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — CODE OTP (RÉEL)
// ─────────────────────────────────────────────────────────────────────────────

class _OtpScreen extends StatefulWidget {
  final String apiId, apiHash, phone, pcoh;
  final VoidCallback onBack, onTwoFa;
  final Future<void> Function(String session) onSuccess;
  const _OtpScreen({
    required this.apiId, required this.apiHash,
    required this.phone, required this.pcoh,
    required this.onBack, required this.onSuccess, required this.onTwoFa,
  });
  @override
  State<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<_OtpScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _verify() async {
    final code = _ctrl.text.trim().replaceAll(' ', '').replaceAll('-', '');
    if (code.isEmpty) { setState(() => _error = 'Entrez le code reçu'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await TelegramService.instance.verifyCode(
        apiId: widget.apiId, apiHash: widget.apiHash,
        phone: widget.phone, phoneCodeHash: widget.pcoh, code: code,
      );
      if (!mounted) return;
      if (result['status'] == 'ok') {
        final session = result['data']?['session_string']?.toString() ?? '';
        await widget.onSuccess(session);
      } else if (result['status'] == '2fa_required') {
        widget.onTwoFa();
      } else {
        setState(() => _error = result['error']?.toString() ?? 'Code incorrect');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LoginShell(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: _tgBlue, size: 64),
          const SizedBox(height: 20),
          const Text('Code de vérification',
            style: TextStyle(color: _tgText, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Telegram a envoyé un code au ${widget.phone}.',
            style: const TextStyle(color: _tgHint, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          _TgField(ctrl: _ctrl, label: 'Code', hint: '- - - - -',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _tgError, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          _TgButton(label: 'Valider', loading: _loading, onTap: _loading ? null : _verify),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _error = null),
              style: TextButton.styleFrom(foregroundColor: _tgBlue),
              child: const Text('Renvoyer le code'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — 2FA
// ─────────────────────────────────────────────────────────────────────────────

class _TwoFaScreen extends StatefulWidget {
  final String apiId, apiHash;
  final VoidCallback onBack;
  final Future<void> Function(String session) onSuccess;
  const _TwoFaScreen({
    required this.apiId, required this.apiHash,
    required this.onBack, required this.onSuccess,
  });
  @override
  State<_TwoFaScreen> createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends State<_TwoFaScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _showPass = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _confirm() async {
    final pass = _ctrl.text;
    if (pass.isEmpty) { setState(() => _error = 'Entrez votre mot de passe 2FA'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await TelegramService.instance.checkPassword(
        apiId: widget.apiId, apiHash: widget.apiHash, password: pass,
      );
      if (!mounted) return;
      if (result['status'] == 'ok') {
        final session = result['data']?['session_string']?.toString() ?? '';
        await widget.onSuccess(session);
      } else {
        setState(() => _error = result['error']?.toString() ?? 'Mot de passe incorrect');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LoginShell(
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: _tgBlue, size: 64),
          const SizedBox(height: 20),
          const Text('Vérification en 2 étapes',
            style: TextStyle(color: _tgText, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Votre compte est protégé par un mot de passe cloud.',
            style: TextStyle(color: _tgHint, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
          _TgField(
            ctrl: _ctrl, label: 'Mot de passe', hint: '••••••••',
            obscure: !_showPass,
            suffix: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: _tgHint, size: 20),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: _tgError, fontSize: 13)),
          ],
          const SizedBox(height: 32),
          _TgButton(label: 'Confirmer', loading: _loading, onTap: _loading ? null : _confirm),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN — Liste de canaux ajoutés
// ═════════════════════════════════════════════════════════════════════════════

class _MainScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const _MainScreen({required this.onLogout});
  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  final _searchCtrl = TextEditingController();
  final _addCtrl    = TextEditingController();
  String _query = '';
  bool _addLoading = false;
  String? _addError;

  Map<String, dynamic> _creds = {};
  List<Map<String, dynamic>> _channels = [];
  bool _loadingCreds = true;

  @override
  void initState() {
    super.initState();
    _loadCreds();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCreds() async {
    final c = await TelegramService.instance.loadCredentials();
    if (mounted) setState(() { _creds = c; _loadingCreds = false; });
  }

  Future<void> _logout() async {
    await TelegramService.instance.logout();
    widget.onLogout();
  }

  Future<void> _addChannel() async {
    final raw = _addCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _addLoading = true; _addError = null; });
    final channel = raw.startsWith('@') ? raw : '@$raw';
    try {
      final result = await TelegramService.instance.getMetadata(
        apiId: _creds['api_id'] ?? '',
        apiHash: _creds['api_hash'] ?? '',
        session: _creds['session'] ?? '',
        channel: channel,
      );
      if (!mounted) return;
      if (result['status'] == 'ok') {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _channels.add(data);
          _addCtrl.clear();
        });
      } else {
        setState(() => _addError = result['error']?.toString() ?? 'Canal introuvable');
      }
    } catch (e) {
      if (mounted) setState(() => _addError = e.toString());
    } finally {
      if (mounted) setState(() => _addLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _channels.where((c) {
      if (_query.isEmpty) return true;
      final t = (c['title'] as String? ?? '').toLowerCase();
      final u = (c['username'] as String? ?? '').toLowerCase();
      return t.contains(_query.toLowerCase()) || u.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: _tgBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2733),
        foregroundColor: _tgText,
        elevation: 0.5,
        shadowColor: _tgBorder,
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _tgBlue, size: 20),
            SizedBox(width: 8),
            Text('Telegram', style: TextStyle(color: _tgText, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _tgBlue),
            tooltip: 'Ajouter un canal',
            onPressed: _showAddDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _tgHint),
            color: _tgCard,
            onSelected: (v) { if (v == 'logout') _logout(); },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: _tgError, size: 18),
                    SizedBox(width: 8),
                    Text('Déconnexion', style: TextStyle(color: _tgError)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: _tgText, fontSize: 15),
                cursorColor: _tgBlue,
                decoration: const InputDecoration(
                  hintText: 'Rechercher un canal',
                  hintStyle: TextStyle(color: _tgHint),
                  prefixIcon: Icon(Icons.search_rounded, color: _tgHint, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          Expanded(
            child: _channels.isEmpty
                ? _emptyState()
                : filtered.isEmpty
                    ? Center(child: Text('Aucun résultat', style: TextStyle(color: _tgHint)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 0.5, thickness: 0.5, indent: 72,
                          color: _tgBorder.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (ctx, i) => _ChannelTile(
                          data: filtered[i],
                          onTap: () => _showChannelSheet(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.send_rounded, color: _tgBorder, size: 64),
          const SizedBox(height: 16),
          const Text('Aucun canal ajouté', style: TextStyle(color: _tgText, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Appuyez sur + pour ajouter un canal Telegram comme source de contenu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _tgHint, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          _TgButton(label: 'Ajouter un canal', onTap: _showAddDialog),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context, backgroundColor: _tgCard, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajouter un canal', style: TextStyle(color: _tgText, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _addCtrl,
                autofocus: true,
                style: const TextStyle(color: _tgText),
                cursorColor: _tgBlue,
                decoration: InputDecoration(
                  hintText: '@nom_du_canal',
                  hintStyle: const TextStyle(color: _tgHint),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: _tgHint, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0E1621),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) async {
                  await _addChannel();
                  if (mounted) Navigator.pop(ctx);
                },
              ),
              if (_addError != null) ...[
                const SizedBox(height: 8),
                Text(_addError!, style: const TextStyle(color: _tgError, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addLoading ? null : () async {
                    await _addChannel();
                    if (mounted && _addError == null) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tgBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _addLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChannelSheet(Map<String, dynamic> ch) {
    showModalBottomSheet(
      context: context, backgroundColor: _tgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36, backgroundColor: _tgBlue,
              child: Text(
                ((ch['title'] as String? ?? '?')[0]).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(ch['title'] as String? ?? '', style: const TextStyle(color: _tgText, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(ch['username'] as String? ?? '', style: const TextStyle(color: _tgBlue, fontSize: 14)),
            if ((ch['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ch['description'] as String? ?? '', style: const TextStyle(color: _tgHint, fontSize: 13), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Utiliser comme source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tgBlue, foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _channels.removeWhere((c) => c['id'] == ch['id']));
                  Navigator.pop(ctx);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tgError, side: const BorderSide(color: _tgError),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retirer ce canal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _ChannelTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '?';
    final username = data['username'] as String? ?? '';
    final subs = data['subscribers'] as int?;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26, backgroundColor: _tgBlue,
                child: Text(title[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _tgText, fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      subs != null ? '$username · ${_fmt(subs)} abonnés' : username,
                      style: const TextStyle(color: _tgHint, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _tgHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═════════════════════════════════════════════════════════════════════════════

class _LoginShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onBack;
  const _LoginShell({required this.child, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tgBg,
      appBar: AppBar(
        backgroundColor: _tgBg, foregroundColor: _tgText, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onBack),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: _tgBlue, size: 20),
            SizedBox(width: 8),
            Text('Telegram', style: TextStyle(color: _tgText)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _TgField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _TgField({
    required this.ctrl, required this.label, required this.hint,
    this.obscure = false, this.suffix, this.keyboardType, this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: _tgText, fontSize: 16),
      cursorColor: _tgBlue,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: _tgHint),
        hintStyle: const TextStyle(color: _tgHint),
        suffixIcon: suffix,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _tgBorder)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _tgBlue, width: 2)),
      ),
    );
  }
}

class _TgButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  const _TgButton({required this.label, this.onTap, this.loading = false, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity, height: 50,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: _tgBlue, side: const BorderSide(color: _tgBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _tgBlue))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
    }
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _tgBlue, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
