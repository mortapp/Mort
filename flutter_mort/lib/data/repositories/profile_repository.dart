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

  Future<OnboardingProgressV2> getOnboardingProgressV2() async {
    requireUserId();
    return _onboardingProgressV2FromRpc(
      await client.rpc('get_my_onboarding_progress_v2'),
    );
  }

  Future<OnboardingProgressV2> saveOnboardingAccountV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
  }) async {
    requireUserId();
    return _onboardingProgressV2FromRpc(
      await client.rpc(
        'save_my_onboarding_account_v2',
        params: {
          'p_payload': payload,
          'p_client_request_id': clientRequestId,
          'p_payload_version': 1,
        },
      ),
    );
  }

  Future<OnboardingProgressV2> saveOnboardingWorkV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async {
    requireUserId();
    return _onboardingProgressV2FromRpc(
      await client.rpc(
        'save_my_onboarding_work_v2',
        params: {
          'p_payload': payload,
          'p_client_request_id': clientRequestId,
          'p_payload_version': 1,
          'p_expected_revision': expectedRevision?.toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<OnboardingProgressV2> saveOnboardingSafetyV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async {
    requireUserId();
    return _onboardingProgressV2FromRpc(
      await client.rpc(
        'save_my_onboarding_safety_v2',
        params: {
          'p_payload': payload,
          'p_client_request_id': clientRequestId,
          'p_payload_version': 1,
          'p_expected_revision': expectedRevision?.toUtc().toIso8601String(),
        },
      ),
    );
  }

  Future<OnboardingProgressV2> completeOnboardingV2({
    required Map<String, dynamic> payload,
    required String clientRequestId,
    DateTime? expectedRevision,
  }) async {
    requireUserId();
    return _onboardingProgressV2FromRpc(
      await client.rpc(
        'complete_my_onboarding_v2',
        params: {
          'p_payload': payload,
          'p_client_request_id': clientRequestId,
          'p_payload_version': 1,
          'p_expected_revision': expectedRevision?.toUtc().toIso8601String(),
        },
      ),
    );
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

  Future<Profile> saveProfileSetup({
    required UserRole role,
    required String displayName,
    required String username,
    required DateTime dob,
    required String city,
    required String state,
    required String locationSetupMode,
    required String bio,
    required String availability,
    required List<String> preferredJobCategories,
    required String approximateArea,
    required String goals,
    required String adultAccountType,
    required String businessName,
    required bool editExisting,
    required String clientRequestId,
  }) async {
    requireUserId();
    final result = await client.rpc(
      'save_my_profile_setup_v2',
      params: {
        'p_payload': {
          'role': userRoleToString(role),
          'display_name': displayName.trim(),
          'username': username.trim().toLowerCase(),
          'dob': DateOfBirthParser.toIsoDate(dob),
          'city': city.trim(),
          'state': state.trim().toUpperCase(),
          'location_setup_mode': locationSetupMode,
          'bio': bio.trim(),
          'availability': availability.trim(),
          'preferred_job_categories': preferredJobCategories,
          'approximate_area': approximateArea.trim(),
          'goals': goals.trim(),
          'adult_account_type': adultAccountType,
          'business_name': businessName.trim(),
        },
        'p_client_request_id': clientRequestId,
        'p_edit_existing': editExisting,
      },
    );
    return _profileFromRpc(result);
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
      final field = result['field']?.toString();
      if (field != null && field.isNotEmpty) {
        throw MortFieldCodedError(
          code,
          _profileErrorMessage(code),
          field: field,
        );
      }
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

  OnboardingProgressV2 _onboardingProgressV2FromRpc(Object? response) {
    if (response is! Map) {
      throw const MortCodedError(
        'onboarding_response_invalid',
        'The onboarding server returned an invalid response.',
      );
    }
    final result = Map<String, dynamic>.from(response);
    if (result['ok'] != true) {
      final code = result['code']?.toString() ?? 'onboarding_update_failed';
      final field = result['field']?.toString();
      if (field != null && field.isNotEmpty) {
        throw MortFieldCodedError(
          code,
          _profileErrorMessage(code),
          field: field,
        );
      }
      throw MortCodedError(code, _profileErrorMessage(code));
    }
    return OnboardingProgressV2.fromMap(result);
  }

  String _profileErrorMessage(String code) {
    return switch (code) {
      'profile_conflict_detected' => 'Your profile changed in another session. Refresh, review the latest version, and save again.',
      'protected_or_unknown_profile_field' =>
        'That profile field is controlled by MORT and cannot be changed here.',
      'role_immutable' || 'dob_immutable' => 'Account role and date of birth cannot be changed from profile settings. Contact support if they are incorrect.',
      'under_13_not_eligible' =>
        'MORT is available only to users age 13 and older.',
      'display_name_invalid' =>
        'Enter a display name between 2 and 80 characters.',
      'username_invalid' =>
        'Use 3-24 lowercase letters, numbers, or underscores.',
      'username_taken' =>
        'That username is already in use. Choose another username.',
      'username_change_unavailable' => 'That username change is not available. Keep your current username or contact support.',
      'dob_invalid' ||
      'future_dob_rejected' ||
      'dob_out_of_range' => 'Enter a valid date of birth.',
      'teen_role_age_mismatch' =>
        'Teen accounts must be for someone age 13 through 17.',
      'adult_role_age_mismatch' =>
        'Adult and Guardian accounts require an age of 18 or older.',
      'city_state_required' => 'Enter a city and valid two-letter state code.',
      'location_setup_mode_role_mismatch' =>
        'Choose a location option allowed for this account role.',
      'bio_invalid' => 'Keep the bio under 500 characters.',
      'availability_invalid' =>
        'Keep availability or scheduling preferences under 240 characters.',
      'approximate_area_invalid' => 'Keep the approximate area under 120 characters and do not enter an exact address.',
      'goals_invalid' => 'Keep goals under 500 characters.',
      'preferred_job_categories_invalid' =>
        'Choose up to 12 job categories using 2-50 characters each.',
      'adult_account_type_invalid' =>
        'Choose whether you are posting as an individual or business.',
      'business_name_invalid' =>
        'Enter a business name between 2 and 120 characters.',
      'profile_setup_request_payload_mismatch' => 'This saved request no longer matches the form. Close this screen, reopen it, and try again.',
      'onboarding_already_completed' => 'This account already finished setup. Reopen Profile from Settings and save there.',
      'profile_setup_failed' => 'MORT could not save the profile consistently. Your edits are still on this device; retry when connected.',
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
      'onboarding_revision_conflict' => 'Your setup changed in another session. Reload the latest saved progress before continuing.',
      'onboarding_request_payload_mismatch' => 'This retry no longer matches the original save. Reload your saved progress and try again.',
      'onboarding_account_required' =>
        'Finish Your account before completing setup.',
      'onboarding_work_preferences_required' =>
        'Finish Work preferences before completing setup.',
      'onboarding_safety_support_required' =>
        'Finish Safety & support before completing setup.',
      'onboarding_acknowledgement_required' =>
        'Review and acknowledge the MORT safety notices first.',
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
