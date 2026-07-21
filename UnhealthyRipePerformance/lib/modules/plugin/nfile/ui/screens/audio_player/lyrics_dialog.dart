import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/icon_fonts/broken_icons.dart';
import '../../../providers/file_manager_provider.dart';
import '../../widgets/nfile_icon.dart';
import '../internal_file_picker_screen.dart';

class LrcLine {
  final Duration timestamp;
  final String text;

  LrcLine({required this.timestamp, required this.text});
}

class LyricsDialog extends StatefulWidget {
  final Player player;
  final String audioPath;
  final String title;
  final String artist;
  final Duration initialPosition;

  const LyricsDialog({
    super.key,
    required this.player,
    required this.audioPath,
    required this.title,
    required this.artist,
    required this.initialPosition,
  });

  @override
  State<LyricsDialog> createState() => _LyricsDialogState();
}

class _LyricsDialogState extends State<LyricsDialog> {
  List<LrcLine>? _lyrics;
  bool _isLoading = true;
  late final StreamSubscription<Duration> _positionSub;
  Duration _position = Duration.zero;
  final ScrollController _scrollController = ScrollController();
  int _activeIndex = -1;
  double _viewportHeight = 350.0;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _loadLyricsAutomatically();
    _positionSub = widget.player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        if (_lyrics != null && _lyrics!.isNotEmpty) {
          final newIdx = _getActiveIndex(pos, _lyrics!);
          if (newIdx != _activeIndex) {
            _activeIndex = newIdx;
            _scrollToActive();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyricsAutomatically() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final ext = p.extension(widget.audioPath);
      if (ext.isNotEmpty) {
        final lrcPath = widget.audioPath.substring(0, widget.audioPath.length - ext.length) + '.lrc';
        final file = File(lrcPath);
        if (await file.exists()) {
          final content = await _readLrcFile(lrcPath);
          if (content != null) {
            final lines = _parseLrc(content);
            if (lines.isNotEmpty) {
              setState(() {
                _lyrics = lines;
                _isLoading = false;
                _activeIndex = _getActiveIndex(_position, lines);
              });
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive(animate: false));
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading lyrics automatically: $e");
    }
    setState(() {
      _lyrics = null;
      _isLoading = false;
    });
  }

  Future<String?> _readLrcFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      try {
        return await file.readAsString(encoding: utf8);
      } catch (_) {
        return await file.readAsString(encoding: latin1);
      }
    } catch (e) {
      debugPrint("Error reading LRC file: $e");
      return null;
    }
  }

  List<LrcLine> _parseLrc(String content) {
    final List<LrcLine> lines = [];
    final regex = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matches = regex.allMatches(line);
      if (matches.isEmpty) continue;

      final textIndex = line.lastIndexOf(']') + 1;
      final text = line.substring(textIndex).trim();

      for (final match in matches) {
        final min = int.tryParse(match.group(1) ?? '') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '') ?? 0;
        final msStr = match.group(3) ?? '0';
        int ms = int.tryParse(msStr) ?? 0;
        if (msStr.length == 1) {
          ms *= 100;
        } else if (msStr.length == 2) {
          ms *= 10;
        }

        final timestamp = Duration(minutes: min, seconds: sec, milliseconds: ms);
        lines.add(LrcLine(timestamp: timestamp, text: text));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  int _getActiveIndex(Duration position, List<LrcLine> lines) {
    int index = -1;
    for (int i = 0; i < lines.length; i++) {
      if (position >= lines[i].timestamp) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _scrollToActive({bool animate = true}) {
    if (!mounted || _lyrics == null || _lyrics!.isEmpty || _activeIndex < 0) return;
    if (!_scrollController.hasClients) return;

    final double itemHeight = 60.0;
    final double targetScroll = (_activeIndex * itemHeight) - (_viewportHeight / 2) + (itemHeight / 2);

    if (animate) {
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  Future<void> _pickLrcManually() async {
    final fileManager = context.read<FileManagerProvider>();
    final fallbackRoot = fileManager.rootPath.isNotEmpty ? fileManager.rootPath : '/storage/emulated/0';

    final picked = await InternalFilePickerScreen.show(context, rootPath: fallbackRoot);
    if (picked != null && picked.isNotEmpty) {
      final path = picked.first;
      if (path.toLowerCase().endsWith('.lrc')) {
        final content = await _readLrcFile(path);
        if (content != null) {
          final lines = _parseLrc(content);
          if (lines.isNotEmpty) {
            setState(() {
              _lyrics = lines;
              _activeIndex = _getActiveIndex(_position, lines);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive(animate: false));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Lyrics loaded successfully', style: TextStyle(color: Colors.white)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          } else {
            _showErrorSnackBar('No valid lyrics lines found in chosen LRC file.');
          }
        } else {
          _showErrorSnackBar('Failed to read the chosen LRC file.');
        }
      } else {
        _showErrorSnackBar('Please select a valid file ending with .lrc');
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF131324).withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Broken.document, color: theme.colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // Content Area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                        ),
                      )
                    : _lyrics == null || _lyrics!.isEmpty
                        ? _buildNoLyricsView(theme)
                        : _buildLyricsListView(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoLyricsView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(Broken.music, size: 48, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Synchronized Lyrics Found',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Keep a .lrc file with the exact same name next to your song, or select it manually below.',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            icon: const Icon(Broken.document_upload, size: 18),
            label: const Text('Load LRC File', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _pickLrcManually,
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsListView(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: _viewportHeight / 2 - 30.0),
                itemCount: _lyrics!.length,
                itemBuilder: (context, idx) {
                  final line = _lyrics![idx];
                  final isSelected = idx == _activeIndex;

                  return GestureDetector(
                    onTap: () {
                      widget.player.seek(line.timestamp);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      height: 60.0,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Text(
                        line.text.isEmpty ? "♪" : line.text,
                        style: TextStyle(
                          color: isSelected ? theme.colorScheme.primary : Colors.white.withOpacity(0.4),
                          fontSize: isSelected ? 18 : 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          shadows: isSelected
                              ? [
                                  Shadow(
                                    color: theme.colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Footer message
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              width: double.infinity,
              color: Colors.black26,
              child: Text(
                'Tap a line to seek playback',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }
}
