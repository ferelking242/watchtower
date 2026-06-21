import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/modules/library/library_screen.dart';
import 'package:watchtower/modules/library/providers/isar_providers.dart';
import 'package:watchtower/modules/library/widgets/library_dialogs.dart';
import 'package:watchtower/modules/library/widgets/library_settings_sheet.dart';
import 'package:watchtower/modules/library/widgets/search_text_form_field.dart';
import 'package:watchtower/modules/widgets/manga_image_card_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/library_updater.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/global_style.dart';

// Design tokens
const _kBg            = Color(0xFF0A0A0A);
const _kSurface       = Color(0xFF1A1A1A);
const _kBorder        = Color(0xFF333333);
const _kAccent        = Color(0xFFE91E63);
const _kTextPrimary   = Color(0xFFFFFFFF);
const _kTextSecondary = Color(0xFF999999);

class MainLibraryScreen extends ConsumerStatefulWidget {
  const MainLibraryScreen({super.key, this.presetInput, this.initialType});
  final String? presetInput;
  final ItemType? initialType;
  @override
  ConsumerState<MainLibraryScreen> createState() => _MainLibraryScreenState();
}

class _MainLibraryScreenState extends ConsumerState<MainLibraryScreen>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  bool _isSearch   = false;
  bool _isListView = true;
  late ItemType _currentType;
  final List<String> _categories = ['All', 'Webto', 'Denger'];
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType ?? ItemType.anime;
    _searchController = TextEditingController(text: widget.presetInput ?? '');
    if (widget.presetInput != null && widget.presetInput!.isNotEmpty) _isSearch = true;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterSheet(Settings settings) {
    final mangaAsync = ref.read(getAllMangaStreamProvider(categoryId: null, itemType: _currentType));
    final entries = mangaAsync.when(data: (v) => v, loading: () => <Manga>[], error: (_, __) => <Manga>[]);
    showLibrarySettingsSheet(context: context, vsync: this, settings: settings, itemType: _currentType, entries: entries);
  }

  // Circle button — transparent bg, circle border. No fill. Identique screenshot.
  Widget _circleBtn({required IconData icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: _kTextPrimary),
      ),
    );
  }

  // Toggle button inside the grouped view-picker pill
  Widget _toggleBtn({required IconData icon, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? _kAccent : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: _kTextPrimary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsStream = ref.watch(getSettingsStreamProvider);
    return settingsStream.when(
      data: (s) => _buildBody(s.first),
      loading: () => const Scaffold(backgroundColor: _kBg, body: Center(child: CircularProgressIndicator(color: _kAccent))),
      error: (e, _) => Scaffold(backgroundColor: _kBg, body: Center(child: Text(e.toString(), style: const TextStyle(color: _kTextPrimary)))),
    );
  }

  Widget _buildBody(Settings settings) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header — 56px
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title 'Library' — 32px bold
                    const Expanded(
                      child: Text(
                        'Library',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                          height: 1,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    // Bouton 1: Search — cercle, transparent, border
                    _circleBtn(
                      icon: Icons.search_rounded,
                      onTap: () => setState(() {
                        _isSearch = !_isSearch;
                        if (!_isSearch) _searchController.clear();
                      }),
                    ),
                    const SizedBox(width: 12),
                    // Bouton 2: Download — cercle, transparent, border
                    _circleBtn(
                      icon: Icons.download_outlined,
                      onTap: () {
                        ref.read(getAllMangaStreamProvider(categoryId: null, itemType: _currentType))
                          .whenData((list) => updateLibrary(ref: ref, context: context, mangaList: list, itemType: _currentType));
                      },
                    ),
                    const SizedBox(width: 12),
                    // Boutons 3+4: List & Grid — COLLES dans la meme box (pill)
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kSurface,
                        border: Border.all(color: _kBorder, width: 1.5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _toggleBtn(
                            icon: Icons.view_list_rounded,
                            active: _isListView,
                            onTap: () => setState(() => _isListView = true),
                          ),
                          _toggleBtn(
                            icon: Icons.grid_view_rounded,
                            active: !_isListView,
                            onTap: () => setState(() => _isListView = false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Inline search (quand _isSearch)
            if (_isSearch) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SeachFormTextField(
                  onChanged: (_) => setState(() {}),
                  onSuffixPressed: () { _searchController.clear(); setState(() {}); },
                  onPressed: () => setState(() { _isSearch = false; _searchController.clear(); }),
                  controller: _searchController,
                ),
              ),
            ],

            // Filter bar — height 48, bg surface, border, radius 24
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _kSurface,
                  border: Border.all(color: _kBorder, width: 1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    // Icone outils (tournevis + cle) — cercle, transparent, border
                    GestureDetector(
                      onTap: () => _openFilterSheet(settings),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBorder, width: 1),
                        ),
                        child: const Icon(Icons.handyman_outlined, size: 16, color: _kTextPrimary),
                      ),
                    ),
                    // Separateur visuel
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: _kBorder,
                    ),
                    // Pills categories — scrollables
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(_categories.length, (i) {
                            final isActive = i == _selectedCategoryIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategoryIndex = i),
                              child: Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isActive ? _kAccent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    _categories[i],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                      color: isActive ? _kTextPrimary : _kTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Contenu bibliotheque
            Expanded(
              child: LibraryScreen(
                itemType: _currentType,
                presetInput: _isSearch && _searchController.text.isNotEmpty ? _searchController.text : null,
                hideOwnAppBar: true,
                externalSearchQuery: _isSearch ? _searchController.text : null,
                key: ValueKey(_currentType.index * 100 + _selectedCategoryIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}