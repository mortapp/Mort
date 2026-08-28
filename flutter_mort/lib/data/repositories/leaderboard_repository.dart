import '../../core/errors/mort_error.dart';
import '../models/leaderboard.dart';
import 'repository_base.dart';

class LeaderboardRepository extends RepositoryBase {
  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 20}) async {
    final result = await client.rpc(
      'get_leaderboard_v1',
      params: {'p_limit': limit},
    );
    final map = _map(result);
    _throwIfFailed(map);
    final entries = (map['entries'] as List? ?? const [])
        .map(
          (entry) =>
              LeaderboardEntry.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);
    return entries;
  }

  Future<MyLeaderboardRank> getMyRank() async {
    final result = await client.rpc('get_my_leaderboard_rank_v1');
    final map = _map(result);
    _throwIfFailed(map);
    return MyLeaderboardRank.fromMap(map);
  }

  Future<bool> setOptOut(bool optOut) async {
    final result = await client.rpc(
      'set_leaderboard_opt_out_v1',
      params: {'p_opt_out': optOut},
    );
    final map = _map(result);
    _throwIfFailed(map);
    return map['leaderboard_opt_out'] as bool? ?? optOut;
  }

  static Map<String, dynamic> _map(Object? result) {
    if (result is! Map) {
      throw const MortCodedError(
        'unknown_permission_failure',
        'The backend returned an unexpected response.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  static void _throwIfFailed(Map<String, dynamic> result) {
    if (result['ok'] == true) return;
    throw MortCodedError(
      (result['code'] as String?) ?? 'unknown_permission_failure',
      (result['message'] as String?) ?? 'We could not load the leaderboard.',
    );
  }
}
