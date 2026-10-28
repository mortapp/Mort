import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_mort/data/repositories/applications_repository.dart';

class _TestApplicationsRepository extends ApplicationsRepository {
  _TestApplicationsRepository(this._client);

  final SupabaseClient _client;

  @override
  SupabaseClient get client => _client;
}

void main() {
  const application = <String, dynamic>{
    'id': 'application-1',
    'job_id': 'job-1',
    'teen_id': 'teen-1',
    'guardian_id': null,
    'status': 'submitted',
    'note': 'Available this weekend',
    'availability_confirmed': true,
    'created_at': '2026-10-20T12:00:00Z',
    'updated_at': '2026-10-20T12:00:00Z',
    'teen': {'display_name': 'Taylor', 'avatar_path': null},
    'jobs': {
      'id': 'job-1',
      'poster_id': 'adult-1',
      'title': 'Yard cleanup',
      'description': 'Rake leaves',
      'category': 'yard_work',
      'location_text': 'Neighborhood',
      'city': 'Indianapolis',
      'state': 'IN',
      'status': 'open',
      'requires_guardian_approval': true,
    },
  };

  late SupabaseClient client;
  late _TestApplicationsRepository repository;
  final requests = <http.Request>[];

  setUp(() {
    requests.clear();
    client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/rpc/get_my_job_applications')) {
          return http.Response(
            jsonEncode({
              'ok': true,
              'items': [application],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith(
          '/rpc/update_my_job_application_status',
        )) {
          return http.Response(
            jsonEncode({'ok': true, 'application': application}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('Not found', 404);
      }),
    );
    repository = _TestApplicationsRepository(client);
  });

  tearDown(() => client.dispose());

  test('loads one application through the production RPC contract', () async {
    final result = await repository.getApplication('application-1');

    expect(result?.id, 'application-1');
    expect(result?.teenName, 'Taylor');
    expect(result?.job?.title, 'Yard cleanup');
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/get_my_job_applications');
    expect(jsonDecode(requests.single.body), {
      'p_application_id': 'application-1',
    });
  });

  test(
    'updates status through the authorized production RPC contract',
    () async {
      final result = await repository.updateStatus(
        'application-1',
        'accepted',
        expectedUpdatedAt: DateTime.utc(2026, 10, 20, 12),
      );

      expect(result.id, 'application-1');
      expect(requests, hasLength(1));
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/update_my_job_application_status',
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['p_application_id'], 'application-1');
      expect(body['p_action'], 'accepted');
      expect(body['p_expected_updated_at'], '2026-10-20T12:00:00.000Z');
      expect(body.containsKey('p_client_request_id'), isFalse);
    },
  );
}
