import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/supabase_service.dart';

abstract class RepositoryBase {
  static const _uuid = Uuid();

  SupabaseClient get client => SupabaseService.client;

  String requireUserId() {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('A signed-in Supabase user is required.');
    return id;
  }

  Future<void> recordUploadFailure({
    required String uploadKind,
    required String safeCode,
  }) async {
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc(
        'record_my_evidence_upload_failure',
        params: {
          'p_upload_kind': uploadKind,
          'p_safe_code': safeCode,
          'p_client_request_id': _uuid.v4(),
        },
      );
    } catch (_) {
      // Reliability telemetry is best effort and must not mask the real error.
    }
  }
}
