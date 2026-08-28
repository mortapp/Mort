import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';

enum RemotePushPermission {
  unavailable,
  notDetermined,
  denied,
  authorized,
  provisional,
}

class RemotePushMessage {
  const RemotePushMessage({required this.data});

  final Map<String, dynamic> data;

  factory RemotePushMessage.fromFirebase(RemoteMessage message) =>
      RemotePushMessage(data: Map<String, dynamic>.from(message.data));
}

abstract interface class RemotePushProvider {
  bool get configured;
  Stream<String> get tokenRefreshes;
  Stream<RemotePushMessage> get foregroundMessages;
  Stream<RemotePushMessage> get openedMessages;

  Future<void> initialize();
  Future<RemotePushPermission> permissionStatus();
  Future<RemotePushPermission> requestPermission();
  Future<String?> registrationToken();
  Future<RemotePushMessage?> initialMessage();
  Future<void> deleteToken();
}

class DisabledRemotePushProvider implements RemotePushProvider {
  const DisabledRemotePushProvider();

  @override
  bool get configured => false;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<RemotePushMessage> get foregroundMessages => const Stream.empty();

  @override
  Stream<RemotePushMessage> get openedMessages => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<RemotePushPermission> permissionStatus() async =>
      RemotePushPermission.unavailable;

  @override
  Future<RemotePushPermission> requestPermission() async =>
      RemotePushPermission.unavailable;

  @override
  Future<String?> registrationToken() async => null;

  @override
  Future<RemotePushMessage?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {}
}

class FirebaseRemotePushProvider implements RemotePushProvider {
  bool _initialized = false;

  @override
  bool get configured =>
      AppConfig.remotePushEnabled && AppConfig.isFirebaseClientConfigured;

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<RemotePushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(RemotePushMessage.fromFirebase);

  @override
  Stream<RemotePushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(RemotePushMessage.fromFirebase);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (!configured) {
      throw StateError('Firebase remote push is not configured.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseAppId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
        storageBucket: AppConfig.firebaseStorageBucket.trim().isEmpty
            ? null
            : AppConfig.firebaseStorageBucket,
        iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
            ? AppConfig.iOSBundleId
            : null,
      ),
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    _initialized = true;
  }

  @override
  Future<RemotePushPermission> permissionStatus() async => _map(
    (await FirebaseMessaging.instance.getNotificationSettings())
        .authorizationStatus,
  );

  @override
  Future<RemotePushPermission> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return _map(settings.authorizationStatus);
  }

  @override
  Future<String?> registrationToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<RemotePushMessage?> initialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : RemotePushMessage.fromFirebase(message);
  }

  @override
  Future<void> deleteToken() => FirebaseMessaging.instance.deleteToken();

  RemotePushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized => RemotePushPermission.authorized,
    AuthorizationStatus.provisional => RemotePushPermission.provisional,
    AuthorizationStatus.denied => RemotePushPermission.denied,
    AuthorizationStatus.notDetermined => RemotePushPermission.notDetermined,
  };
}

RemotePushProvider createRemotePushProvider() =>
    AppConfig.remotePushEnabled && AppConfig.isFirebaseClientConfigured
    ? FirebaseRemotePushProvider()
    : const DisabledRemotePushProvider();

void configureRemotePushBackgroundHandler() {
  if (!kIsWeb &&
      AppConfig.remotePushEnabled &&
      AppConfig.isFirebaseClientConfigured) {
    FirebaseMessaging.onBackgroundMessage(mortRemotePushBackgroundHandler);
  }
}

@pragma('vm:entry-point')
Future<void> mortRemotePushBackgroundHandler(RemoteMessage message) async {
  // The OS displays generic content. The authenticated app reloads hosted
  // state, so this isolate never logs or persists notification payloads.
}
