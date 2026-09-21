class ProgressionBoardEntry {
  const ProgressionBoardEntry({
    required this.position,
    required this.username,
    required this.rank,
    required this.level,
    required this.score,
  });
  final int position;
  final String username;
  final String rank;
  final int level;
  final int score;

  factory ProgressionBoardEntry.fromMap(Map<String, dynamic> map) =>
      ProgressionBoardEntry(
        position: _int(map['position']),
        username: map['username'] is String ? map['username'] as String : '',
        rank: map['rank'] is String ? map['rank'] as String : 'bronze',
        level: _int(map['level']),
        score: _int(map['score']),
      );
}

class ProgressionEvent {
  const ProgressionEvent({
    required this.type,
    required this.xp,
    required this.tokens,
    required this.at,
    required this.newLevel,
    required this.newRank,
  });

  final String type;
  final int xp;
  final int tokens;
  final DateTime? at;
  final int? newLevel;
  final String? newRank;

  factory ProgressionEvent.fromMap(Map<String, dynamic> map) =>
      ProgressionEvent(
        type: map['type'] is String ? map['type'] as String : 'activity',
        xp: _int(map['xp']),
        tokens: _int(map['tokens']),
        at: DateTime.tryParse(map['at'] is String ? map['at'] as String : ''),
        newLevel: map['new_level'] is num
            ? (map['new_level'] as num).toInt()
            : null,
        newRank: map['new_rank'] is String ? map['new_rank'] as String : null,
      );
}

class ProgressionCosmetic {
  const ProgressionCosmetic({
    required this.key,
    required this.title,
    required this.cost,
    required this.owned,
    required this.presentation,
    required this.equipped,
  });

  final String key;
  final String title;
  final int cost;
  final bool owned;
  final String presentation;
  final bool equipped;

  factory ProgressionCosmetic.fromMap(Map<String, dynamic> map) =>
      ProgressionCosmetic(
        key: map['key'] is String ? map['key'] as String : '',
        title: map['title'] is String ? map['title'] as String : 'Cosmetic',
        cost: _int(map['cost']),
        owned: map['owned'] == true,
        presentation: map['presentation'] is String
            ? map['presentation'] as String
            : '',
        equipped: map['equipped'] == true,
      );
}

class ProgressionGoal {
  const ProgressionGoal({
    required this.title,
    required this.progress,
    required this.target,
  });
  final String title;
  final int progress;
  final int target;
  factory ProgressionGoal.fromMap(Map<String, dynamic> map) => ProgressionGoal(
    title: map['title'] is String ? map['title'] as String : 'Goal',
    progress: _int(map['progress']),
    target: _int(map['target']),
  );
}

class ProgressionSnapshot {
  const ProgressionSnapshot({
    required this.xpTotal,
    required this.level,
    required this.rank,
    required this.nextLevelXp,
    required this.motionTokensBalance,
    required this.currentSafetyStreak,
    required this.bestSafetyStreak,
    required this.events,
    required this.badges,
    required this.goals,
    required this.cosmetics,
  });

  final int xpTotal;
  final int level;
  final String rank;
  final int? nextLevelXp;
  final int motionTokensBalance;
  final int currentSafetyStreak;
  final int bestSafetyStreak;
  final List<ProgressionEvent> events;
  final List<String> badges;
  final List<ProgressionGoal> goals;
  final List<ProgressionCosmetic> cosmetics;

  factory ProgressionSnapshot.fromMap(Map<String, dynamic> map) {
    final xp = _requiredNonNegative(map, 'xp_total');
    final level = _requiredNonNegative(map, 'level');
    final tokens = _requiredNonNegative(map, 'motion_tokens_balance');
    final streak = _requiredNonNegative(map, 'current_safety_streak');
    final bestStreak = _requiredNonNegative(map, 'best_safety_streak');
    final rank = map['rank'];
    if (level < 1 ||
        level > 50 ||
        rank is! String ||
        !const {
          'bronze',
          'silver',
          'gold',
          'platinum',
          'diamond',
        }.contains(rank)) {
      throw const FormatException('Invalid progression rank or level.');
    }
    final expectedRank = level <= 10
        ? 'bronze'
        : level <= 20
        ? 'silver'
        : level <= 30
        ? 'gold'
        : level <= 40
        ? 'platinum'
        : 'diamond';
    if (rank != expectedRank) {
      throw const FormatException('Inconsistent progression rank.');
    }
    final nextLevelXp = map['next_level_xp'] == null
        ? null
        : _requiredNonNegative(map, 'next_level_xp');
    if (level < 50 && (nextLevelXp == null || nextLevelXp <= xp)) {
      throw const FormatException('Invalid progression XP threshold.');
    }
    return ProgressionSnapshot(
      xpTotal: xp,
      level: level,
      rank: rank,
      nextLevelXp: nextLevelXp,
      motionTokensBalance: tokens,
      currentSafetyStreak: streak,
      bestSafetyStreak: bestStreak,
      events: _maps(
        map['events'],
      ).map(ProgressionEvent.fromMap).toList(growable: false),
      badges: (map['badges'] is List ? map['badges'] as List : const [])
          .whereType<String>()
          .toList(growable: false),
      goals: _maps(
        map['goals'],
      ).map(ProgressionGoal.fromMap).toList(growable: false),
      cosmetics: _maps(
        map['cosmetics'],
      ).map(ProgressionCosmetic.fromMap).toList(growable: false),
    );
  }

  String get rankLabel =>
      rank.isEmpty ? 'Bronze' : '${rank[0].toUpperCase()}${rank.substring(1)}';
  String? get nextRank => switch (rank) {
    'bronze' => 'Silver',
    'silver' => 'Gold',
    'gold' => 'Platinum',
    'platinum' => 'Diamond',
    _ => null,
  };
  double get levelProgress {
    if (nextLevelXp == null) return 1;
    final previous = (level - 1) * 100 + 25 * (level - 1) * (level - 2) ~/ 2;
    final span = nextLevelXp! - previous;
    return span <= 0 ? 0 : ((xpTotal - previous) / span).clamp(0.0, 1.0);
  }
}

int _int(Object? value) => value is num ? value.toInt() : 0;

int _requiredNonNegative(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! num || value < 0 || value.toInt() != value) {
    throw FormatException('Invalid progression field: $key');
  }
  return value.toInt();
}

Iterable<Map<String, dynamic>> _maps(Object? value) sync* {
  if (value is! List) return;
  for (final item in value) {
    if (item is Map) yield Map<String, dynamic>.from(item);
  }
}
