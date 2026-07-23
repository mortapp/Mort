import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const mortSecureDeviceStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(storageNamespace: 'mort_auth_session'),
);
