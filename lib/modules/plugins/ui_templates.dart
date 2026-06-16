import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';

  // Template "downloader" embarqué dans Watchtower.
  // Utilisé par ManifestUiRenderer quand manifest.json déclare "template": "downloader".
  // Fournit l'ossature visuelle type downloader (URL + qualité + format + progression).
  // Le schema.json du plugin surcharge les champs/labels/options de ce template.

  const Color _bg     = Color(0xFF0F0F0F);
  const Color _card   = Color(0xFF1A1A1A);
  const Color _border = Color(0xFF2A2A2A);
  const Color _grey   = Color(0xFF888888);

  class DownloaderTemplate extends StatelessWidget {
    final String title;
    final Color accentColor;
    final Widget urlField;
    final List<Widget> chips;
    final List<Widget> toggles;
    final List<Widget> actions;
    final Widget? outputZone;

    const DownloaderTemplate({
      required this.title,
      required this.accentColor,
      required this.urlField,
      required this.chips,
      required this.toggles,
      required this.actions,
      this.outputZone,
      super.key,
    });

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(title, style: GoogleFonts.inter(
            fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            urlField,
            const SizedBox(height: 16),
            ...chips,
            if (toggles.isNotEmpty) ...[const SizedBox(height: 16), ...toggles],
            const SizedBox(height: 8),
            Divider(color: _border, height: 32),
            ...actions,
            if (outputZone != null) ...[const SizedBox(height: 16), outputZone!],
          ],
        ),
      );
    }
  }

  // ── Template "browser" ─────────────────────────────────────────────────────

  class BrowserTemplate extends StatelessWidget {
    final String title;
    final Widget searchBar;
    final Widget resultList;
    final Color accentColor;

    const BrowserTemplate({
      required this.title,
      required this.searchBar,
      required this.resultList,
      required this.accentColor,
      super.key,
    });

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg, elevation: 0, scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(14), child: searchBar),
          Expanded(child: resultList),
        ]),
      );
    }
  }

  // ── Template "sync" ────────────────────────────────────────────────────────

  class SyncTemplate extends StatelessWidget {
    final String title;
    final List<Widget> fields;
    final List<Widget> toggles;
    final Widget primaryAction;
    final Widget? secondaryAction;
    final Color accentColor;

    const SyncTemplate({
      required this.title,
      required this.fields,
      required this.toggles,
      required this.primaryAction,
      this.secondaryAction,
      required this.accentColor,
      super.key,
    });

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg, elevation: 0, scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            ...fields,
            if (toggles.isNotEmpty) ...[
              Divider(color: _border, height: 32),
              ...toggles,
            ],
            Divider(color: _border, height: 32),
            primaryAction,
            if (secondaryAction != null) ...[const SizedBox(height: 10), secondaryAction!],
          ],
        ),
      );
    }
  }