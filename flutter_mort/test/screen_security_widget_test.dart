import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/services/screen_security_service.dart';

void main() {
  const channel = MethodChannel('mort/native_security');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // reset handlers/state
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ScreenSecurityService.setPlatformSetter(null);
    await ScreenSecurityService.debugReset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ScreenSecurityService.setPlatformSetter(null);
    await ScreenSecurityService.debugReset();
  });

  testWidgets('widget disposal releases protection', (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    bool show = true;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (c, setState) {
          return MaterialApp(
            home: Column(
              children: [
                if (show)
                  const SensitiveScreenProtection(child: _ProtectedBox()),
                ElevatedButton(
                  onPressed: () => setState(() => show = false),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // initial add should call setSecure(true)
    await tester.pumpAndSettle();
    expect(calls.length, 1);
    expect(calls.first.method, 'setSecureScreen');
    expect(calls.first.arguments, {'enabled': true});

    // remove widget
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // should have called setSecure(false)
    expect(calls.length, 2);
    expect(calls[1].method, 'setSecureScreen');
    expect(calls[1].arguments, {'enabled': false});
  });

  testWidgets('push and pop protected route returns count to zero', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SensitiveScreenProtection(child: _ProtectedBox()),
                  ),
                ),
                child: const Text('Push'),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(calls.length, 0);

    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();

    // entering protected route should enable
    expect(calls.length, 1);
    expect(calls.first.arguments, {'enabled': true});

    // pop
    (tester.state(find.byType(Navigator)) as NavigatorState).pop();
    await tester.pumpAndSettle();

    // should have disabled
    expect(calls.length, 2);
    expect(calls[1].arguments, {'enabled': false});
  });

  testWidgets('ordinary route after protected route is not secure', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SensitiveScreenProtection(
                        child: _ProtectedBox(),
                      ),
                    ),
                  ),
                  child: const Text('PushProtected'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('Ordinary')),
                    ),
                  ),
                  child: const Text('PushOrdinary'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('PushProtected'));
    await tester.pumpAndSettle();
    expect(calls.length, 1);

    // pop protected
    (tester.state(find.byType(Navigator)) as NavigatorState).pop();
    await tester.pumpAndSettle();
    expect(calls.length, 2);

    // push ordinary route
    await tester.tap(find.text('PushOrdinary'));
    await tester.pumpAndSettle();

    // no additional secure calls
    expect(calls.length, 2);
  });

  testWidgets('lifecycle inactive->resumed preserves state and secure count', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            int counter = 0;
            return Column(
              children: [
                SensitiveScreenProtection(
                  child: StatefulBuilder(
                    builder: (c, s) {
                      return Column(
                        children: [
                          Text('$counter', key: const ValueKey('counter')),
                          ElevatedButton(
                            onPressed: () => s(() => counter += 1),
                            child: const Text('Inc'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(calls.length, 1);

    // increment state
    await tester.tap(find.text('Inc'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('counter')), findsOneWidget);

    // simulate inactive then resumed
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // state preserved and secure not leaked
    expect(find.byKey(const ValueKey('counter')), findsOneWidget);
    expect(calls.last.arguments, {'enabled': true});
  });

  testWidgets('lifecycle paused->resumed preserves state and secure count', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: SensitiveScreenProtection(
          child: Column(
            children: [
              Text('ok'),
              ElevatedButton(onPressed: () {}, child: Text('btn')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.length, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(calls.last.arguments, {'enabled': true});
  });

  testWidgets(
    'nested SensitiveScreenProtection increments counter but calls native once',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      await tester.pumpWidget(
        MaterialApp(
          home: SensitiveScreenProtection(
            child: SensitiveScreenProtection(child: const _ProtectedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // only one native enable
      expect(calls.length, 1);

      // dispose by rebuilding without protections
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      // native disable called once
      expect(calls.length, 2);
    },
  );

  testWidgets('failed navigation does not leak secure count', (tester) async {
    final calls = <bool>[];
    ScreenSecurityService.setPlatformSetter((enabled) async {
      calls.add(enabled);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _FaultyProtectedRoute(),
                    ),
                  ),
                  child: const Text('PushValid'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('Ordinary')),
                    ),
                  ),
                  child: const Text('PushOrdinary'),
                ),
              ],
            );
          },
        ),
      ),
    );

    expect(calls, isEmpty);

    await tester.tap(find.text('PushValid'));
    await tester.pump();
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(
      exception,
      isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('intentional'),
      ),
    );

    await tester.pumpAndSettle();

    final navigator = tester.state(find.byType(Navigator)) as NavigatorState;
    navigator.pop();
    await tester.pumpAndSettle();

    expect(calls, [true, false]);

    // Ensure ordinary route remains unprotected after failure.
    await tester.tap(find.text('PushOrdinary'));
    await tester.pumpAndSettle();

    expect(calls, [true, false]);
  });
}

class _FaultyProtectedRoute extends StatefulWidget {
  const _FaultyProtectedRoute();

  @override
  State<_FaultyProtectedRoute> createState() => _FaultyProtectedRouteState();
}

class _FaultyProtectedRouteState extends State<_FaultyProtectedRoute> {
  bool _shouldThrow = false;

  @override
  void initState() {
    super.initState();
    ScreenSecurityService.acquire();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _shouldThrow = true);
    });
  }

  @override
  void dispose() {
    ScreenSecurityService.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldThrow) {
      throw Exception('intentional broken protected route');
    }
    return const SizedBox.shrink();
  }
}

class _ProtectedBox extends StatelessWidget {
  const _ProtectedBox();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// _ThrowingWidget removed; navigation-failure tests require specialized handling.
