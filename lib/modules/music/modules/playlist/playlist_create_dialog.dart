import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/form/checkbox_form_field.dart';
import 'package:watchtower/modules/music/components/form/text_form_field.dart';
import 'package:watchtower/modules/music/components/image/universal_image.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/models/metadata/metadata.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/library/playlists.dart';
import 'package:watchtower/modules/music/provider/metadata_plugin/playlist/playlist.dart';

class PlaylistCreateDialog extends HookConsumerWidget {
  /// Track ids to add to the playlist
  final List<String> trackIds;
  final String? playlistId;
  const PlaylistCreateDialog({
    super.key,
    this.trackIds = const [],
    this.playlistId,
  });

  @override
  Widget build(BuildContext context, ref) {
    final userPlaylists = ref.watch(metadataPluginSavedPlaylistsProvider);
    final playlist =
        ref.watch(metadataPluginPlaylistProvider(playlistId ?? ""));
    final playlistNotifier =
        ref.watch(metadataPluginPlaylistProvider(playlistId ?? "").notifier);

    final isSubmitting = useState(false);

    final formKey = useMemoized(() => GlobalKey<FormBuilderState>(), []);

    final updatingPlaylist = useMemoized(
      () => userPlaylists.asData?.value.items
          .firstWhereOrNull((playlist) => playlist.id == playlistId),
      [
        userPlaylists.asData?.value.items,
        playlistId,
      ],
    );

    final isUpdatingPlaylist = playlistId != null;

    final l10n = context.l10n;
    final theme = Theme.of(context);

    useEffect(() {
      if (playlist.asData?.value != null) {
        formKey.currentState?.patchValue({
          'playlistName': playlist.asData!.value.name,
          'description': playlist.asData!.value.description,
          'public': playlist.asData!.value.public,
          'collaborative': playlist.asData!.value.collaborative,
        });
      }

      return;
    }, [playlist]);

    final onError = useCallback((error) {
      // toast removed - use SnackBar instead
    }, [l10n, theme]);

    Future<void> onCreate() async {
      if (!formKey.currentState!.saveAndValidate()) return;

      try {
        isSubmitting.value = true;
        final values = formKey.currentState!.value;

        final payload = (
          playlistName: values['playlistName'],
          collaborative: values['collaborative'],
          public: values['public'],
          description: values['description'],
          base64Image: (values['image'] as XFile?)?.path != null
              ? await (values['image'] as XFile)
                  .readAsBytes()
                  .then((bytes) => base64Encode(bytes))
              : null,
        );

        if (isUpdatingPlaylist) {
          await playlistNotifier.modify(
            name: payload.playlistName,
            description: payload.description,
            public: payload.public,
            collaborative: payload.collaborative,
            onError: onError,
          );
        } else {
          await playlistNotifier.create(
            name: payload.playlistName,
            description: payload.description,
            public: payload.public,
            collaborative: payload.collaborative,
            onError: onError,
          );
        }

        if (trackIds.isNotEmpty) {
          await playlistNotifier.addTracks(trackIds, onError);
        }
      } finally {
        isSubmitting.value = false;
        if (context.mounted &&
            !ref
                .read(metadataPluginPlaylistProvider(playlistId ?? ""))
                .hasError) {
          context.router.maybePop<SpotubeFullPlaylistObject>(
            await ref
                .read(metadataPluginPlaylistProvider(playlistId ?? "").future),
          );
        }
      }
    }

    return AlertDialog(
      title: Text(
        isUpdatingPlaylist
            ? context.l10n.update_playlist
            : context.l10n.create_a_playlist,
      ),
      actions: [
        OutlinedButton(
          child: Text(context.l10n.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        FilledButton(
          onPressed: (!playlist.isLoading && !isSubmitting.value) ? onCreate : null,
          child: Text(
            isUpdatingPlaylist ? context.l10n.update : context.l10n.create,
          ),
        ),
      ],
      content: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 500),
        child: FormBuilder(
          key: formKey,
          initialValue: {
            'playlistName': updatingPlaylist?.name,
            'description': updatingPlaylist?.description,
            'public': playlist.asData?.value.public ?? false,
            'collaborative': playlist.asData?.value.collaborative ?? false,
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              FormBuilderField<XFile?>(
                name: 'image',
                validator: (value) {
                  if (value == null) return null;
                  final file = File(value.path);

                  if (file.lengthSync() > 256000) {
                    return "Image size should be less than 256kb";
                  }

                  if (extension(file.path) != ".png") {
                    return "Image should be in PNG format";
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    spacing: 10,
                    children: [
                      UniversalImage(
                        path: field.value?.path ??
                            (updatingPlaylist?.images).asUrlString(
                              placeholder: ImagePlaceholder.collection,
                            ),
                        height: 200,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            icon: const Icon(SpotubeIcons.edit),
                            label: Text(
                              field.value?.path != null ||
                                      updatingPlaylist?.images != null
                                  ? context.l10n.change_cover
                                  : context.l10n.add_cover,
                            ),
                            onPressed: () async {
                              final imageFile = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                              );

                              if (imageFile != null) {
                                field.didChange(imageFile);
                                field.validate();
                                field.save();
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(SpotubeIcons.trash),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: field.value == null
                                ? null
                                : () {
                                    field.didChange(null);
                                    field.validate();
                                    field.save();
                                  },
                          ),
                        ],
                      ),
                      if (field.hasError)
                        Text(
                          field.errorText ?? "",
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                    ],
                  );
                },
              ),
              const SizedBox(height: 20, width: 20),
              TextFormBuilderField(
                name: 'playlistName',
                label: Text(context.l10n.playlist_name),
                placeholder: Text(context.l10n.name_of_playlist),
                validator: FormBuilderValidators.required(),
              ),
              const SizedBox(height: 20, width: 20),
              TextFormBuilderField(
                name: 'description',
                label: Text(context.l10n.description),
                validator: FormBuilderValidators.required(),
                placeholder: Text(context.l10n.description),
                keyboardType: TextInputType.multiline,
                maxLines: 5,
              ),
              const SizedBox(height: 20, width: 20),
              CheckboxFormBuilderField(
                name: 'public',
                trailing: Text(context.l10n.public),
              ),
              const SizedBox(height: 10, width: 10),
              CheckboxFormBuilderField(
                name: 'collaborative',
                trailing: Text(context.l10n.collaborative),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistCreateDialogButton extends HookConsumerWidget {
  const PlaylistCreateDialogButton({super.key});

  void showPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PlaylistCreateDialog(),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    return TextButton.icon(
      icon: const Icon(SpotubeIcons.addFilled),
      label: Text(context.l10n.playlist),
      onPressed: () => showPlaylistDialog(context),
    );
  }
}
