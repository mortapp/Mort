import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/backend_profile.dart';
import '../models/backend_transport_mode.dart';
import 'transport_mode_service.dart';
import 'profile_service.dart';

class ProfileBackendService {
  ProfileBackendService._();
  static final ProfileBackendService instance = ProfileBackendService._();

  final _client = Supabase.instance.client;

  Future<BackendProfile?> getCurrentProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return BackendProfile.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveProfileFields(Map<String, dynamic> values) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      await ensureProfileExists();
      final data = <String, dynamic>{'id': user.id, ...values};
      if (values.containsKey('username') && values['username'] is String) {
        data['username_lower'] = (values['username'] as String)
            .trim()
            .toLowerCase();
      }
      if (values.containsKey('avatar_url') ||
          values.containsKey('avatar_path')) {
        data['avatar_updated_at'] = DateTime.now().toUtc().toIso8601String();
      }
      data['profile_updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('profiles').upsert(data);
      return true;
    } catch (e, stack) {
      print('saveProfileFields error: $e');
      print(stack);
      return false;
    }
  }

  Future<bool> saveTransportMode(BackendTransportMode mode) async {
    final result = await saveProfileFields({'transport_mode': mode.value});
    if (result) {
      await TransportModeService.instance.saveTransportMode(mode);
    }
    return result;
  }

  Future<bool> saveAgeGroup(String ageGroup) async {
    return saveProfileFields({'age_group': ageGroup});
  }

  Future<bool> saveDob(String dob) async {
    return saveProfileFields({'date_of_birth': dob});
  }

  Future<bool> saveUsername(String username) async {
    return saveProfileFields({'username': username});
  }

  Future<bool> saveDisplayName(String displayName) async {
    return saveProfileFields({'display_name': displayName});
  }

  Future<bool> saveAvatarUrl(String? avatarUrl, {String? avatarPath}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in. Cannot save avatar.');
    }
    
    print('--- AVATAR LINK START ---');
    print('Table: profiles');
    print('User ID (id): ${user.id}');
    print('Avatar URL length/presence: ${avatarUrl != null ? avatarUrl.length : 'null'}');
    print('Avatar Path: $avatarPath');

    try {
      final exists = await ensureProfileExists();
      if (!exists) {
        print('Warning: ensureProfileExists returned false. Row might not exist.');
      }

      final data = <String, dynamic>{
        'id': user.id,
        'avatar_url': avatarUrl,
        'avatar_path': avatarPath,
        'avatar_updated_at': DateTime.now().toUtc().toIso8601String(),
        'profile_updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _client.from('profiles').upsert(data).select();
      
      if (response.isEmpty) {
        print('Error: No rows were updated in profiles table.');
        throw Exception('Profile row missing or RLS blocked update.');
      }
      
      print('--- AVATAR LINK SUCCESS ---');
      return true;
    } on PostgrestException catch (e) {
      print('PostgREST Error during avatar link: ${e.message} (Code: ${e.code}, Details: ${e.details})');
      throw Exception('Database error linking avatar: ${e.message}');
    } catch (e, stack) {
      print('Unknown error during avatar link: $e');
      print(stack);
      throw Exception('Avatar linking failed.');
    }
  }

  Future<bool> saveBio(String bio) async {
    return saveProfileFields({'bio': bio});
  }

  Future<bool> ensureProfileExists({String? email}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      final existing = await getCurrentProfile();
      if (existing != null) {
        return true;
      }
      final profileUsername = user.email?.split('@').first;
      final payload = <String, dynamic>{
        'id': user.id,
        'email': email ?? user.email,
        'username': profileUsername,
        'username_lower': profileUsername?.toLowerCase(),
        'display_name': profileUsername,
        'role': 'teen',
        'age_group': 'teen',
        'transport_mode': 'walking',
        'verification_status': 'unverified',
        'profile_completion': 0,
        'trust_score': 0,
        'xp': 0,
        'level': 1,
        'completed_jobs': 0,
        'safety_streak': 0,
        'tracked_earnings_cents': 0,
        'leaderboard_opt_in': false,
        'ads_personalized_allowed': false,
      };
      await _client.from('profiles').upsert(payload);
      await ProfileService.instance.saveAgeGroup('teen');
      await ProfileService.instance.saveDob('');
      return true;
    } catch (e, stack) {
      print('ensureProfileExists error: $e');
      print(stack);
      return false;
    }
  }

  Future<bool> saveProfile(BackendProfile profile) async {
    try {
      await _client.from('profiles').upsert(profile.toJson());
      return true;
    } catch (_) {
      return false;
    }
  }
}
