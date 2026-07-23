import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/job.dart';
import 'repository_base.dart';

const _jobSelect =
    '*, profiles:poster_id(display_name,verification_status,avatar_path)';

class JobsRepository extends RepositoryBase {
  Future<List<Job>> listOpenJobs({
    JobSearchFilters filters = const JobSearchFilters(),
    String? category,
    int limit = 40,
  }) async {
    requireUserId();
    final isTestAccount = await client.rpc('current_profile_is_test') == true;
    var query = client
        .from('jobs')
        .select(_jobSelect)
        .eq('status', 'open')
        .eq('applications_open', true)
        .eq('is_test', isTestAccount);

    final selectedCategory = category ?? filters.category;
    if (selectedCategory != null &&
        selectedCategory.isNotEmpty &&
        selectedCategory != 'All') {
      query = query.eq('category', selectedCategory);
    }
    if (filters.minimumPayCents != null) {
      query = query.gte('pay_amount_cents', filters.minimumPayCents!);
    }
    if (filters.paymentType != null) {
      query = query.eq('payment_type', filters.paymentType!);
    }
    if (filters.scheduleType != null) {
      query = query.eq('schedule_type', filters.scheduleType!);
    }
    if (filters.verificationRequirement != null) {
      query = query.eq(
        'verification_requirement',
        filters.verificationRequirement!,
      );
    }
    if (filters.requiresGuardianApproval != null) {
      query = query.eq(
        'requires_guardian_approval',
        filters.requiresGuardianApproval!,
      );
    }
    if (filters.workEnvironment != null) {
      query = query.eq('work_environment', filters.workEnvironment!);
    }
    final city = filters.city?.trim();
    if (city != null && city.isNotEmpty) {
      query = query.ilike('city', city.replaceAll(RegExp(r'[%_,]'), ''));
    }
    final state = filters.state?.trim().toUpperCase();
    if (state != null && state.isNotEmpty) {
      query = query.eq('state', state.replaceAll(RegExp(r'[^A-Z]'), ''));
    }

    final keyword = filters.keyword
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .trim();
    if (keyword.isNotEmpty) {
      query = query.or(
        'title.ilike.%$keyword%,summary.ilike.%$keyword%,description.ilike.%$keyword%',
      );
    }

    final rows = switch (filters.sort) {
      JobSort.highestPay =>
        await query.order('pay_amount_cents', ascending: false).limit(limit),
      JobSort.soonestStart =>
        await query
            .order('starts_at', ascending: true, nullsFirst: false)
            .limit(limit),
      JobSort.newest =>
        await query.order('created_at', ascending: false).limit(limit),
    };
    return _jobs(rows);
  }

  Future<List<Job>> listMyJobs() async {
    final id = requireUserId();
    final rows = await client
        .from('jobs')
        .select(_jobSelect)
        .eq('poster_id', id)
        .order('updated_at', ascending: false);
    return _jobs(rows);
  }

  Future<List<Job>> listSavedJobs() async {
    requireUserId();
    return _jobs(await client.rpc('list_my_saved_jobs'));
  }

  Future<bool> isSaved(String jobId) async {
    final id = requireUserId();
    final row = await client
        .from('saved_jobs')
        .select('job_id')
        .eq('user_id', id)
        .eq('job_id', jobId)
        .maybeSingle();
    return row != null;
  }

  Future<void> saveJob(String jobId) async {
    final id = requireUserId();
    await client.from('saved_jobs').upsert({'user_id': id, 'job_id': jobId});
  }

  Future<void> unsaveJob(String jobId) async {
    final id = requireUserId();
    await client
        .from('saved_jobs')
        .delete()
        .eq('user_id', id)
        .eq('job_id', jobId);
  }

  Future<Job?> getJob(String id) async {
    final row = await client
        .from('jobs')
        .select(_jobSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Job.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Job> saveDraft(JobDraft draft) => _save(draft, publish: false);

  Future<Job> publish(JobDraft draft) => _save(draft, publish: true);

  Future<Job> createJob({
    required String title,
    required String description,
    required String category,
    required String locationText,
    required String city,
    required String state,
    int? payAmountCents,
    bool requiresGuardianApproval = false,
  }) {
    final cleanDescription = description.trim();
    final summary = cleanDescription.length <= 240
        ? cleanDescription
        : cleanDescription.substring(0, 240);
    final draft = JobDraft(clientRequestId: const Uuid().v4())
      ..title = title.trim()
      ..summary = summary
      ..description = cleanDescription
      ..category = category.trim()
      ..locationText = locationText.trim()
      ..city = city.trim()
      ..state = state.trim().toUpperCase()
      ..payAmountCents = payAmountCents
      ..requiresGuardianApproval = requiresGuardianApproval;
    return publish(draft);
  }

  Future<Job> _save(JobDraft draft, {required bool publish}) async {
    final result = await client.rpc(
      'save_job_draft_or_publish',
      params: {
        'p_job_id': draft.id,
        'p_client_request_id': draft.clientRequestId,
        'p_payload': draft.toMap(),
        'p_publish': publish,
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    final jobMap = Map<String, dynamic>.from(map['job'] as Map);
    final job = Job.fromMap(jobMap);
    draft.id = job.id;
    return job;
  }

  Future<Job?> manageJob(String jobId, String action) async {
    final result = await client.rpc(
      'manage_job',
      params: {'p_job_id': jobId, 'p_action': action},
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    final job = map['job'];
    return job is Map ? Job.fromMap(Map<String, dynamic>.from(job)) : null;
  }

  Future<List<Map<String, dynamic>>> listStatusEvents(String jobId) async {
    final rows = await client
        .from('job_status_events')
        .select()
        .eq('job_id', jobId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static List<Job> _jobs(Object? rows) {
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(Job.fromMap).toList(growable: false);
  }

  static Map<String, dynamic> _rpcMap(Object? result) {
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
      (result['message'] as String?) ??
          'We could not complete that job action.',
    );
  }
}
