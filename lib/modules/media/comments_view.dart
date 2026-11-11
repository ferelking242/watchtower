import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/widgets/zoomable_image_viewer.dart';
import 'package:watchtower/services/isolate_service.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/cached_network.dart';

/// One media attachment inside a comment (image or short video). Extensions
/// hand these over as plain URLs plus an optional type hint.
class CommentMedia {
  final String url;

  /// `image` or `video`; anything else falls back to `image`.
  final String kind;
  final String? thumb;

  const CommentMedia({required this.url, this.kind = 'image', this.thumb});

  bool get isVideo => kind == 'video';
}

/// A comment (and its replies) rendered by [CommentsSection]. Built from the
/// raw map an extension `getComments()` returns; the common key spellings are
/// accepted so a source that names its fields differently still renders fully.
class CommentItem {
  final String id;
  final String author;
  final String? avatarUrl;
  final String timeAgo;
  final String body;
  final List<CommentMedia> media;
  int likes;
  bool liked;
  bool collapsed;
  final List<CommentItem> replies;

  CommentItem({
    required this.id,
    required this.author,
    this.avatarUrl,
    required this.timeAgo,
    required this.body,
    this.media = const [],
    this.likes = 0,
    this.liked = false,
    this.collapsed = false,
    List<CommentItem>? replies,
  }) : replies = replies ?? [];

  factory CommentItem.fromJson(Map<String, dynamic> m, {int depth = 0}) {
    final author = (m['author'] ?? m['name'] ?? m['user'] ?? 'Anonyme')
        .toString()
        .trim();
    final avatar = (m['avatar'] ?? m['avatarUrl'] ?? m['image'] ?? m['userImage'])
        ?.toString()
        .trim();
    final date = (m['date'] ?? m['time_diff'] ?? m['timeAgo'] ?? '').toString();
    final scoreVal = m['score'] ?? m['votes'] ?? m['likes'];
    final score = scoreVal is num ? scoreVal.toInt() : 0;

    final media = <CommentMedia>[];
    void addMedia(Object? raw, [String? kind, String? thumb]) {
      if (raw is String && raw.trim().isNotEmpty) {
        media.add(CommentMedia(
          url: raw.trim(),
          kind: kind ?? 'image',
          thumb: thumb,
        ));
      }
    }

    for (final key in const ['images', 'medias', 'attachments']) {
      final list = m[key];
      if (list is List) {
        for (final e in list) {
          if (e is Map) {
            addMedia(e['url'] ?? e['src'] ?? e['image'], e['type']?.toString());
          } else {
            addMedia(e);
          }
        }
      }
    }
    addMedia(m['imageUrl'], 'image', m['thumb']?.toString());
    addMedia(m['videoUrl'] ?? m['video'], 'video', m['thumb']?.toString());

    final replies = <CommentItem>[];
    final rawReplies = m['replies'] ?? m['children'];
    if (depth < 8 && rawReplies is List) {
      for (final r in rawReplies) {
        if (r is Map) {
          replies.add(CommentItem.fromJson(
            Map<String, dynamic>.from(r),
            depth: depth + 1,
          ));
        }
      }
    }

    return CommentItem(
      id: '$author$date${m['id'] ?? ''}',
      author: author.isEmpty ? 'Anonyme' : author,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      timeAgo: date,
      body: (m['content'] ?? m['message'] ?? m['body'] ?? '').toString().trim(),
      media: media,
      likes: score,
      replies: replies,
    );
  }

  int get totalCount =>
      1 + replies.fold<int>(0, (sum, r) => sum + r.totalCount);
}

/// Inline comments UI shared by the manga and video detail pages.
///
/// Comments render directly on the page (avatars, replies and attached
/// media), never behind a WebView: the source's `getComments()` runs through
/// the isolate service and the results are drawn with the shared components.
class CommentsSection extends StatefulWidget {
  final String url;
  final Source? source;

  /// When false the section stays idle until [autoLoad] turns true — the
  /// manga detail tab loads lazily so a hidden tab never occupies the source's
  /// single non-reentrant runtime.
  final bool autoLoad;

  const CommentsSection({
    super.key,
    required this.url,
    this.source,
    this.autoLoad = true,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  List<CommentItem> _comments = [];
  bool _loading = true;
  bool _failed = false;
  String _sortMode = 'best';

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) _load();
  }

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoLoad && !oldWidget.autoLoad && _comments.isEmpty) {
      _load();
    }
  }

  Future<void> _load() async {
    final src = widget.source;
    if (src == null || widget.url.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final raw = await getIsolateService.get<List<dynamic>>(
        url: widget.url,
        source: src,
        serviceType: 'getComments',
      );
      if (!mounted) return;
      final mapped = raw
          .whereType<Map>()
          .map((e) => CommentItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      setState(() {
        _comments = mapped;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = [];
        _loading = false;
        _failed = true;
      });
    }
  }

  void _applySort() {
    setState(() {
      if (_sortMode == 'recent') {
        _comments.sort((a, b) => b.timeAgo.compareTo(a.timeAgo));
      } else {
        _comments.sort((a, b) => b.likes.compareTo(a.likes));
      }
    });
  }

  void _toggleLike(CommentItem c) {
    setState(() {
      c.liked = !c.liked;
      c.likes += c.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final total = _comments.fold<int>(0, (sum, c) => sum + c.totalCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
          child: Row(
            children: [
              Text(
                '$total commentaires',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              AdaptiveOverlayMenu<String>(
                icon: Icon(
                  Broken.sort,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                menuWidth: 200,
                initialValue: _sortMode,
                onSelected: (value) {
                  _sortMode = value;
                  _applySort();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'best', child: Text('Meilleures')),
                  PopupMenuItem(value: 'recent', child: Text('Récents')),
                ],
              ),
            ],
          ),
        ),
        if (_failed || _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              children: [
                Icon(
                  Broken.message,
                  size: 34,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 10),
                Text(
                  _failed
                      ? 'Impossible de charger les commentaires.'
                      : 'Aucun commentaire pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                if (_failed) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          )
        else
          for (final comment in _comments)
            _CommentTile(
              comment: comment,
              depth: 0,
              onLike: _toggleLike,
              onChanged: () => setState(() {}),
            ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentItem comment;
  final int depth;
  final void Function(CommentItem) onLike;
  final VoidCallback onChanged;

  static const _kDepthColors = [
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
  ];

  const _CommentTile({
    required this.comment,
    required this.depth,
    required this.onLike,
    required this.onChanged,
  });

  Color get _threadColor => _kDepthColors[depth % _kDepthColors.length];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final indent = depth * 16.0;
    final grey = scheme.onSurfaceVariant;
    final faint = scheme.outlineVariant.withValues(alpha: 0.6);
    return Padding(
      padding: EdgeInsets.only(left: indent, top: depth == 0 ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (depth > 0)
                  GestureDetector(
                    onTap: () {
                      comment.collapsed = !comment.collapsed;
                      onChanged();
                    },
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _threadColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: 16, bottom: depth == 0 ? 0 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _CommentAvatar(
                              author: comment.author,
                              avatarUrl: comment.avatarUrl,
                              size: depth == 0 ? 30 : 24,
                              accent: _threadColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      comment.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: depth == 0 ? 13 : 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    comment.timeAgo,
                                    style:
                                        TextStyle(color: grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                comment.collapsed = !comment.collapsed;
                                onChanged();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  comment.collapsed
                                      ? Icons.expand_more_rounded
                                      : Icons.expand_less_rounded,
                                  color: grey,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!comment.collapsed) ...[
                          if (comment.body.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              comment.body,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.88),
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                          if (comment.media.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _CommentMediaGrid(
                              media: comment.media,
                              accent: _threadColor,
                              faint: faint,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => onLike(comment),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      comment.liked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
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
                              if (comment.replies.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _threadColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          _threadColor.withValues(alpha: 0.30),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    '${comment.replies.length} réponse'
                                    '${comment.replies.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: _threadColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (depth == 0 && comment.replies.isEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: faint),
                          ],
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            '${comment.replies.length} réponse'
                            '${comment.replies.length > 1 ? 's' : ''} masquée'
                            '${comment.replies.length > 1 ? 's' : ''}',
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
          if (!comment.collapsed)
            for (final reply in comment.replies)
              _CommentTile(
                comment: reply,
                depth: depth + 1,
                onLike: onLike,
                onChanged: onChanged,
              ),
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

class _CommentMediaGrid extends StatelessWidget {
  final List<CommentMedia> media;
  final Color accent;
  final Color faint;

  const _CommentMediaGrid({
    required this.media,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    final single = media.length == 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 80;
        final itemWidth = single ? fullWidth : (fullWidth - 6) / 2;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in single ? media : media.take(4))
              SizedBox(
                width: itemWidth,
                child: _CommentMediaThumb(media: m, accent: accent, faint: faint),
              ),
          ],
        );
      },
    );
  }
}

class _CommentMediaThumb extends StatelessWidget {
  final CommentMedia media;
  final Color accent;
  final Color faint;

  const _CommentMediaThumb({
    required this.media,
    required this.accent,
    required this.faint,
  });

  @override
  Widget build(BuildContext context) {
    final previewUrl =
        media.thumb != null && media.thumb!.isNotEmpty ? media.thumb! : media.url;
    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              cachedNetworkImage(
                imageUrl: previewUrl,
                width: null,
                height: null,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: faint,
                  child: Icon(
                    media.isVideo
                        ? Icons.videocam_off_outlined
                        : Icons.image_not_supported_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
              ),
              if (media.isVideo)
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (media.isVideo) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        builder: (dialogContext) => GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Vidéo du commentaire',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.url,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }
    showZoomableImage(
      context,
      imageProvider: ExtendedNetworkImageProvider(media.url),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  final String author;
  final String? avatarUrl;
  final double size;
  final Color accent;

  const _CommentAvatar({
    required this.author,
    this.avatarUrl,
    required this.size,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final border =
        Border.all(color: accent.withValues(alpha: 0.40), width: 1.5);
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.18),
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: cachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: _initials(border),
        ),
      );
    }
    return _initials(border);
  }

  Widget _initials([BoxBorder? border]) {
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
        border: border ??
            Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
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
