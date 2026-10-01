import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/widgets/shimmer_skeleton.dart';

/// A single comment (with its nested replies) as returned by the extension
/// `getComments` service.
class MediaComment {
  final String id;
  final String author;
  final String timeAgo;
  final String body;
  int likes;
  bool liked;
  bool collapsed;
  final List<MediaComment> replies;

  MediaComment({
    required this.id,
    required this.author,
    required this.timeAgo,
    required this.body,
    this.likes = 0,
    this.liked = false,
    this.collapsed = false,
    List<MediaComment>? replies,
  }) : replies = replies ?? [];
}

// ─── COMMENTS SECTION ────────────────────────────────────────────────────────

/// Extension-backed comments list shared by the Watch (anime) and Manga
/// detail screens.
///
/// Loads real comments through the `getComments` isolate service and renders
/// loading (shimmer skeleton), error (with retry), empty and list states.
class CommentsSection extends StatefulWidget {
  final String url;
  final String title;
  final Source? source;
  final Color accent;
  final Color bg;
  final Color card;
  final Color onSurface;
  final Color grey;
  final Color faint;
  final Color textPrimary;

  /// When false the section renders as a plain column meant to live inside an
  /// outer scroll view (Manga details page). When true it owns its own
  /// viewport (Watch detail tab).
  final bool scrollable;

  /// Optional bridge shown in the empty state (e.g. open the WebView).
  final String? emptyActionLabel;
  final VoidCallback? emptyAction;

  const CommentsSection({
    super.key,
    required this.url,
    required this.title,
    this.source,
    required this.accent,
    required this.bg,
    required this.card,
    required this.onSurface,
    required this.grey,
    required this.faint,
    required this.textPrimary,
    this.scrollable = true,
    this.emptyActionLabel,
    this.emptyAction,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  List<MediaComment> _comments = [];
  bool _loading = true;
  bool _error = false;
  final _replyController = TextEditingController();
  final _commentController = TextEditingController();
  String _sortMode = 'Meilleures';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    final src = widget.source;
    if (src == null) {
      if (!mounted) return;
      setState(() {
        _comments = [];
        _loading = false;
      });
      return;
    }
    try {
      final raw = await getIsolateService.get<List<dynamic>>(
        url: widget.url,
        source: src,
        serviceType: 'getComments',
        proxyServer: '',
      );
      if (!mounted) return;
      final mapped = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final sv = m['score'];
        final sc = sv is num ? sv.toDouble() : -1.0;
        final dt = (m['date'] as String?) ?? '';
        return MediaComment(
          id: '${(m['author'] ?? 'anon') as String}$dt',
          author: (m['author'] as String?) ?? 'Anonyme',
          timeAgo: dt,
          body:
              ((m['content'] as String?) ?? '').trim() +
              (sc > 0 ? '  ★${sc.toStringAsFixed(1)}' : ''),
        );
      }).toList();
      setState(() {
        _comments = mapped;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = [];
        _loading = false;
        _error = true;
      });
    }
  }

  void _toggleLike(MediaComment comment) {
    setState(() {
      if (comment.liked) {
        comment.likes--;
        comment.liked = false;
      } else {
        comment.likes++;
        comment.liked = true;
      }
    });
  }

  Widget _wrapViewport(Widget child) {
    if (!widget.scrollable) return child;
    return Expanded(child: child);
  }

  Widget _stateBlock({required Widget child}) {
    if (!widget.scrollable) return child;
    return Expanded(child: Center(child: child));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CommentsSkeleton();
    }

    final total = _comments.fold<int>(
      0,
      (sum, c) =>
          sum + 1 + c.replies.fold<int>(0, (s, r) => s + 1 + r.replies.length),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Text(
                '$total commentaires',
                style: TextStyle(
                  color: widget.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _sortMode = _sortMode == 'Meilleures'
                        ? 'Récents'
                        : 'Meilleures';
                    if (_sortMode == 'Récents') {
                      _comments.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
                    } else {
                      _comments.sort((a, b) => b.likes.compareTo(a.likes));
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: widget.faint, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Broken.sort, size: 13, color: widget.grey),
                      const SizedBox(width: 4),
                      Text(
                        _sortMode,
                        style: TextStyle(color: widget.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Write comment bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => _showWriteCommentSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: widget.faint, width: 0.8),
              ),
              child: Row(
                children: [
                  CommentAvatar(
                    author: 'Moi',
                    size: 26,
                    accent: widget.accent,
                    isLight: false,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ajouter un commentaire…',
                    style: TextStyle(color: widget.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: widget.faint),
        // Comment list / states
        if (_error)
          _stateBlock(
            child: _messageBlock(
              icon: Broken.danger,
              message: 'Impossible de charger les commentaires.',
              actionLabel: 'Réessayer',
              onAction: _loadComments,
            ),
          )
        else if (_comments.isEmpty)
          _stateBlock(
            child: _messageBlock(
              icon: Broken.message,
              message: 'Aucun commentaire pour le moment.',
              actionLabel: widget.emptyActionLabel,
              onAction: widget.emptyAction,
            ),
          )
        else
          _wrapViewport(
            ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              shrinkWrap: !widget.scrollable,
              physics: !widget.scrollable
                  ? const NeverScrollableScrollPhysics()
                  : null,
              itemCount: _comments.length,
              itemBuilder: (ctx, i) => CommentTile(
                comment: _comments[i],
                depth: 0,
                accent: widget.accent,
                bg: widget.bg,
                card: widget.card,
                grey: widget.grey,
                faint: widget.faint,
                textPrimary: widget.textPrimary,
                onLike: _toggleLike,
                onReply: (c) => _showWriteCommentSheet(ctx, replyTo: c),
                onCollapse: (_) => setState(() {}),
              ),
            ),
          ),
      ],
    );
  }

  Widget _messageBlock({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: widget.grey.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.grey, fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(color: widget.accent, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showWriteCommentSheet(BuildContext ctx, {MediaComment? replyTo}) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.faint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (replyTo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: widget.accent, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          replyTo.author,
                          style: TextStyle(
                            color: widget.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyTo.body,
                          style: TextStyle(color: widget.grey, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CommentAvatar(
                      author: 'Moi',
                      size: 32,
                      accent: widget.accent,
                      isLight: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        autofocus: true,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(
                          color: widget.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: replyTo != null
                              ? 'Répondre à ${replyTo.author}…'
                              : 'Votre commentaire…',
                          hintStyle: TextStyle(color: widget.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          if (replyTo != null) {
                            replyTo.replies.add(
                              MediaComment(
                                id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                                author: 'Moi',
                                timeAgo: 'à l\'instant',
                                body: text,
                              ),
                            );
                          } else {
                            _comments.insert(
                              0,
                              MediaComment(
                                id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                                author: 'Moi',
                                timeAgo: 'à l\'instant',
                                body: text,
                              ),
                            );
                          }
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Broken.send,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── LOADING SKELETON ────────────────────────────────────────────────────────

/// Shimmer skeleton reproducing the geometry of a comment card
/// (avatar · username · text lines). Used both as the section loading state
/// and inside the Manga details page skeleton.
class CommentsSkeleton extends StatelessWidget {
  const CommentsSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      effect: shimmerEffectFor(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows; i++) const _CommentSkeletonRow(),
          ],
        ),
      ),
    );
  }
}

class _CommentSkeletonRow extends StatelessWidget {
  const _CommentSkeletonRow();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: 120,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 200,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
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

// ─── COMMENT TILE (recursive) ────────────────────────────────────────────────

class CommentTile extends StatelessWidget {
  final MediaComment comment;
  final int depth;
  final Color accent;
  final Color bg;
  final Color card;
  final Color grey;
  final Color faint;
  final Color textPrimary;
  final void Function(MediaComment) onLike;
  final void Function(MediaComment) onReply;
  final void Function(MediaComment) onCollapse;

  static const _kDepthColors = [
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
  ];

  const CommentTile({
    super.key,
    required this.comment,
    required this.depth,
    required this.accent,
    required this.bg,
    required this.card,
    required this.grey,
    required this.faint,
    required this.textPrimary,
    required this.onLike,
    required this.onReply,
    required this.onCollapse,
  });

  Color get _threadColor => _kDepthColors[depth % _kDepthColors.length];

  @override
  Widget build(BuildContext context) {
    final indent = depth * 16.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: depth == 0 ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line + content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thread line (only for replies)
                if (depth > 0) ...[
                  GestureDetector(
                    onTap: () {
                      comment.collapsed = !comment.collapsed;
                      onCollapse(comment);
                    },
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _threadColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                ],
                // Comment body
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 16,
                      bottom: depth == 0 ? 0 : 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author row
                        Row(
                          children: [
                            CommentAvatar(
                              author: comment.author,
                              size: depth == 0 ? 30 : 24,
                              accent: _threadColor,
                              isLight: false,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    comment.author,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: depth == 0 ? 13 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.timeAgo,
                                    style: TextStyle(color: grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Collapse toggle
                            GestureDetector(
                              onTap: () {
                                comment.collapsed = !comment.collapsed;
                                onCollapse(comment);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  comment.collapsed
                                      ? Broken.arrow_down
                                      : Broken.arrow_up_3,
                                  color: grey,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!comment.collapsed) ...[
                          const SizedBox(height: 6),
                          // Body
                          Text(
                            comment.body,
                            style: TextStyle(
                              color: textPrimary.withValues(alpha: 0.88),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Action bar
                          Row(
                            children: [
                              // Like
                              GestureDetector(
                                onTap: () => onLike(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Broken.heart,
                                      color: comment.liked
                                          ? const Color(0xFFEF4444)
                                          : grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${comment.likes}',
                                      style: TextStyle(
                                        color: comment.liked
                                            ? const Color(0xFFEF4444)
                                            : grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Reply
                              GestureDetector(
                                onTap: () => onReply(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Broken.send, color: grey, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Répondre',
                                      style: TextStyle(
                                        color: grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Replies count badge
                              if (comment.replies.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _threadColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _threadColor.withValues(
                                        alpha: 0.30,
                                      ),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: _threadColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Divider for top-level comments
                          if (depth == 0 && comment.replies.isEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: faint),
                          ],
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            '${comment.replies.length} réponse${comment.replies.length > 1 ? 's' : ''} cachée${comment.replies.length > 1 ? 's' : ''}',
                            style: TextStyle(color: grey, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Nested replies
          if (!comment.collapsed)
            for (final reply in comment.replies)
              CommentTile(
                comment: reply,
                depth: depth + 1,
                accent: accent,
                bg: bg,
                card: card,
                grey: grey,
                faint: faint,
                textPrimary: textPrimary,
                onLike: onLike,
                onReply: onReply,
                onCollapse: onCollapse,
              ),
          // Separator for top-level with replies
          if (depth == 0 && comment.replies.isNotEmpty && !comment.collapsed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(height: 1, color: faint),
            ),
        ],
      ),
    );
  }
}

// ─── COMMENT AVATAR ──────────────────────────────────────────────────────────

class CommentAvatar extends StatelessWidget {
  final String author;
  final double size;
  final Color accent;
  final bool isLight;

  const CommentAvatar({
    super.key,
    required this.author,
    required this.size,
    required this.accent,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final initials = author.isEmpty
        ? '?'
        : author
              .trim()
              .split(' ')
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .take(2)
              .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: accent,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
