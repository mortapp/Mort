import '../models/review.dart';
import 'repository_base.dart';

class ReviewsRepository extends RepositoryBase {
  Future<MortReview> createReview({
    required String jobId,
    required String subjectId,
    required int rating,
    String? body,
  }) async {
    final reviewerId = requireUserId();
    final row = await client
        .from('reviews')
        .insert({
          'job_id': jobId,
          'reviewer_id': reviewerId,
          'subject_id': subjectId,
          'rating': rating,
          'body': body?.trim().isEmpty == true ? null : body?.trim(),
        })
        .select()
        .single();
    return MortReview.fromMap(Map<String, dynamic>.from(row));
  }

  Future<MortReview?> reviewForJobByCurrentUser(String jobId) async {
    final row = await client
        .from('reviews')
        .select()
        .eq('job_id', jobId)
        .eq('reviewer_id', requireUserId())
        .maybeSingle();
    return row == null
        ? null
        : MortReview.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<MortReview>> listReceived() async {
    final rows = await client
        .from('reviews')
        .select()
        .eq('subject_id', requireUserId())
        .eq('moderation_status', 'approved')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(MortReview.fromMap).toList(growable: false);
  }
}
