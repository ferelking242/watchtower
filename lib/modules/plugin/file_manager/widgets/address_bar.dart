// lib/modules/plugin/file_manager/widgets/address_bar.dart
// Barre d'adresse breadcrumb pour le gestionnaire de fichiers.

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class AddressBar extends StatefulWidget {
  final String currentPath;
  final void Function(String path) onNavigate;

  const AddressBar({
    super.key,
    required this.currentPath,
    required this.onNavigate,
  });

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentPath);
  }

  @override
  void didUpdateWidget(AddressBar old) {
    super.didUpdateWidget(old);
    if (!_editing && old.currentPath != widget.currentPath) {
      _ctrl.text = widget.currentPath;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final path = _ctrl.text.trim();
    setState(() => _editing = false);
    widget.onNavigate(path);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_editing) {
      return Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_rounded, size: 18),
              onPressed: _submit,
              padding: EdgeInsets.zero,
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
      );
    }

    final segments = _buildSegments(widget.currentPath);

    return GestureDetector(
      onTap: () => setState(() {
        _editing = true;
        _ctrl.text = widget.currentPath;
      }),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: segments.length,
          separatorBuilder: (_, __) => Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.40),
          ),
          itemBuilder: (_, i) {
            final seg = segments[i];
            final isLast = i == segments.length - 1;
            return Center(
              child: GestureDetector(
                onTap: () => widget.onNavigate(seg.path),
                child: Text(
                  seg.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isLast ? FontWeight.w600 : FontWeight.w400,
                    color: isLast
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<_Segment> _buildSegments(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    final segments = <_Segment>[];
    var built = '';
    segments.add(_Segment(label: '/', path: '/'));
    for (final part in parts) {
      built = '$built/$part';
      segments.add(_Segment(label: part, path: built));
    }
    return segments;
  }
}

class _Segment {
  final String label;
  final String path;
  const _Segment({required this.label, required this.path});
}
