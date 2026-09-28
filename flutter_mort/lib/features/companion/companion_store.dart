import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'companion_catalog.dart';

/// Local cosmetic preference only. This storage never represents entitlement.
class CompanionLook {
  const CompanionLook({
    this.companionId = 'wix',
    this.colorId = 'default',
    this.accessoryId = 'none',
    this.itemId = 'none',
    this.auraId = 'none',
    this.environmentId = 'default',
  });

  final String companionId;
  final String colorId;
  final String accessoryId;
  final String itemId;
  final String auraId;
  final String environmentId;

  CompanionLook copyWith({
    String? companionId,
    String? colorId,
    String? accessoryId,
    String? itemId,
    String? auraId,
    String? environmentId,
  }) => CompanionLook(
    companionId: companionId ?? this.companionId,
    colorId: colorId ?? this.colorId,
    accessoryId: accessoryId ?? this.accessoryId,
    itemId: itemId ?? this.itemId,
    auraId: auraId ?? this.auraId,
    environmentId: environmentId ?? this.environmentId,
  );

  Map<String, String> toJson() => {
    'companionId': companionId,
    'colorId': colorId,
    'accessoryId': accessoryId,
    'itemId': itemId,
    'auraId': auraId,
    'environmentId': environmentId,
  };

  static CompanionLook fromJson(Object? value, {required bool hasPro}) {
    if (value is! Map<String, dynamic>) return const CompanionLook();
    String allowed(String key, List<CosmeticOption> options, String fallback) {
      final token = value[key];
      return token is String && options.any((option) => option.id == token)
          ? token
          : fallback;
    }

    final storedId = value['companionId'];
    return CompanionLook(
      companionId:
          storedId is String && canSelectCompanion(storedId, hasPro: hasPro)
          ? storedId
          : 'wix',
      colorId: allowed('colorId', companionColors, 'default'),
      accessoryId: allowed('accessoryId', companionAccessories, 'none'),
      itemId: allowed('itemId', companionItems, 'none'),
      auraId: allowed('auraId', companionAuras, 'none'),
      environmentId: allowed('environmentId', companionEnvironments, 'default'),
    );
  }
}

class CompanionStore {
  static String storageKey(String userId) => 'mort.companion.look.$userId';
  static String savedKey(String userId) => 'mort.companion.saved.$userId';

  Future<CompanionLook> load(String userId, {required bool hasPro}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey(userId));
    if (raw == null) return const CompanionLook();
    try {
      return CompanionLook.fromJson(jsonDecode(raw), hasPro: hasPro);
    } on FormatException {
      return const CompanionLook();
    }
  }

  Future<void> save(
    String userId,
    CompanionLook look, {
    required bool hasPro,
  }) async {
    if (!canSelectCompanion(look.companionId, hasPro: hasPro)) {
      throw StateError('Companion is unavailable.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(storageKey(userId), jsonEncode(look.toJson()))) {
      throw StateError('Companion look was not saved.');
    }
  }

  Future<List<CompanionLook>> savedLooks(
    String userId, {
    required bool hasPro,
  }) async {
    final raw = await _readSaved(userId);
    return raw
        .whereType<Map<String, dynamic>>()
        .map((value) => CompanionLook.fromJson(value, hasPro: true))
        .where((look) => canSelectCompanion(look.companionId, hasPro: hasPro))
        .toList();
  }

  Future<void> addSavedLook(
    String userId,
    CompanionLook look, {
    required bool hasPro,
  }) async {
    if (!canSelectCompanion(look.companionId, hasPro: hasPro)) {
      throw StateError('Companion is unavailable.');
    }
    final raw = await _readSaved(userId);
    if (raw.length >= 20) throw StateError('Saved looks are full.');
    raw.add(look.toJson());
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(savedKey(userId), jsonEncode(raw))) {
      throw StateError('Look was not saved.');
    }
  }

  Future<void> removeSavedLook(String userId, int index) async {
    final raw = await _readSaved(userId);
    if (index < 0 || index >= raw.length) throw RangeError.index(index, raw);
    raw.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(savedKey(userId), jsonEncode(raw))) {
      throw StateError('Look was not removed.');
    }
  }

  Future<List<dynamic>> _readSaved(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(savedKey(userId));
    if (raw == null) return <dynamic>[];
    try {
      final parsed = jsonDecode(raw);
      return parsed is List ? parsed.take(20).toList() : <dynamic>[];
    } on FormatException {
      return <dynamic>[];
    }
  }
}
