import 'package:flutter/material.dart';

/// Shows a modal progress dialog and returns the function that closes it.
///
/// The dialog is pushed as a [DialogRoute] that this function owns, so closing
/// it removes exactly that route. The usual pattern —
/// `showDialog(...)` … `Navigator.pop(context)` — has two failure modes the
/// file manager hits constantly:
///
/// * the back button dismisses the dialog while a long copy/encrypt is still
///   running, and the later `Navigator.pop(context)` then pops the *screen*
///   underneath (the user is thrown out of the folder they were working in);
/// * the screen is disposed mid-operation, `context` is dead, the pop throws
///   and the modal barrier stays on screen — the app looks frozen.
///
/// The returned closer is idempotent and safe to call after the route is gone.
Future<void> Function() showBlockingProgressDialog(
  BuildContext context, {
  String? message,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: message,
    builder: (_) => _BlockingProgress(message: message),
  );
  navigator.push(route);
  var closed = false;
  return () {
    if (closed) return;
    closed = true;
    if (route.isActive) navigator.removeRoute(route);
  };
}

class _BlockingProgress extends StatelessWidget {
  const _BlockingProgress({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Center(
        child: Card(
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
