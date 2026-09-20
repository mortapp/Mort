import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import 'repository_base.dart';
import 'uploads_repository.dart';

class MortVerifyRepository extends RepositoryBase {
  static const bucket = 'mort-verify-evidence';

  final _uuid = const Uuid();

  Future<Map<String, dynamic>> getStatus() async {
    requireUserId();
    return _map(await client.rpc('get_mort_verify_status'));
  }

  Future<Map<String, dynamic>> start(String schoolEmail) async {
    requireUserId();
    final response = await client.functions.invoke(
      'mort-verify',
      body: {'action': 'start', 'email': schoolEmail.trim().toLowerCase()},
    );
    return _requireFunctionMap(response);
  }

  Future<Map<String, dynamic>> verifySchoolEmailCode({
    required String sessionId,
    required String code,
  }) async {
    requireUserId();
    final value = await client.rpc(
      'verify_mort_school_email_code',
      params: {'p_session_id': sessionId, 'p_code': code.trim()},
    );
    final result = _map(value);
    _requireSuccess(result);
    return result;
  }

  Future<Map<String, dynamic>> uploadSchoolId({
    required String sessionId,
    required String side,
    required Uint8List source,
  }) async {
    final userId = requireUserId();
    if (!Uuid.isValidUUID(fromString: sessionId) ||
        (side != 'front' && side != 'back')) {
      throw const MortCodedError(
        'invalid_school_id_upload',
        'Start a new verification session and try again.',
      );
    }

    final prepared = UploadsRepository.prepareVerification(source);
    final path = '$userId/$sessionId/$side/${_uuid.v4()}.jpg';
    var uploaded = false;
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            prepared.bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
              upsert: false,
            ),
          );
      uploaded = true;

      final response = await client.functions.invoke(
        'mort-verify',
        body: {
        'action': 'finalize_document',
        'session_id': sessionId,
        'storage_path': path,
        'side': side,
      },
      );
      return _requireFunctionMap(response);
    } catch (_) {
      await recordUploadFailure(
        uploadKind: 'mort_verify_school_id',
        safeCode: uploaded
            ? 'mort_verify_document_finalize_failed'
            : 'mort_verify_document_upload_failed',
      );
      if (uploaded) {
        try {
          await client.storage.from(bucket).remove([path]);
        } catch (_) {
          // Orphan cleanup is best effort. Registered evidence is retained.
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submit(String sessionId) async {
    requireUserId();
    final result = _map(
      await client.rpc(
        'submit_mort_verify_session',
        params: {'p_session_id': sessionId},
      ),
    );
    _requireSuccess(result);
    return result;
  }

  static Map<String, dynamic> _requireFunctionMap(FunctionResponse response) {
    if (response.data is! Map) {
      throw const MortCodedError(
        'invalid_response',
        'MORT Verify returned an unexpected response.',
      );
    }
    final result = Map<String, dynamic>.from(response.data as Map);
    _requireSuccess(result);
    return result;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const MortCodedError(
      'invalid_response',
      'MORT Verify returned an unexpected response.',
    );
  }

  static void _requireSuccess(Map<String, dynamic> result) {
    if (result['ok'] == true) return;
    throw MortCodedError(
      result['code'] as String? ?? 'mort_verify_failed',
      result['message'] as String? ?? 'MORT Verify could not continue.',
    );
  }
}
