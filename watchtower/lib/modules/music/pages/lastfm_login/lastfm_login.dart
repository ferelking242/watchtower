import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/spotube_icons.dart';
import 'package:watchtower/modules/music/components/button/back_button.dart';
import 'package:watchtower/modules/music/components/dialogs/prompt_dialog.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/provider/scrobbler/scrobbler.dart';

class LastFMLoginPage extends HookConsumerWidget {
  static const name = "lastfm_login";
  const LastFMLoginPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final scrobblerNotifier = ref.read(scrobblerProvider.notifier);

    final usernameController = useTextEditingController();
    final passwordController = useTextEditingController();
    final passwordVisible = useState(false);
    final isLoading = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>(), []);

    Future<void> onSubmit() async {
      if (!formKey.currentState!.validate()) return;
      try {
        isLoading.value = true;
        await scrobblerNotifier.login(
          usernameController.text.trim(),
          passwordController.text,
        );
        if (context.mounted) {
          context.back();
        }
      } catch (e) {
        if (context.mounted) {
          await showPromptDialog(
            context: context,
            title: context.l10n.error("Authentication failed"),
            message: e.toString(),
            cancelText: null,
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          leading: MusicBackButton(),
        ),
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: const Color.fromARGB(255, 186, 0, 0),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              SpotubeIcons.lastFm,
                              color: Colors.white,
                              size: 60,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "last.fm",
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(context.l10n.login_with_your_lastfm),
                          const SizedBox(height: 16),
                          AutofillGroup(
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: usernameController,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: context.l10n.username,
                                    hintText: context.l10n.username,
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Username is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: passwordController,
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  obscureText: !passwordVisible.value,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.password,
                                    hintText: context.l10n.password,
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        passwordVisible.value
                                            ? SpotubeIcons.eye
                                            : SpotubeIcons.noEye,
                                      ),
                                      onPressed: () => passwordVisible.value =
                                          !passwordVisible.value,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "Password is required";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: isLoading.value ? null : onSubmit,
                                  child: Text(context.l10n.login),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
