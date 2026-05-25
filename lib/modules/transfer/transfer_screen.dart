import 'package:flutter/material.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _bg = Color(0xFF0E0E0E);
  static const _teal = Color(0xFF1DB954);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Transfert',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildChipTabBar(),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMovieBoxTab(),
                _buildLocalFilesTab(),
                _buildReceivedTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(context),
    );
  }

  Widget _buildChipTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return Row(
            children: [
              _chipTab(0, 'MovieBox'),
              const SizedBox(width: 8),
              _chipTab(1, 'Fichiers locaux'),
              const SizedBox(width: 8),
              _chipTab(2, 'Reçu'),
            ],
          );
        },
      ),
    );
  }

  Widget _chipTab(int index, String label) {
    final selected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.white : Colors.white38,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMovieBoxTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildBoxIcon(),
          const SizedBox(height: 24),
          const Text(
            'Vos téléchargements apparaîtront ici',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF444444)),
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF1A1A1A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Trouvez plus de sources gratuites',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLocalFilesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 72, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 20),
          const Text(
            'Aucun fichier local',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les fichiers envoyés depuis un autre appareil\napparaîtront ici',
            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done_outlined,
              size: 72, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 20),
          const Text(
            'Aucun fichier reçu',
            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les contenus reçus d\'un autre appareil\napparaîtront ici',
            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBoxIcon() {
    return SizedBox(
      width: 130,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.04),
                  blurRadius: 40,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          Positioned(
            top: 10,
            right: 20,
            child: Icon(Icons.wifi_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.3)),
          ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Icon(Icons.diamond_outlined,
                size: 12, color: Colors.white.withValues(alpha: 0.2)),
          ),
          Positioned(
            bottom: 14,
            right: 14,
            child: Icon(Icons.diamond_outlined,
                size: 10, color: Colors.white.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: _GradientButton(
                label: 'Envoyer',
                icon: Icons.send_rounded,
                onTap: () => _showSendSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GradientButton(
                label: 'Recevoir',
                icon: Icons.download_rounded,
                onTap: () => _showReceiveSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comment transférer ?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Assurez-vous que les deux appareils sont sur le même réseau Wi-Fi.\n'
              '2. Ouvrez Watchtower sur l\'appareil destinataire et appuyez sur Recevoir.\n'
              '3. Sur cet appareil, appuyez sur Envoyer et sélectionnez les fichiers.',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSendSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun appareil trouvé',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Assurez-vous que l\'appareil destinataire a ouvert l\'écran Recevoir sur le même réseau Wi-Fi.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showReceiveSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 12),
            const Icon(Icons.wifi_tethering, color: _teal, size: 48),
            const SizedBox(height: 12),
            const Text(
              'En attente d\'envoi',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Cet appareil est visible sur le réseau local. Envoyez depuis l\'autre appareil.',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1DB954), Color(0xFF17A349)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
