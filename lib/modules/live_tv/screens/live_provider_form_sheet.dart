import 'package:flutter/material.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/modules/live_tv/models/live_provider.dart';

/// Sheet that creates a provider from a URL, an Xtream panel, or a JSON list.
///
/// One sheet for all three kinds rather than three flows: the only difference
/// is the extra credential fields, and splitting them would triplicate the
/// validation and the id generation.
class LiveProviderFormSheet extends StatefulWidget {
  const LiveProviderFormSheet({super.key});

  @override
  State<LiveProviderFormSheet> createState() => _LiveProviderFormSheetState();
}

class _LiveProviderFormSheetState extends State<LiveProviderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sourceController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  LiveProviderKind _kind = LiveProviderKind.m3u;

  @override
  void dispose() {
    _nameController.dispose();
    _sourceController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _needsCredentials => _kind == LiveProviderKind.xtream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ajouter un fournisseur',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live TV accepte une playlist M3U, un panneau Xtream ou une '
                'liste JSON.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<LiveProviderKind>(
                segments: const [
                  ButtonSegment(
                    value: LiveProviderKind.m3u,
                    label: Text('M3U'),
                    icon: Icon(Broken.video_play, size: 18),
                  ),
                  ButtonSegment(
                    value: LiveProviderKind.xtream,
                    label: Text('Xtream'),
                    icon: Icon(Broken.lock, size: 18),
                  ),
                  ButtonSegment(
                    value: LiveProviderKind.json,
                    label: Text('JSON'),
                    icon: Icon(Broken.document_text, size: 18),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) {
                  setState(() => _kind = selection.first);
                },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Mon fournisseur',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Un nom est requis.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sourceController,
                keyboardType: TextInputType.url,
                textInputAction: _needsCredentials
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: InputDecoration(
                  labelText: _needsCredentials ? 'URL du panneau' : 'URL de la liste',
                  hintText: _needsCredentials
                      ? 'http://panel.example:8080'
                      : 'https://example.com/channels.m3u',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Une URL est requise.';
                  final uri = Uri.tryParse(text);
                  if (uri == null ||
                      !uri.hasScheme ||
                      (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return 'L’URL doit commencer par http:// ou https://';
                  }
                  return null;
                },
              ),
              if (_needsCredentials) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'Requis.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? 'Requis.' : null,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final source = _sourceController.text.trim();
    final now = DateTime.now();
    final provider = LiveProvider(
      // Stable id from kind + source: re-adding the same list replaces the
      // entry instead of creating a duplicate row.
      id: '${_kind.name}:${source.hashCode.toUnsigned(32).toRadixString(16)}',
      name: name,
      kind: _kind,
      source: source,
      username: _needsCredentials ? _usernameController.text.trim() : null,
      password: _needsCredentials ? _passwordController.text : null,
      version: '1.0.0',
      author: 'Utilisateur',
      updatedAt: now,
    );
    Navigator.of(context).pop(provider);
  }
}
