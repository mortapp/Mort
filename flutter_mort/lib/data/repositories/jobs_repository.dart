import 'dart:collection';

import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../models/job.dart';
import 'repository_base.dart';

const _jobSelect =
    '*, profiles:poster_id(display_name,verification_status,avatar_path)';

class JobPageSessionCache {
  JobPageSessionCache({
    this.maximumEntries = 24,
    this.timeToLive = const Duration(minutes: 15),
    DateTime Function()? now,
  }) : assert(maximumEntries > 0),
       assert(!timeToLive.isNegative),
       _now = now ?? DateTime.now;

  final int maximumEntries;
  final Duration timeToLive;
  final DateTime Function() _now;
  final LinkedHashMap<String, _CachedJobPage> _entries = LinkedHashMap();

  int get length => _entries.length;

  JobPage? read(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (_now().difference(entry.storedAt) >= timeToLive) return null;
    _entries[key] = entry;
    return entry.page;
  }

  void write(String key, JobPage page) {
    final now = _now();
    _entries.removeWhere(
      (_, entry) => now.difference(entry.storedAt) >= timeToLive,
    );
    _entries.remove(key);
    _entries[key] = _CachedJobPage(page: page, storedAt: now);
    while (_entries.length > maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _CachedJobPage {
  const _CachedJobPage({required this.page, required this.storedAt});

  final JobPage page;
  final DateTime storedAt;
}

class JobsRepository extends RepositoryBase {
  final JobPageSessionCache _sessionFeedCache = JobPageSessionCache();

  Future<List<Job>> listOpenJobs({
    JobSearchFilters filters = const JobSearchFilters(),
    String? category,
  }) async {
    final selectedCategory = category == 'All' ? null : category;
    final effectiveFilters = selectedCategory == null
        ? filters
        : JobSearchFilters(
            keyword: filters.keyword,
            category: selectedCategory,
            minimumPayCents: filters.minimumPayCents,
            paymentType: filters.paymentType,
            scheduleType: filters.scheduleType,
            verificationRequirement: filters.verificationRequirement,
            requiresGuardianApproval: filters.requiresGuardianApproval,
            workEnvironment: filters.workEnvironment,
            city: filters.city,
            state: filters.state,
            transportationMethods: filters.transportationMethods,
            limit: filters.limit,
            sort: filters.sort,
          );
    return (await listOpenJobsPage(filters: effectiveFilters)).items;
  }

  Future<JobPage> listOpenJobsPage({
    JobSearchFilters filters = const JobSearchFilters(),
    JobPageCursor? cursor,
  }) async {
    final userId = requireUserId();
    final cacheKey = _feedCacheKey(userId, filters, cursor);
    try {
      final result = await client.rpc(
        'list_open_jobs_page',
        params: {
          'p_keyword': filters.keyword.trim(),
          'p_category': filters.category,
          'p_minimum_pay_cents': filters.minimumPayCents,
          'p_payment_type': filters.paymentType,
          'p_schedule_type': filters.scheduleType,
          'p_verification_requirement': filters.verificationRequirement,
          'p_requires_guardian_approval': filters.requiresGuardianApproval,
          'p_work_environment': filters.workEnvironment,
          'p_city': filters.city,
          'p_state': filters.state,
          'p_transportation_methods': filters.transportationMethods,
          'p_sort': filters.sort.apiValue,
          'p_cursor_value': cursor?.value,
          'p_cursor_id': cursor?.id,
          'p_limit': filters.limit.clamp(1, 50),
        },
      );
      final map = _rpcMap(result);
      _throwIfFailed(map);
      final page = JobPage.fromMap(map);
      _sessionFeedCache.write(cacheKey, page);
      return page;
    } on MortCodedError {
      rethrow;
    } catch (error) {
      final message = error.toString().toLowerCase();
      final connectivityFailure =
          message.contains('network') ||
          message.contains('socket') ||
          message.contains('failed host lookup') ||
          message.contains('clientexception') ||
          message.contains('connection');
      if (!connectivityFailure) rethrow;
      final cached = _sessionFeedCache.read(cacheKey);
      if (cached != null) return cached.asSessionCacheFallback();
      rethrow;
    }
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

  Future<JobSaveResult> saveDraftWithState(JobDraft draft) =>
      _saveWithState(draft, publish: false);

  Future<JobSaveResult> publishWithState(JobDraft draft) =>
      _saveWithState(draft, publish: true);

  Future<Job> createJob({
    required String title,
    required String description,
    required String category,
    required String locationText,
    required String city,
    required String state,
    int? adultJobAmountCents,
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
      ..adultJobAmountCents = adultJobAmountCents
      ..requiresGuardianApproval = requiresGuardianApproval;
    return publish(draft);
  }

  Future<Job> _save(JobDraft draft, {required bool publish}) async =>
      (await _saveWithState(draft, publish: publish)).job;

  Future<JobSaveResult> _saveWithState(
    JobDraft draft, {
    required bool publish,
  }) async {
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
    return JobSaveResult(
      job: job,
      publicationState:
          map['publication_state']?.toString() ??
          (publish
              ? job.status == 'open' && job.applicationsOpen
                    ? 'open'
                    : job.status == 'pending_review'
                    ? 'pending_review'
                    : 'not_open'
              : 'draft'),
      replayed: map['replayed'] == true,
    );
  }

  Future<Job?> manageJob(
    String jobId,
    String action, {
    String? reason,
    String? clientRequestId,
    DateTime? expectedUpdatedAt,
  }) async {
    final result = await client.rpc(
      'manage_job_v2',
      params: {
        'p_job_id': jobId,
        'p_action': action,
        'p_reason': reason,
        'p_client_request_id': clientRequestId ?? const Uuid().v4(),
        'p_expected_updated_at': expectedUpdatedAt?.toUtc().toIso8601String(),
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    final job = map['job'];
    return job is Map ? Job.fromMap(Map<String, dynamic>.from(job)) : null;
  }

  /// Saves the job site's precise, private location. Coordinates never
  /// reach the public job feed -- see save_job_private_location's
  /// server-side contract.
  Future<void> saveJobPrivateLocation(
    String jobId, {
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
    String? exactAddress,
    String? arrivalInstructions,
    String? accessNotes,
  }) async {
    final result = await client.rpc(
      'save_job_private_location',
      params: {
        'p_job_id': jobId,
        'p_exact_address': exactAddress,
        'p_arrival_instructions': arrivalInstructions,
        'p_access_notes': accessNotes,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_location_accuracy_meters': locationAccuracyMeters,
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
  }

  /// Server-computed, rounded distance (miles) from the Teen's fresh
  /// on-demand coordinates to each open job's private location. Never
  /// returns raw job coordinates -- see get_nearby_job_distances_v1.
  Future<Map<String, double>> getNearbyJobDistances(
    List<String> jobIds, {
    required double latitude,
    required double longitude,
  }) async {
    if (jobIds.isEmpty) return const {};
    final result = await client.rpc(
      'get_nearby_job_distances_v1',
      params: {
        'p_job_ids': jobIds,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    final map = _rpcMap(result);
    _throwIfFailed(map);
    final distances = <String, double>{};
    for (final entry in (map['distances'] as List? ?? const [])) {
      if (entry is Map &&
          entry['job_id'] is String &&
          entry['distance_miles'] is num) {
        distances[entry['job_id'] as String] = (entry['distance_miles'] as num)
            .toDouble();
      }
    }
    return distances;
  }

  Future<List<Map<String, dynamic>>> listStatusEvents(String jobId) async {
    final rows = await client
        .from('job_status_events')
        .select()
        .eq('job_id', jobId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> listManagementEvents(String jobId) async {
    final rows = await client
        .from('job_management_requests')
        .select('action,reason,from_status,to_status,succeeded,created_at')
        .eq('job_id', jobId)
        .not('completed_at', 'is', null)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static List<Job> _jobs(Object? rows) {
    return List<Map<String, dynamic>>.from(
      rows as List,
    ).map(Job.fromMap).toList(growable: false);
  }

  static String _feedCacheKey(
    String userId,
    JobSearchFilters filters,
    JobPageCursor? cursor,
  ) => [
    userId,
    filters.keyword,
    filters.category,
    filters.minimumPayCents,
    filters.paymentType,
    filters.scheduleType,
    filters.verificationRequirement,
    filters.requiresGuardianApproval,
    filters.workEnvironment,
    filters.city,
    filters.state,
    (filters.transportationMethods ?? const <String>[]).join(','),
    filters.limit,
    filters.sort.apiValue,
    cursor?.value,
    cursor?.id,
  ].join('|');

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
    final code = (result['code'] as String?) ?? 'unknown_permission_failure';
    final message =
        (result['message'] as String?) ??
        'We could not complete that job action.';
    final field = result['field']?.toString();
    if (field != null && field.isNotEmpty) {
      throw MortFieldCodedError(code, message, field: field);
    }
    throw MortCodedError(code, message);
  }
}
