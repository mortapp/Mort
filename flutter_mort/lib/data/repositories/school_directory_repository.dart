import '../models/school_directory_entry.dart';
import '../services/supabase_service.dart';

class SchoolDirectoryRepository {
  Future<Map<String, dynamic>> requestSchool({
    required String schoolName,
    required String city,
    required String state,
    String? website,
    String? studentDomain,
  }) async {
    final result = await SupabaseService.client.rpc(
      'request_school_directory_entry',
      params: {
        'p_school_name': schoolName.trim(),
        'p_city': city.trim(),
        'p_state': state.trim().toUpperCase(),
        'p_website': website?.trim().isEmpty == true ? null : website?.trim(),
        'p_student_domain': studentDomain?.trim().isEmpty == true
            ? null
            : studentDomain?.trim().toLowerCase(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<SchoolDirectoryEntry>> search(String query) async {
    final result = await SupabaseService.client.rpc(
      'search_schools',
      params: {'p_query': query.trim(), 'p_limit': 25},
    );
    return (result as List<dynamic>)
        .map(
          (row) => SchoolDirectoryEntry.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> isEmailEligible({
    required String schoolId,
    required String email,
  }) async {
    final result = await SupabaseService.client.rpc(
      'check_school_email_for_signup',
      params: {'p_school_id': schoolId, 'p_email': email.trim()},
    );
    return (result as Map<String, dynamic>)['eligible'] == true;
  }

  Future<Map<String, dynamic>> verifyCurrentEmail({
    required String schoolId,
    required String email,
  }) async {
    final result = await SupabaseService.client.rpc(
      'verify_my_school_email',
      params: {'p_school_id': schoolId, 'p_school_email': email.trim()},
    );
    return Map<String, dynamic>.from(result as Map);
  }
}
