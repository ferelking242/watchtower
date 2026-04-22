import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';

class CreateExtension extends StatefulWidget {
  const CreateExtension({super.key});

  @override
  State<CreateExtension> createState() => _CreateExtensionState();
}

class _CreateExtensionState extends State<CreateExtension> {
  String _name = "";
  String _lang = "";
  String _baseUrl = "";
  String _apiUrl = "";
  String _iconUrl = "";
  String _notes = "";
  int _sourceTypeIndex = 0;
  int _itemTypeIndex = 0;
  int _languageIndex = 0;
  final List<String> _sourceTypes = ["single", "multi", "torrent"];
  final List<String> _itemTypes = ["Manga", "Anime", "Novel"];
  final List<String> _languages = [
    "Dart",
    "JavaScript",
    "LNReader compiled JS",
  ];
  SourceCodeLanguage _sourceCodeLanguage = SourceCodeLanguage.dart;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.extension_rounded, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            const Text("Create Extension"),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.16),
                      cs.tertiary.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded,
                        color: cs.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Build your own source. After creation, open the '
                        'extension to edit its code and publish it to the '
                        'community marketplace.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _SectionHeader(label: 'LANGUAGE', icon: Icons.code_rounded),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    const Text("Choose extension language"),
                    const SizedBox(width: 20),
                    Flexible(
                      child: DropdownButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        isExpanded: true,
                        value: _languageIndex,
                        hint: Text(
                          _languages[_languageIndex],
                          style: const TextStyle(fontSize: 13),
                        ),
                        items: _languages
                            .map(
                              (e) => DropdownMenuItem(
                                value: _languages.indexOf(e),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            if (v == 0) {
                              _sourceCodeLanguage = SourceCodeLanguage.dart;
                            } else if (v == 1) {
                              _sourceCodeLanguage =
                                  SourceCodeLanguage.javascript;
                            } else {
                              _sourceCodeLanguage = SourceCodeLanguage.lnreader;
                            }
                            _languageIndex = v!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _textEditing("Name", context, "ex: myAnime", (v) {
                setState(() {
                  _name = v;
                });
              }),
              _textEditing("Lang", context, "ex: en", (v) {
                setState(() {
                  _lang = v;
                });
              }),
              _textEditing("BaseUrl", context, "ex: https://example.com", (v) {
                setState(() {
                  _baseUrl = v;
                });
              }),
              _textEditing(
                "ApiUrl (optional)",
                context,
                "ex: https://api.example.com",
                (v) {
                  setState(() {
                    _apiUrl = v;
                  });
                },
              ),
              _textEditing("iconUrl", context, "Source icon url", (v) {
                setState(() {
                  _iconUrl = v;
                });
              }),
              _textEditing(
                "notes",
                context,
                "ex: this extension requires login",
                (v) {
                  setState(() {
                    _notes = v;
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    const Text("Type"),
                    const SizedBox(width: 20),
                    Flexible(
                      child: DropdownButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        isExpanded: true,
                        value: _sourceTypeIndex,
                        hint: Text(
                          _sourceTypes[_sourceTypeIndex],
                          style: const TextStyle(fontSize: 13),
                        ),
                        items: _sourceTypes
                            .map(
                              (e) => DropdownMenuItem(
                                value: _sourceTypes.indexOf(e),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _sourceTypeIndex = v!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  children: [
                    const Text("Target"),
                    const SizedBox(width: 20),
                    Flexible(
                      child: DropdownButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        isExpanded: true,
                        value: _itemTypeIndex,
                        hint: Text(
                          _itemTypes[_itemTypeIndex],
                          style: const TextStyle(fontSize: 13),
                        ),
                        items: _itemTypes
                            .map(
                              (e) => DropdownMenuItem(
                                value: _itemTypes.indexOf(e),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _itemTypeIndex = v!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'Save your extension first, then open it '
                                'and tap "Publish" to share to the marketplace.',
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                              color: cs.primary.withValues(alpha: 0.5)),
                        ),
                        icon: Icon(Icons.public_rounded,
                            color: cs.primary, size: 18),
                        label: Text(
                          'Publish',
                          style: TextStyle(color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Consumer(
                  builder: (context, ref, child) => ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      if (_name.isNotEmpty &&
                          _lang.isNotEmpty &&
                          _baseUrl.isNotEmpty &&
                          _iconUrl.isNotEmpty) {
                        try {
                          final id =
                              _sourceCodeLanguage == SourceCodeLanguage.dart
                              ? 'watchtower-$_lang.$_name'.hashCode
                              : 'watchtower-js-$_lang.$_name'.hashCode;
                          final checkIfExist = isar.sources.getSync(id);
                          if (checkIfExist == null) {
                            Source source = Source(
                              id: id,
                              name: _name,
                              lang: _lang,
                              baseUrl: _baseUrl,
                              apiUrl: _apiUrl,
                              iconUrl: _iconUrl,
                              typeSource: _sourceTypes[_sourceTypeIndex],
                              itemType: ItemType.values.elementAt(
                                _itemTypeIndex,
                              ),
                              isAdded: true,
                              isActive: true,
                              version: "0.0.1",
                              isNsfw: false,
                              notes: _notes,
                            )..sourceCodeLanguage = _sourceCodeLanguage;
                            source = source
                              ..isLocal = true
                              ..sourceCode =
                                  _sourceCodeLanguage == SourceCodeLanguage.dart
                                  ? _dartTemplate
                                  : _jsSample(source);
                            isar.writeTxnSync(() {
                              isar.sources.putSync(
                                source
                                  ..updatedAt =
                                      DateTime.now().millisecondsSinceEpoch,
                              );
                            });
                            Navigator.pop(context);
                            botToast("Source created successfully");
                          } else {
                            botToast("Source already exists");
                          }
                        } catch (e) {
                          botToast("Error when creating source");
                        }
                      }
                    },
                    child: Text(context.l10n.save),
                  ),
                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _textEditing(
  String label,
  BuildContext context,
  String hintText,
  void Function(String)? onChanged,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
    child: TextFormField(
      keyboardType: TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.transparent,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: context.secondaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: context.secondaryColor),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: context.secondaryColor),
        ),
      ),
    ),
  );
}

const _dartTemplate = r'''
import 'package:watchtower/bridge_lib.dart';
import 'dart:convert';

class TestSource extends MProvider {
  TestSource({required this.source});

  MSource source;

  final Client client = Client();

  @override
  bool get supportsLatest => true;

  @override
  Map<String, String> get headers => {};
  
  @override
  Future<MPages> getPopular(int page) async {
    // TODO: implement
  }

  @override
  Future<MPages> getLatestUpdates(int page) async {
    // TODO: implement
  }

  @override
  Future<MPages> search(String query, int page, FilterList filterList) async {
    // TODO: implement
  }

  @override
  Future<MManga> getDetail(String url) async {
    // TODO: implement
  }
  
  // For novel html content
  @override
  Future<String> getHtmlContent(String name, String url) async {
    // TODO: implement
  }
  
  // Clean html up for reader
  @override
  Future<String> cleanHtmlContent(String html) async {
    // TODO: implement
  }
  
  // For anime episode video list
  @override
  Future<List<MVideo>> getVideoList(String url) async {
    // TODO: implement
  }

  // For manga chapter pages
  @override
  Future<List<String>> getPageList(String url) async{
    // TODO: implement
  }

  @override
  List<dynamic> getFilterList() {
    // TODO: implement
  }

  @override
  List<dynamic> getSourcePreferences() {
    // TODO: implement
  }
}

TestSource main(MSource source) {
  return TestSource(source:source);
}''';

String _jsSample(Source source) =>
    '''
const watchtowerSources = [{
    "name": "${source.name}",
    "lang": "${source.lang}",
    "baseUrl": "${source.baseUrl}",
    "apiUrl": "${source.apiUrl}",
    "iconUrl": "${source.iconUrl}",
    "typeSource": "${source.typeSource}",
    "itemType": ${source.itemType.index},
    "version": "${source.version}",
    "pkgPath": "",
    "notes": ""
}];

class DefaultExtension extends MProvider {
    getHeaders(url) {
        throw new Error("getHeaders not implemented");
    }
    async getPopular(page) {
        throw new Error("getPopular not implemented");
    }
    get supportsLatest() {
        throw new Error("supportsLatest not implemented");
    }
    async getLatestUpdates(page) {
        throw new Error("getLatestUpdates not implemented");
    }
    async search(query, page, filters) {
        throw new Error("search not implemented");
    }
    async getDetail(url) {
        throw new Error("getDetail not implemented");
    }
    // For novel html content
    async getHtmlContent(name, url) {
        throw new Error("getHtmlContent not implemented");
    }
    // Clean html up for reader
    async cleanHtmlContent(html) {
        throw new Error("cleanHtmlContent not implemented");
    }
    // For anime episode video list
    async getVideoList(url) {
        throw new Error("getVideoList not implemented");
    }
    // For manga chapter pages
    async getPageList(url) {
        throw new Error("getPageList not implemented");
    }
    getFilterList() {
        throw new Error("getFilterList not implemented");
    }
    getSourcePreferences() {
        throw new Error("getSourcePreferences not implemented");
    }
}
''';
