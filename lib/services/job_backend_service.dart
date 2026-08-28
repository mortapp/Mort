import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/backend_job.dart';

class JobBackendService {
  JobBackendService._();
  static final JobBackendService instance = JobBackendService._();
  final _client = Supabase.instance.client;

  Future<List<BackendJob>> fetchApprovedJobs({int limit = 50}) async {
    try {
      final response = await _client
          .from('jobs')
          .select()
          .eq('job_status', 'posted')
          .eq('safety_status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      return response
          .map((item) => BackendJob.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BackendJob>> fetchTeenJobsFallback({int limit = 8}) async {
    return [];
  }
}
