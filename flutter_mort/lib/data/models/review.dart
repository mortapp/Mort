class MortReview {
  const MortReview({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.subjectId,
    required this.rating,
    required this.moderationStatus,
    this.body,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String reviewerId;
  final String subjectId;
  final int rating;
  final String? body;
  final String moderationStatus;
  final DateTime? createdAt;

  factory MortReview.fromMap(Map<String, dynamic> map) {
    return MortReview(
      id: map['id'].toString(),
      jobId: map['job_id'].toString(),
      reviewerId: map['reviewer_id'].toString(),
      subjectId: map['subject_id'].toString(),
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      body: map['body'] as String?,
      moderationStatus:
          (map['moderation_status'] as String?) ?? 'pending_review',
      createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
    );
  }
}
