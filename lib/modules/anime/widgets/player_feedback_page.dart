import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Page feedback/signalement pour le lecteur vidéo.
/// Remplace l'ancienne page Aide — affichée via le bouton ❓ en haut à droite.
class PlayerFeedbackPage extends StatefulWidget {
  const PlayerFeedbackPage({super.key});

  @override
  State<PlayerFeedbackPage> createState() => _PlayerFeedbackPageState();
}

class _PlayerFeedbackPageState extends State<PlayerFeedbackPage> {
  static const _kBg = Color(0xFF0F0F1A);
  static const _kCard = Color(0xFF1A1A2E);
  static const _kAccent = Color(0xFF7986CB);
  static const _kBorder = Color(0x1AFFFFFF);
  static const _kGrey = Color(0xFF8A8A9A);

  static const List<_Category> _categories = [
    _Category(Icons.play_circle_outline_rounded, 'Expérience de visionnage',
        'Buffering, qualité, son, plein écran…'),
    _Category(Icons.subtitles_rounded, 'Sous-titres',
        'Décalage, traduction, affichage…'),
    _Category(Icons.download_rounded, 'Téléchargement',
        'Erreur, lenteur, espace disque…'),
    _Category(Icons.folder_open_rounded, 'Gestion des fichiers',
        'Bibliothèque, organisation, import…'),
    _Category(Icons.warning_amber_rounded, 'Contenu problématique',
        'Signalement, violation de droits…'),
    _Category(Icons.bug_report_rounded, 'Bug ou crash',
        'L\'application s\'est fermée ou bloquée'),
    _Category(Icons.more_horiz_rounded, 'Autre', ''),
  ];

  int _selectedIndex = 0;
  final _descCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _kAccent.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Text(
          'Merci pour votre retour !',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _openGitHub() async {
    final cat = _categories[_selectedIndex].label;
    final body = Uri.encodeComponent(
      '**Catégorie** : $cat\n\n**Description**\n${_descCtrl.text.trim().isEmpty ? '—' : _descCtrl.text.trim()}\n\n---\n*Signalé depuis Watchtower — Player*',
    );
    final uri = Uri.parse(
      'https://github.com/ferelking242/watchtower/issues/new?labels=bug&title=${Uri.encodeComponent('[Player] $cat')}&body=$body',
    );
    if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir GitHub')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Signaler un problème',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Question ──────────────────────────────────────────────────
              const Text(
                'Sur quoi portez-vous vos commentaires ?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // ── Catégories ────────────────────────────────────────────────
              ...List.generate(_categories.length, (i) {
                final cat = _categories[i];
                final sel = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel
                          ? _kAccent.withValues(alpha: 0.14)
                          : _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? _kAccent.withValues(alpha: 0.55)
                            : _kBorder,
                        width: sel ? 1.0 : 0.6,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: sel
                                ? _kAccent.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(cat.icon,
                              color: sel ? _kAccent : _kGrey, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.label,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              if (cat.hint.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  cat.hint,
                                  style: const TextStyle(
                                    color: _kGrey,
                                    fontSize: 11.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? _kAccent : _kGrey,
                              width: 2,
                            ),
                            color: sel ? _kAccent : Colors.transparent,
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  size: 10, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // ── Description ───────────────────────────────────────────────
              const Text(
                'Description (optionnel)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        'Décrivez le problème en quelques mots…',
                    hintStyle: TextStyle(color: _kGrey, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Boutons ───────────────────────────────────────────────────
              Row(
                children: [
                  // GitHub
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openGitHub,
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('GitHub'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGrey,
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Envoyer
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _kAccent.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Envoyer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Category {
  final IconData icon;
  final String label;
  final String hint;
  const _Category(this.icon, this.label, this.hint);
}
