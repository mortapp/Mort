import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mort/core/routing/app_router.dart';
import 'package:flutter_mort/core/widgets/legal_reacceptance_gate.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';

class _LegalContractRepository extends LegalContractRepository {
  _LegalContractRepository(this.requirements);

  List<Map<String, dynamic>> requirements;
  bool unavailable = false;

  @override
  Future<Map<String, dynamic>> legalRequirements({
    String? expectedUserId,
  }) async {
    if (unavailable) throw Exception('offline');
    return {'requirements': requirements};
  }
}

void main() {
  late GoRouter router;
  late ProviderContainer container;
  late _LegalContractRepository repository;

  setUp(() {
    repository = _LegalContractRepository([
      {'required': true, 'acceptance_id': null},
    ]);
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Text('private account content'),
        ),
        GoRoute(
          path: '/legal-center',
          builder: (_, _) => const Text('legal center'),
        ),
        GoRoute(
          path: '/legal-center/version/:id',
          builder: (_, state) =>
              Text('legal version ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/legal-center-extra',
          builder: (_, _) => const Text('unrelated route'),
        ),
      ],
    );
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appRouterProvider.overrideWithValue(router),
        legalContractRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);
  });

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (_, child) => LegalReacceptanceGate(
        userId: 'user-1',
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets(
    'required reacceptance blocks app routes but allows legal review',
    (tester) async {
      await tester.pumpWidget(app());
      await pumpUi(tester);

      expect(find.text('legal center'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/legal-center',
      );

      router.go('/legal-center/version/terms-v2');
      await pumpUi(tester);
      expect(find.text('legal version terms-v2'), findsOneWidget);

      router.go('/legal-center-extra');
      await pumpUi(tester);
      expect(find.text('legal center'), findsOneWidget);
      expect(find.text('unrelated route'), findsNothing);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/legal-center',
      );

      router.go('/home');
      await pumpUi(tester);
      expect(find.text('legal center'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/legal-center',
      );
    },
  );

  testWidgets(
    'verification errors block app routes and retry the requirement',
    (tester) async {
      repository.unavailable = true;
      await tester.pumpWidget(app());
      await pumpUi(tester);

      expect(find.text('Required legal documents unavailable'), findsOneWidget);
      expect(find.text('private account content'), findsNothing);

      repository
        ..unavailable = false
        ..requirements = [];
      await tester.tap(find.text('Retry legal check'));
      await pumpUi(tester);

      expect(find.text('private account content'), findsOneWidget);
    },
  );

  testWidgets('accepted requirements leave regular app routes available', (
    tester,
  ) async {
    repository.requirements = [
      {'required': true, 'acceptance_id': 'accepted-v2'},
    ];
    await tester.pumpWidget(app());
    await pumpUi(tester);

    expect(find.text('private account content'), findsOneWidget);
    expect(find.text('legal center'), findsNothing);
  });
}
