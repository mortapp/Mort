import 'dart:convert';
import 'dart:io';

import 'package:flutter_mort/data/repositories/monetization_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Repository extends MonetizationRepository {
  _Repository(this.testClient);

  final SupabaseClient testClient;

  @override
  SupabaseClient get client => testClient;
}

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late MonetizationRepository repository;
  Map<String, dynamic>? responseRow;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-test-key',
    );
    repository = _Repository(client);
    server.listen((request) async {
      await request.drain<void>();
      final wantsSingle =
          request.headers.value(HttpHeaders.acceptHeader) ==
          'application/vnd.pgrst.object+json';
      request.response.headers.contentType = ContentType.json;
      if (wantsSingle && responseRow == null) {
        request.response.statusCode = HttpStatus.notAcceptable;
        request.response.write(
          jsonEncode({
            'code': 'PGRST116',
            'message': 'Cannot coerce the result to a single JSON object',
            'details': 'The result contains 0 rows',
            'hint': null,
          }),
        );
      } else {
        request.response.write(
          jsonEncode(
          wantsSingle ? responseRow : [?responseRow],
          ),
        );
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('entitlement table RPC resolves its one authoritative row', () async {
    responseRow = {
      'premium_active': false,
      'ad_free_active': false,
      'adult_pro_active': false,
      'entitlements': <String>[],
    };
    final result = await repository.getMyEntitlements();
    expect(result, responseRow);
    expect(result['premium_active'], isFalse);
  });

  test('ad eligibility table RPC resolves the server decision', () async {
    responseRow = {
      'allowed': false,
      'reason': 'Ad-free entitlement active.',
      'request_non_personalized': true,
    };
    final result = await repository.adEligibility('job_feed', 'banner');
    expect(result, responseRow);
    expect(result['allowed'], isFalse);
  });

  test('missing authoritative row raises a provider error', () async {
    responseRow = null;
    await expectLater(
      repository.getMyEntitlements(),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repository.adEligibility('job_feed', 'banner'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
