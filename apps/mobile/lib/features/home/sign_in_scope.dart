import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';

/// Lets any deep widget send a signed-out user to the sign-in tab. Provided by
/// the home shell (like CallScope) so gated actions never dead-end.
class SignInScope extends InheritedWidget {
  const SignInScope({
    super.key,
    required this.requestSignIn,
    required super.child,
  });

  final VoidCallback requestSignIn;

  static SignInScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SignInScope>();

  @override
  bool updateShouldNotify(SignInScope oldWidget) =>
      requestSignIn != oldWidget.requestSignIn;
}

/// Shows a clear "please sign in" snackbar with a Sign in action that jumps to
/// the account tab. Returns false so callers can `if (!ensureSignedIn(...)) return;`.
bool promptSignIn(BuildContext context, AppLanguage language) {
  final en = language == AppLanguage.english;
  final messenger = ScaffoldMessenger.of(context);
  final scope = SignInScope.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(en
        ? 'Please sign in to do this.'
        : 'ይህን ለማድረግ እባክዎ ይግቡ።'),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 4),
    action: scope == null
        ? null
        : SnackBarAction(
            label: en ? 'Sign in' : 'ግባ',
            onPressed: scope.requestSignIn,
          ),
  ));
  return false;
}
