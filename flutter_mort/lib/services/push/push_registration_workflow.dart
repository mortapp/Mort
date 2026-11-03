import 'remote_push_provider.dart';

typedef PushDeviceRegistration =
    Future<void> Function(String token, RemotePushPermission permission);

class PushRegistrationWorkflow {
  Future<bool> run({
    required Future<bool> Function() deliveryAvailable,
    required Future<bool> Function() pushPreferenceEnabled,
    required Future<RemotePushPermission> Function() permissionStatus,
    required Future<String?> Function() registrationToken,
    required PushDeviceRegistration register,
  }) async {
    if (!await deliveryAvailable()) return false;
    if (!await pushPreferenceEnabled()) return false;

    final permission = await permissionStatus();
    if (!_canRegister(permission)) return false;

    final token = await registrationToken();
    if (token == null || token.trim().isEmpty) return false;

    await register(token, permission);
    return true;
  }

  bool _canRegister(RemotePushPermission permission) =>
      permission == RemotePushPermission.authorized ||
      permission == RemotePushPermission.provisional;
}
