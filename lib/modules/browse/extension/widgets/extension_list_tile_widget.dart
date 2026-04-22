import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/utils/log/logger.dart';

final extensionListTileWidget = Provider.family<Widget, Source>((ref, source) {
  return ExtensionListTileWidget(source: source);
});

class ExtensionListTileWidget extends ConsumerStatefulWidget {
  final Source source;
  const ExtensionListTileWidget({super.key, required this.source});

  @override
  ConsumerState<ExtensionListTileWidget> createState() =>
      _ExtensionListTileWidgetState();
}

class _ExtensionListTileWidgetState
    extends ConsumerState<ExtensionListTileWidget> {
  bool _isLoading = false;
  late final bool _updateAvailable;
  late final bool _sourceNotEmpty;

  @override
  void initState() {
    super.initState();
    _updateAvailable =
        compareVersions(widget.source.version!, widget.source.versionLast!) < 0;
    _sourceNotEmpty =
        widget.source.sourceCode != null &&
        widget.source.sourceCode!.isNotEmpty;
  }

  Future<void> _handleSourceFetch() async {
    setState(() => _isLoading = true);
    AppLogger.log(
      '${_updateAvailable ? "Update" : "Install"} requested: "${widget.source.name}" v${widget.source.version}',
      tag: LogTag.extension_,
    );

    try {
      final provider = fetchItemSourcesListProvider(
        id: widget.source.id,
        reFresh: true,
        itemType: widget.source.itemType,
      );

      if (!(widget.source.isAdded ?? false)) ref.invalidate(provider);
      await ref.read(provider.future);
      AppLogger.log(
        '${_updateAvailable ? "Update" : "Install"} completed: "${widget.source.name}"',
        tag: LogTag.extension_,
      );
    } catch (e, st) {
      AppLogger.log(
        '${_updateAvailable ? "Update" : "Install"} FAILED: "${widget.source.name}"',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTrailingButton(BuildContext context, String label) {
    final isInstall = label == context.l10n.install;
    final isUpdate = label == context.l10n.update;
    return _isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                splashRadius: 20,
                onPressed: _isLoading
                    ? null
                    : () {
                        if (!_updateAvailable && _sourceNotEmpty) {
                          context.push(
                            '/extension_detail',
                            extra: widget.source,
                          );
                        } else {
                          _handleSourceFetch();
                        }
                      },
                icon: Icon(
                  isInstall
                      ? Icons.download_outlined
                      : isUpdate
                      ? Icons.system_update_alt_outlined
                      : Icons.settings_outlined,
                  size: 22,
                ),
              ),
              if (_sourceNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  splashRadius: 20,
                  icon: const Icon(Icons.delete_outline, size: 22),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(widget.source.name!),
                          content: Text(
                            ctx.l10n.uninstall_extension(widget.source.name!),
                          ),
                          actions: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(ctx.l10n.cancel),
                                ),
                                const SizedBox(width: 15),
                                TextButton(
                                  onPressed: () {
                                    final sourcePrefsIds = isar
                                        .sourcePreferences
                                        .filter()
                                        .sourceIdEqualTo(widget.source.id!)
                                        .findAllSync()
                                        .map((e) => e.id!)
                                        .toList();
                                    final sourcePrefsStringIds = isar
                                        .sourcePreferenceStringValues
                                        .filter()
                                        .sourceIdEqualTo(widget.source.id!)
                                        .findAllSync()
                                        .map((e) => e.id)
                                        .toList();
                                    isar.writeTxnSync(() {
                                      if (widget.source.isObsolete ?? false) {
                                        isar.sources.deleteSync(
                                          widget.source.id!,
                                        );
                                        ref
                                            .read(
                                              synchingProvider(
                                                syncId: 1,
                                              ).notifier,
                                            )
                                            .addChangedPart(
                                              ActionType.removeExtension,
                                              widget.source.id,
                                              "{}",
                                              false,
                                            );
                                      } else {
                                        isar.sources.putSync(
                                          widget.source
                                            ..sourceCode = ""
                                            ..isAdded = false
                                            ..isPinned = false
                                            ..updatedAt = DateTime.now()
                                                .millisecondsSinceEpoch,
                                        );
                                      }
                                      isar.sourcePreferences.deleteAllSync(
                                        sourcePrefsIds,
                                      );
                                      isar.sourcePreferenceStringValues
                                          .deleteAllSync(sourcePrefsStringIds);
                                    });

                                    Navigator.pop(ctx);
                                  },
                                  child: Text(ctx.l10n.ok),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    final buttonLabel = !_sourceNotEmpty
        ? l10n.install
        : _updateAvailable
        ? l10n.update
        : l10n.settings;

    final lang = widget.source.sourceCodeLanguage;
    final isJs = lang == SourceCodeLanguage.javascript;
    final isDart = lang == SourceCodeLanguage.dart;

    return ListTile(
      onTap: _isLoading
          ? null
          : () {
              if (_sourceNotEmpty) {
                AppLogger.log(
                  'Open extension detail: "${widget.source.name}" '
                  '[${widget.source.lang}] v${widget.source.version} '
                  '· id=${widget.source.id} · type=${widget.source.itemType.name}',
                  tag: LogTag.extension_,
                );
                context.push('/extension_detail', extra: widget.source);
              } else {
                _handleSourceFetch();
              }
            },
      leading: Container(
        height: 37,
        width: 37,
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: widget.source.iconUrl!.isEmpty
            ? const Icon(Icons.extension_rounded)
            : cachedNetworkImage(
                imageUrl: widget.source.iconUrl!,
                fit: BoxFit.contain,
                width: 37,
                height: 37,
                errorWidget: const SizedBox(
                  width: 37,
                  height: 37,
                  child: Center(child: Icon(Icons.extension_rounded)),
                ),
                useCustomNetworkImage: false,
              ),
      ),
      title: Text(widget.source.name!),
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            completeLanguageName(widget.source.lang!.toLowerCase()),
            style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            _updateAvailable
                ? '${widget.source.version!} → ${widget.source.versionLast!}'
                : widget.source.version!,
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 12,
              color: _updateAvailable
                  ? Colors.orange.shade400
                  : null,
            ),
          ),
          if (widget.source.isNsfw ?? false)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "NSFW",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (isDart)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "DART",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (isJs)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade800.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "JS",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (widget.source.repo?.name != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "- ${widget.source.repo!.name!}",
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (widget.source.isObsolete ?? false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "OBSOLETE",
                style: TextStyle(
                  color: context.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      trailing: _buildTrailingButton(context, buttonLabel),
    );
  }
}
