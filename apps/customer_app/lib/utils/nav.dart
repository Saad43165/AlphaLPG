import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension AppNav on BuildContext {
  /// Back if there is somewhere to go back to, otherwise Home. This is what
  /// every Back button and Android back press uses, so nobody is ever stuck.
  void backOrHome() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }

  /// Resets to Home and then stacks [locations] on top of it, so Back from the
  /// last one leads through the earlier ones to Home instead of nowhere.
  void goHomeThenPush(List<String> locations) {
    final router = GoRouter.of(this);
    router.go('/');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final l in locations) {
        router.push(l);
      }
    });
  }
}
