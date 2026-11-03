import 'package:flutter_mort/data/models/progression.dart';
import 'package:flutter_test/flutter_test.dart';

int threshold(int level) =>
    (level - 1) * 100 + 25 * (level - 1) * (level - 2) ~/ 2;

void main() {
  test('all rank boundaries and level progress use cumulative XP', () {
    const ranks = <int, String>{
      1: 'bronze',
      10: 'bronze',
      11: 'silver',
      20: 'silver',
      21: 'gold',
      30: 'gold',
      31: 'platinum',
      40: 'platinum',
      41: 'diamond',
      50: 'diamond',
    };
    for (final entry in ranks.entries) {
      final level = entry.key;
      final snapshot = ProgressionSnapshot.fromMap({
        'xp_total': threshold(level),
        'level': level,
        'rank': entry.value,
        'next_level_xp': level == 50 ? null : threshold(level + 1),
        'motion_tokens_balance': 0,
        'current_safety_streak': 0,
        'best_safety_streak': 0,
        'events': [],
        'badges': [],
        'cosmetics': [],
      });
      expect(snapshot.level, level);
      expect(snapshot.rank, entry.value);
      expect(snapshot.levelProgress, level == 50 ? 1 : 0);
    }
  });

  test('malformed optional lists do not crash the progression hub', () {
    final snapshot = ProgressionSnapshot.fromMap({
      'xp_total': threshold(3),
      'level': 3,
      'rank': 'bronze',
      'next_level_xp': threshold(4),
      'motion_tokens_balance': 0,
      'current_safety_streak': 0,
      'best_safety_streak': 0,
      'events': 'invalid',
      'badges': [null, 4, 'jobs_1'],
      'cosmetics': [null],
    });
    expect(snapshot.events, isEmpty);
    expect(snapshot.badges, ['jobs_1']);
    expect(snapshot.cosmetics, isEmpty);
  });

  test('level and rank milestones come from server event metadata', () {
    final event = ProgressionEvent.fromMap({
      'type': 'completed_job',
      'xp': 100,
      'tokens': 65,
      'at': '2026-09-20T12:00:00Z',
      'new_level': 11,
      'new_rank': 'silver',
    });
    expect(event.newLevel, 11);
    expect(event.newRank, 'silver');
    expect(event.tokens, 65);
  });

  test(
    'missing balance or unknown rank rejects a malformed server snapshot',
    () {
      expect(
        () => ProgressionSnapshot.fromMap({'level': 1, 'rank': 'bronze'}),
        throwsFormatException,
      );
      expect(
        () => ProgressionSnapshot.fromMap({
          'xp_total': 0,
          'level': 1,
          'rank': 'mythic',
          'next_level_xp': 100,
          'motion_tokens_balance': 0,
          'current_safety_streak': 0,
          'best_safety_streak': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => ProgressionSnapshot.fromMap({
          'xp_total': threshold(11),
          'level': 11,
          'rank': 'bronze',
          'next_level_xp': threshold(12),
          'motion_tokens_balance': 0,
          'current_safety_streak': 0,
          'best_safety_streak': 0,
        }),
        throwsFormatException,
      );
    },
  );
}
