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

    final usernameKey =
        useMemoized(() => const FormKey<String>("username"), []);
    final passwordKey =
        useMemoized(() => const FormKey<String>("password"), []);

    final passwordVisible = useState(false);

    final isLoading = useState(false);

    return Scaffold(
      headers: const [
        SafeArea(
          bottom: false,
          child: AppBar(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [BackButton()]),
          ),
        ),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Card(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  onSubmit: (context, values) async {
                    try {
                      isLoading.value = true;
                      await scrobblerNotifier.login(
                        values[usernameKey].trim(),
                        values[passwordKey],
                      );
                      if (context.mounted) {
                        context.back();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showPromptDialog(
                          context: context,
                          title: context.l10n.error("Authentication failed"),
                          message: e.toString(),
                          cancelText: null,
                        );
                      }
                    } finally {
                      isLoading.value = false;
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
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
                      const Text("last.fm").h3(),
                      Text(context.l10n.login_with_your_lastfm),
                      AutofillGroup(
                        child: Column(
                          spacing: 10,
                          children: [
                            FormField(
                              label: Text(context.l10n.username),
                              key: usernameKey,
                              validator: const NotEmptyValidator(
                                message: "Username is required",
                              ),
                              child: TextField(
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                placeholder: Text(context.l10n.username),
                              ),
                            ),
                            FormField(
                              key: passwordKey,
                              validator: const NotEmptyValidator(
                                message: "Password is required",
                              ),
                              label: Text(context.l10n.password),
                              child: TextField(
                                autofillHints: const [
                                  AutofillHints.password,
                                ],
                                obscureText: !passwordVisible.value,
                                placeholder: Text(context.l10n.password),
                                features: [
                                  InputFeature.trailing(
                                    IconButton(
                                      icon: Icon(
                                        passwordVisible.value
                                            ? SpotubeIcons.eye
                                            : SpotubeIcons.noEye,
                                      ),
                                      onPressed: () => passwordVisible.value =
                                          !passwordVisible.value,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      FormErrorBuilder(builder: (context, errors, child) {
                        return FilledButton(
                          onPressed: () => context.submitForm(),
                          enabled: errors.isEmpty && !isLoading.value,
                          child: Text(context.l10n.login),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
