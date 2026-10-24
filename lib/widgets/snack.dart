import 'package:flutter/material.dart';

/// Shows a snackbar, replacing the current one. Every snackbar in the app
/// goes through here because Flutter keeps one with an action on screen until
/// dismissed (`persist` defaults to true); these leave after the usual 4 s.
///
/// The snackbar outlives the screen that showed it, so [onAction] must not
/// use that screen's BuildContext. Capture what it needs (a NavigatorState,
/// a notifier) before calling.
void showSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        content: Text(message),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
