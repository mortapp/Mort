import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/safe_image.dart';
import '../../core/errors/mort_error.dart';
import 'profile_repository.dart';
import 'repository_base.dart';

class AvatarRepository extends RepositoryBase {
  AvatarRepository({ImagePicker? picker, ProfileRepository? profiles})
    : _picker = picker ?? ImagePicker(),
      _profiles = profiles ?? ProfileRepository();

  static const bucket = 'profile-avatars';
  static const maximumSourceBytes = 5 * 1024 * 1024;
  static const _maximumSignedUrlEntries = 64;
  static const _signedUrlLifetime = Duration(minutes: 55);

  final ImagePicker _picker;
  final ProfileRepository _profiles;
  final Map<String, _SignedAvatarEntry> _signedUrls = {};

  Future<XFile?> choosePhoto({ImageSource source = ImageSource.gallery}) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('camera') &&
          (code.contains('denied') || code.contains('restricted'))) {
        throw const MortCodedError(
          'avatar_camera_permission_denied',
          'Camera access is off. Enable Camera for MORT in device settings, then try again.',
        );
      }
      if ((code.contains('photo') || code.contains('gallery')) &&
          (code.contains('denied') || code.contains('restricted'))) {
        throw const MortCodedError(
          'avatar_photo_permission_denied',
          'Photo access is off. Enable Photos for MORT in device settings, then try again.',
        );
      }
      throw const MortCodedError(
        'avatar_picker_unavailable',
        'The photo picker is unavailable right now. Try again or use the other photo option.',
      );
    }
  }

  Future<String> uploadAvatar(XFile file, {String? previousPath}) async {
    final processed = await prepareAvatar(file);
    return uploadPreparedAvatar(processed, previousPath: previousPath);
  }

  Future<Uint8List> prepareAvatar(XFile file) async {
    final source = await file.readAsBytes();
    return processAvatarBytes(source);
  }

  Future<String> uploadPreparedAvatar(
    Uint8List processed, {
    String? previousPath,
  }) async {
    final userId = requireUserId();
    final path = '$userId/${const Uuid().v4()}.jpg';

    try {
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            processed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      await recordUploadFailure(
        uploadKind: 'avatar',
        safeCode: 'avatar_storage_upload_failed',
      );
      rethrow;
    }

    try {
      final persisted = await _profiles
          .setAvatarPath(path)
          .timeout(const Duration(seconds: 20));
      if (persisted.id != userId || persisted.avatarPath != path) {
        throw StateError('The server did not confirm the new avatar path.');
      }
    } catch (_) {
      await recordUploadFailure(
        uploadKind: 'avatar',
        safeCode: 'avatar_profile_update_failed',
      );
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {
        await _recordCleanup(path, 'profile_update_compensation_failed');
      }
      rethrow;
    }

    if (previousPath != null && previousPath != path) {
      try {
        await client.storage.from(bucket).remove([previousPath]);
      } catch (_) {
        await _recordCleanup(previousPath, 'replaced_avatar_delete_failed');
      }
    }
    clearSignedUrlCache(profileId: userId);
    return path;
  }

  Future<void> removeAvatar(String? currentPath) async {
    final userId = requireUserId();
    final persisted = await _profiles.setAvatarPath(null);
    if (persisted.id != userId || persisted.avatarPath != null) {
      throw StateError('The server did not confirm avatar removal.');
    }
    if (currentPath != null) {
      try {
        await client.storage.from(bucket).remove([currentPath]);
      } catch (_) {
        await _recordCleanup(currentPath, 'removed_avatar_delete_failed');
      }
    }
    clearSignedUrlCache(profileId: userId);
  }

  Future<String?> signedAvatarUrl({
    required String profileId,
    required String? avatarPath,
    DateTime? avatarUpdatedAt,
    bool forceRefresh = false,
  }) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    final cacheKey = _cacheKey(profileId, avatarPath, avatarUpdatedAt);
    final now = DateTime.now();
    final cached = _signedUrls[cacheKey];
    if (!forceRefresh && cached != null && cached.expiresAt.isAfter(now)) {
      return cached.future;
    }
    if (forceRefresh) _signedUrls.remove(cacheKey);
    final future = _fetchSignedUrl(
      profileId: profileId,
      avatarPath: avatarPath,
      avatarUpdatedAt: avatarUpdatedAt,
    );
    _signedUrls[cacheKey] = _SignedAvatarEntry(
      future: future,
      expiresAt: now.add(_signedUrlLifetime),
    );
    _trimSignedUrlCache();
    try {
      return await future;
    } catch (_) {
      _signedUrls.remove(cacheKey);
      rethrow;
    }
  }

  Future<String?> _fetchSignedUrl({
    required String profileId,
    required String avatarPath,
    required DateTime? avatarUpdatedAt,
  }) async {
    final response = await client.functions
        .invoke(
          'avatar-url',
          body: {'profileId': profileId, 'avatarPath': avatarPath},
        )
        .timeout(const Duration(seconds: 15));
    final data = response.data;
    if (data is! Map) {
      throw StateError('The avatar service returned an invalid response.');
    }
    final signedUrl = data['signedUrl'];
    if (signedUrl == null) return null;
    if (signedUrl is! String || signedUrl.isEmpty) {
      throw StateError('The avatar service returned an invalid URL.');
    }
    final uri = Uri.parse(signedUrl);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'mortAvatarVersion':
                avatarUpdatedAt?.toUtc().millisecondsSinceEpoch.toString() ??
                '0',
          },
        )
        .toString();
  }

  String _cacheKey(
    String profileId,
    String avatarPath,
    DateTime? avatarUpdatedAt,
  ) =>
      '$profileId|$avatarPath|${avatarUpdatedAt?.toUtc().millisecondsSinceEpoch ?? 0}';

  void clearSignedUrlCache({String? profileId}) {
    if (profileId == null) {
      _signedUrls.clear();
      return;
    }
    _signedUrls.removeWhere((key, _) => key.startsWith('$profileId|'));
  }

  void _trimSignedUrlCache() {
    while (_signedUrls.length > _maximumSignedUrlEntries) {
      _signedUrls.remove(_signedUrls.keys.first);
    }
  }

  Future<void> _recordCleanup(String path, String reasonCode) async {
    try {
      await client.rpc(
        'record_avatar_orphan_cleanup',
        params: {'p_object_path': path, 'p_reason_code': reasonCode},
      );
    } catch (_) {
      // The persisted avatar remains authoritative. Restricted maintenance can
      // also discover unreferenced owner objects independently.
    }
  }

  static Uint8List processAvatarBytes(Uint8List source) {
    return SafeImageProcessor.avatar(source, maximumBytes: maximumSourceBytes);
  }
}

class _SignedAvatarEntry {
  const _SignedAvatarEntry({required this.future, required this.expiresAt});

  final Future<String?> future;
  final DateTime expiresAt;
}
