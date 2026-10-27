import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/progression.dart';
import 'repository_base.dart';

class ProgressionRepository extends RepositoryBase {
  Future<List<ProgressionBoardEntry>> getBoard(String board) async {
    final result = await client.rpc(
      'get_progression_leaderboard_v1',
      params: {'p_board': board, 'p_limit': 20},
    );
    if (result is! Map)
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    final map = Map<String, dynamic>.from(result);
    if (map['ok'] != true)
      throw MortCodedError(
        map['code'] is String
            ? map['code'] as String
            : 'unknown_permission_failure',
        'Leaderboard is unavailable. Please try again.',
      );
    final entries = map['entries'];
    if (entries is! List) return const [];
    return entries
        .whereType<Map>()
        .map(
          (entry) =>
              ProgressionBoardEntry.fromMap(Map<String, dynamic>.from(entry)),
        )
        .toList(growable: false);
  }

  Future<ProgressionSnapshot> getMyProgression() async {
    final result = await client.rpc('get_my_progression_v1');
    if (result is! Map)
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    final map = Map<String, dynamic>.from(result);
    if (map['ok'] != true)
      throw MortCodedError(
        map['code'] is String
            ? map['code'] as String
            : 'unknown_permission_failure',
        'Progression is unavailable. Please try again.',
      );
    return ProgressionSnapshot.fromMap(map);
  }

  Future<void> unlockCosmetic(String key, {String? requestId}) async {
    final result = await client.rpc(
      'unlock_progression_cosmetic_v1',
      params: {
        'p_cosmetic_key': key,
        'p_request_id': requestId ?? const Uuid().v4(),
      },
    );
    if (result is! Map)
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    final map = Map<String, dynamic>.from(result);
    if (map['ok'] != true)
      throw MortCodedError(
        map['code'] is String
            ? map['code'] as String
            : 'unknown_permission_failure',
        'Cosmetic unlock failed. Please try again.',
      );
  }

  Future<void> equipCosmetic(String key) async {
    final result = await client.rpc(
      'equip_progression_cosmetic_v1',
      params: {'p_cosmetic_key': key},
    );
    if (result is! Map)
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    final map = Map<String, dynamic>.from(result);
    if (map['ok'] != true)
      throw MortCodedError(
        map['code'] is String
            ? map['code'] as String
            : 'unknown_permission_failure',
        'Cosmetic equip failed. Please try again.',
      );
  }
}
