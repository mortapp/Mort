class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.avatarPath,
    required this.score,
    required this.completedCount,
    required this.tier,
  });

  final int rank;
  final String? displayName;
  final String? avatarPath;
  final int score;
  final int completedCount;
  final String tier;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        displayName: json['display_name'] as String?,
        avatarPath: json['avatar_path'] as String?,
        score: (json['score'] as num?)?.toInt() ?? 0,
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
        tier: (json['tier'] as String?) ?? 'newcomer',
      );

  String get tierLabel => switch (tier) {
    'community_leader' => 'Community Leader',
    'trusted_worker' => 'Trusted Worker',
    'rising_star' => 'Rising Star',
    _ => 'Newcomer',
  };
}

class MyLeaderboardRank {
  const MyLeaderboardRank({
    required this.score,
    required this.completedCount,
    required this.reviewCount,
    required this.averageRating,
    required this.tier,
    required this.rank,
    required this.leaderboardOptOut,
  });

  final int score;
  final int completedCount;
  final int reviewCount;
  final double averageRating;
  final String tier;
  final int rank;
  final bool leaderboardOptOut;

  factory MyLeaderboardRank.fromMap(Map<String, dynamic> json) =>
      MyLeaderboardRank(
        score: (json['score'] as num?)?.toInt() ?? 0,
        completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
        tier: (json['tier'] as String?) ?? 'newcomer',
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        leaderboardOptOut: json['leaderboard_opt_out'] as bool? ?? false,
      );

  String get tierLabel => switch (tier) {
    'community_leader' => 'Community Leader',
    'trusted_worker' => 'Trusted Worker',
    'rising_star' => 'Rising Star',
    _ => 'Newcomer',
  };
}
