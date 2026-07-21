import 'package:flutter/material.dart';

/// Full-screen help dialog for the video player.
/// Shows every gesture, button, and control with a clear description.
class PlayerHelpPage extends StatelessWidget {
  const PlayerHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
        decoration: BoxDecoration(
          color: const Color(0xEA151524),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6BC0).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFF7986CB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Aide — Lecteur vidéo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),

            // ── Content ──────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Gestes tactiles', [
                      _row(Icons.touch_app_rounded, 'Appui simple',
                          'Afficher / masquer les contrôles'),
                      _row(Icons.keyboard_double_arrow_left_rounded,
                          'Double tap — gauche',
                          'Reculer de N secondes'),
                      _row(Icons.keyboard_double_arrow_right_rounded,
                          'Double tap — droite',
                          'Avancer de N secondes'),
                      _row(Icons.swipe_up_rounded, 'Glisser ↕ gauche',
                          'Régler la luminosité'),
                      _row(Icons.swipe_up_rounded, 'Glisser ↕ droite',
                          'Régler le volume'),
                      _row(Icons.swipe_rounded, 'Glisser ↔ horizontal',
                          'Chercher dans la vidéo (prévisualisation)'),
                      _row(Icons.speed_rounded, 'Appui long',
                          'Vitesse ×2 temporaire (relâcher pour revenir)'),
                    ]),
                    const SizedBox(height: 20),
                    _section('Barre de progression', [
                      _row(Icons.drag_indicator_rounded, 'Glisser le curseur',
                          'Prévisualise la position sans interrompre la lecture'),
                      _row(Icons.check_circle_outline_rounded, 'Relâcher',
                          'Seeks vers la position sélectionnée'),
                      _row(Icons.info_outline_rounded, 'Aperçu',
                          'Montre la miniature, l\'heure cible et la durée restante'),
                    ]),
                    const SizedBox(height: 20),
                    _section('Contrôles centraux', [
                      _row(Icons.skip_previous_rounded, 'Épisode précédent',
                          'Passer à l\'épisode précédent'),
                      _row(Icons.replay_rounded, '−15 s',
                          'Reculer de 15 secondes'),
                      _row(Icons.play_circle_outline_rounded, 'Play / Pause',
                          'Lire ou mettre en pause la vidéo'),
                      _row(Icons.forward_rounded, '+15 s',
                          'Avancer de 15 secondes'),
                      _row(Icons.skip_next_rounded, 'Épisode suivant',
                          'Passer à l\'épisode suivant'),
                    ]),
                    const SizedBox(height: 20),
                    _section('Barre supérieure', [
                      _row(Icons.arrow_back_rounded, 'Retour',
                          'Quitter le lecteur'),
                      _row(Icons.format_list_bulleted_rounded, 'Épisodes',
                          'Afficher la liste des épisodes'),
                      _row(Icons.adaptive.share, 'Partager',
                          'Capturer une image et la partager / enregistrer'),
                      _row(Icons.help_outline_rounded, 'Aide',
                          'Afficher cette page'),
                    ]),
                    const SizedBox(height: 20),
                    _section('Barre inférieure', [
                      _row(Icons.video_settings_rounded, 'Piste vidéo',
                          'Qualité, sous-titres, piste audio'),
                      _row(Icons.language_rounded, 'Langue audio',
                          'Changer rapidement la piste audio'),
                      _row(Icons.speed_rounded, 'Vitesse',
                          'Régler la vitesse de lecture'),
                      _row(Icons.fit_screen_rounded, 'Ajustement',
                          'Contenu, couverture, largeur, hauteur…'),
                      _row(Icons.more_vert_rounded, 'Paramètres',
                          'Tous les paramètres du lecteur en un seul endroit'),
                      _row(Icons.fullscreen_rounded, 'Plein écran',
                          'Basculer le mode plein écran / portrait'),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7986CB),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 0.5,
                color: const Color(0xFF7986CB).withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  Widget _row(IconData icon, String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white60, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
