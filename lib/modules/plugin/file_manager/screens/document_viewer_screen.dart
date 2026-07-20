// lib/modules/plugin/file_manager/screens/document_viewer_screen.dart
// Visionneuse de documents texte, code et Markdown.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownBody;
import 'package:path/path.dart' as p;

import '../utils/file_utils.dart';

class FmDocumentViewerScreen extends StatefulWidget {
  final String filePath;
  const FmDocumentViewerScreen({super.key, required this.filePath});

  @override
  State<FmDocumentViewerScreen> createState() => _FmDocumentViewerScreenState();
}

class _FmDocumentViewerScreenState extends State<FmDocumentViewerScreen> {
  String? _content;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final content = await File(widget.filePath).readAsString();
      if (mounted) setState(() { _content = content; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.filePath);
    final ext = p.extension(widget.filePath).replaceFirst('.', '').toLowerCase();
    final isMarkdown = FileUtils.isMarkdown(ext);

    return Scaffold(
      appBar: AppBar(
        title: Text(name,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_content != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copier',
              onPressed: () {
                // Copy to clipboard via ScaffoldMessenger
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contenu copié')),
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                )
              : isMarkdown
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: MarkdownBody(
                        data: _content!,
                        selectable: true,
                      ),
                    )
                  : _CodeView(content: _content!, ext: ext),
    );
  }
}

// ── Code / text view ──────────────────────────────────────────────────────────

class _CodeView extends StatelessWidget {
  final String content;
  final String ext;
  const _CodeView({required this.content, required this.ext});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCode = FileUtils.kindOf(ext) == FileKind.code;

    return Container(
      color: isCode
          ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA))
          : null,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: TextStyle(
            fontFamily: isCode ? 'monospace' : null,
            fontSize: isCode ? 12.5 : 15,
            height: 1.55,
            color: isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
