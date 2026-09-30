import 'package:flutter_mort/core/routing/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('production router preserves role tab paths and sensitive nested routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    final shells = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .toList();
    expect(shells, hasLength(3));
    final paths = shells
        .map(
          (shell) => shell.branches
              .map((branch) => (branch.routes.first as GoRoute).path)
              .toList(),
        )
        .toList();
    expect(paths[0], [
      '/teen/home',
      '/teen/jobs',
      '/teen/messages',
      '/teen/safety',
      '/teen/profile',
    ]);
    expect(paths[1], [
      '/adult/home',
      '/adult/jobs',
      '/adult/messages',
      '/adult/safety',
      '/adult/profile',
    ]);
    expect(paths[2], [
      '/guardian/home',
      '/guardian/safety',
      '/guardian/messages',
      '/guardian/profile',
    ]);

    for (final shell in shells) {
      for (final branch in shell.branches) {
        final route = branch.routes.first as GoRoute;
        if (!route.path.endsWith('/messages')) continue;
        expect((route.routes.single as GoRoute).path, ':conversationId');
      }
    }
  });
}
