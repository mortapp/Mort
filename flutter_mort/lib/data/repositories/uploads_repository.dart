import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/utils/safe_image.dart';
import 'repository_base.dart';

class PreparedProofImage {
  const PreparedProofImage._(this.bytes);

  final Uint8List bytes;
}

class PreparedVerificationImage {
  const PreparedVerificationImage._(this.bytes);

  final Uint8List bytes;
}

class UploadsRepository extends RepositoryBase {
  static const proofBucket = 'proof-uploads';
  static const verificationBucket = 'verification-uploads';
  static const reportBucket = 'report-uploads';
  static const maximumProofSourceBytes = 10 * 1024 * 1024;
  static const maximumVerificationSourceBytes = 10 * 1024 * 1024;

  final _uuid = const Uuid();

  String newProofSubmissionId() => _uuid.v4();

  String newVerificationSubmissionId() => _uuid.v4();

  static PreparedProofImage prepareProof(Uint8List source) {
    return PreparedProofImage._(
      SafeImageProcessor.proof(source, maximumBytes: maximumProofSourceBytes),
    );
  }

  static PreparedVerificationImage prepareVerification(Uint8List source) {
    return PreparedVerificationImage._(
      SafeImageProcessor.verification(
        source,
        maximumBytes: maximumVerificationSourceBytes,
      ),
    );
  }

  Future<String> uploadProof({
    required String applicationId,
    required String submissionId,
    required PreparedProofImage proof,
    String? note,
  }) async {
    final userId = requireUserId();
    if (!Uuid.isValidUUID(fromString: submissionId)) {
      throw const MortCodedError(
        'invalid_proof_submission',
        'Start a new proof upload and try again.',
      );
    }
    final path = '$userId/$submissionId.jpg';
    var uploadedOrAlreadyPresent = false;
    try {
      try {
        await client.storage
            .from(proofBucket)
            .uploadBinary(
              path,
              proof.bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ),
            );
        uploadedOrAlreadyPresent = true;
      } on StorageException catch (error) {
        if (error.statusCode != '409') rethrow;
        uploadedOrAlreadyPresent = true;
      }

      final value = await client.rpc(
        'submit_application_proof',
        params: {
          'p_proof_id': submissionId,
          'p_application_id': applicationId,
          'p_storage_path': path,
          'p_note': note,
        },
      );
      if (value is! Map) {
        throw const MortCodedError(
          'unknown_permission_failure',
          'The backend returned an unexpected proof response.',
        );
      }
      final result = Map<String, dynamic>.from(value);
      if (result['ok'] != true) {
        throw MortCodedError(
          (result['code'] as String?) ?? 'unknown_permission_failure',
          (result['message'] as String?) ?? 'We could not submit this proof.',
        );
      }
      return path;
    } catch (_) {
      await recordUploadFailure(
        uploadKind: 'proof',
        safeCode: uploadedOrAlreadyPresent
            ? 'proof_manifest_failed'
            : 'proof_storage_upload_failed',
      );
      if (uploadedOrAlreadyPresent) {
        try {
          await client.storage.from(proofBucket).remove([path]);
        } catch (_) {
          // Attached proof cannot be removed; orphan cleanup is best effort.
        }
      }
      rethrow;
    }
  }

  Future<String> uploadVerificationDocument({
    required String submissionId,
    required String businessName,
    required String businessType,
    required PreparedVerificationImage document,
    String? notes,
  }) async {
    requireUserId();
    throw const MortCodedError(
      'business_verification_provider_required',
      'Business verification is unavailable until an approved provider and legal workflow are connected. Do not upload a document.',
    );
  }

  Future<List<Map<String, dynamic>>> listMyVerificationRequests() async {
    final rows = await client
        .from('business_verifications')
        .select('id,business_name,business_type,status,created_at,updated_at')
        .eq('adult_id', requireUserId())
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> signedUrl(String bucket, String path, {int expiresIn = 600}) {
    return client.storage.from(bucket).createSignedUrl(path, expiresIn);
  }
}
