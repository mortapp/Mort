import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../models/onboarding_progress.dart';
import '../models/profile.dart';
import 'repository_base.dart';

const _directoryProfileSelect =
    'id,role,display_name,verification_status,created_at,updated_at,'
    'username,avatar_path,avatar_moderation_status,avatar_updated_at,bio,'
    'availability,preferred_job_categories,approximate_area,goals,'
    'location_setup_mode';

class ProfileRepository extends RepositoryBase {
  static const _uuid = Uuid();

  Future<Profile?> getCurrentProfile() async {
    if (client.auth.currentUser == null) return null;
    final rows = await client.rpc('get_my_profile');
    if (rows is! List || rows.isEmpty) return null;
    return Profile.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<Profile?> getProfile(String profileId) async {
    final row = await client
        .from('profiles')
        .select(_directoryProfileSelect)
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Profile> saveProfile({
    required UserRole role,
    required String displayName,
    required DateTime dob,
    String? city,
    String? state,
    String locationSetupMode = 'city_state',
    bool completeOnboarding = true,
    String paymentPreference = 'none',
  }) async {
    requireUserId();
    const modes = {'city_state', 'partner_supported', 'location_deferred'};
    if (!modes.contains(locationSetupMode)) {
      throw ArgumentError.value(locationSetupMode, 'locationSetupMode');
    }
    if (role != UserRole.teen && locationSetupMode != 'city_state') {
      throw ArgumentError(
        'Adult and guardian profiles require city and state.',
      );
    }
    final result = await client.rpc(
      'save_my_onboarding_profile',
      params: {
        'p_role': userRoleToString(role),
        'p_display_name': displayName,
        'p_dob': DateOfBirthParser.toIsoDate(dob),
        'p_city': city,
        'p_state': state,
        'p_location_setup_mode': locationSetupMode,
        'p_complete_onboarding': completeOnboarding,
        'p_payment_preference': paymentPreference,
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _profileFromRpc(result);
  }

  Future<Profile> completeOnboarding() async {
    requireUserId();
    final result = await client.rpc('complete_my_onboarding');
    return _profileFromRpc(result);
  }

  Future<OnboardingProgress> getOnboardingProgress() async {
    requireUserId();
    final result = await client.rpc('get_my_onboarding_progress');
    return _onboardingProgressFromRpc(result);
  }

  Future<OnboardingProgress> saveOnboardingAge(DateTime dob) async {
    requireUserId();
    final result = await client.rpc(
      'save_my_onboarding_age',
      params: {
        'p_dob': DateOfBirthParser.toIsoDate(dob),
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _onboardingProgressFromRpc(result);
  }

  Future<OnboardingProgress> saveOnboardingRole(UserRole role) async {
    requireUserId();
    final result = await client.rpc(
      'save_my_onboarding_role',
      params: {
        'p_role': userRoleToString(role),
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _onboardingProgressFromRpc(result);
  }

  Future<OnboardingProgress> saveOnboardingProgress({
    required String completedStep,
    Map<String, dynamic> preferences = const {},
  }) async {
    requireUserId();
    final result = await client.rpc(
      'save_my_onboarding_progress',
      params: {
        'p_step': completedStep,
        'p_preferences': preferences,
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _onboardingProgressFromRpc(result);
  }

  Future<OnboardingProgress> recordOnboardingAcknowledgement({
    required String version,
    required String platform,
    required String appVersion,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'record_my_onboarding_acknowledgement',
      params: {
        'p_acknowledgement_version': version,
        'p_pilot_terms_notice_acknowledged': true,
        'p_privacy_notice_acknowledged': true,
        'p_community_rules_acknowledged': true,
        'p_prohibited_work_acknowledged': true,
        'p_safety_rules_acknowledged': true,
        'p_platform': platform,
        'p_app_version': appVersion,
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _onboardingProgressFromRpc(result);
  }

  Future<Profile> saveProfileDetails({
    required String displayName,
    required String bio,
    required String availability,
    required List<String> preferredJobCategories,
    required String approximateArea,
    required String goals,
  }) async {
    return updateMyProfile({
      'display_name': displayName,
      'bio': bio,
      'availability': availability,
      'preferred_job_categories': preferredJobCategories,
      'approximate_area': approximateArea,
      'goals': goals,
    });
  }

  Future<Profile> saveTransportationPreferences({
    required List<String> methods,
    int? maxDistanceMiles,
    int? maxTravelMinutes,
    bool walkingDistanceOnly = false,
    bool guardianTransportationPossible = false,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'save_my_transportation_preferences',
      params: {
        'p_methods': methods,
        'p_max_distance_miles': maxDistanceMiles,
        'p_max_travel_minutes': maxTravelMinutes,
        'p_walking_distance_only': walkingDistanceOnly,
        'p_guardian_transportation_possible': guardianTransportationPossible,
        'p_client_request_id': _uuid.v4(),
      },
    );
    return _profileFromRpc(result);
  }

  Future<Profile> setAvatarPath(String? path) {
    return updateMyProfile({'avatar_path': path});
  }

  Future<Profile> updateMyProfile(
    Map<String, dynamic> patch, {
    DateTime? expectedUpdatedAt,
    String? clientRequestId,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'update_my_profile',
      params: {
        'p_patch': patch,
        'p_expected_updated_at': expectedUpdatedAt?.toUtc().toIso8601String(),
        'p_client_request_id': clientRequestId ?? _uuid.v4(),
      },
    );
    return _profileFromRpc(result);
  }

  Profile _profileFromRpc(Object? response) {
    if (response is! Map) {
      throw const MortCodedError(
        'profile_response_invalid',
        'The profile server returned an invalid response.',
      );
    }
    final result = Map<String, dynamic>.from(response);
    if (result['ok'] != true) {
      final code = result['code']?.toString() ?? 'profile_update_failed';
      throw MortCodedError(code, _profileErrorMessage(code));
    }
    final profile = result['profile'];
    if (profile is! Map) {
      throw const MortCodedError(
        'profile_response_invalid',
        'The saved profile could not be loaded.',
      );
    }
    return Profile.fromMap(Map<String, dynamic>.from(profile));
  }

  OnboardingProgress _onboardingProgressFromRpc(Object? response) {
    if (response is! Map) {
      throw const MortCodedError(
        'onboarding_response_invalid',
        'The onboarding server returned an invalid response.',
      );
    }
    final result = Map<String, dynamic>.from(response);
    if (result['ok'] != true) {
      final code = result['code']?.toString() ?? 'onboarding_update_failed';
      throw MortCodedError(code, _profileErrorMessage(code));
    }
    return OnboardingProgress.fromMap(result);
  }

  String _profileErrorMessage(String code) {
    return switch (code) {
      'profile_conflict_detected' =>
        'Your profile changed in another session. Refresh, review the latest version, and save again.',
      'protected_or_unknown_profile_field' =>
        'That profile field is controlled by MORT and cannot be changed here.',
      'role_immutable' || 'dob_immutable' =>
        'Account role and date of birth cannot be changed from profile settings. Contact support if they are incorrect.',
      'under_13_not_eligible' =>
        'MORT is available only to users age 13 and older.',
      'display_name_invalid' =>
        'Enter a display name between 2 and 80 characters.',
      'profile_not_found' =>
        'Finish account setup before editing your profile.',
      'transportation_methods_invalid' =>
        'Choose at least one valid transportation method.',
      'max_travel_distance_invalid' =>
        'Choose a travel distance between 1 and 50 miles.',
      'max_travel_minutes_invalid' =>
        'Choose a travel time between 5 and 180 minutes.',
      'walking_method_required' =>
        'Select Walking before choosing walking-distance-only jobs.',
      'teen_profile_required' =>
        'Transportation matching preferences are available for teen profiles.',
      'onboarding_steps_incomplete' =>
        'Finish every required setup step before completing onboarding.',
      'onboarding_acknowledgement_required' =>
        'Review and acknowledge the closed-pilot safety notices first.',
      'profile_identity_fields_required' =>
        'Add a display name and username before completing setup.',
      'published_legal_acceptance_required' =>
        'Review and accept the current published legal documents first.',
      _ => 'Your profile was not saved. Review the fields and try again.',
    };
  }

  Future<Map<String, dynamic>> getUsernameChangeStatus() async {
    final result = await client.rpc('get_username_change_status');
    final rows = result as List<dynamic>;
    if (rows.isEmpty) {
      return {
        'current_username': null,
        'free_changes_used': 0,
        'free_changes_remaining': 3,
        'token_credits': 0,
        'admin_credits': 0,
        'plus_allowance_available': false,
        'plus_changes_used': 0,
        'plus_period_start': null,
      };
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<Map<String, dynamic>> requestUsernameChange(String username) async {
    final result = await client.rpc(
      'request_username_change',
      params: {'p_new_username': username},
    );
    final rows = result as List<dynamic>;
    if (rows.isEmpty) return {};
    return Map<String, dynamic>.from(rows.first as Map);
  }
}
