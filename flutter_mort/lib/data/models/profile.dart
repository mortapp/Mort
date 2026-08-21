import '../../core/utils/date_of_birth.dart';

enum UserRole { teen, adult, guardian, admin }

UserRole? userRoleFromString(String? value) {
  return switch (value) {
    'teen' => UserRole.teen,
    'adult' => UserRole.adult,
    'guardian' => UserRole.guardian,
    'admin' => UserRole.admin,
    _ => null,
  };
}

String? userRoleToString(UserRole? value) {
  return switch (value) {
    UserRole.teen => 'teen',
    UserRole.adult => 'adult',
    UserRole.guardian => 'guardian',
    UserRole.admin => 'admin',
    null => null,
  };
}

class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.displayName,
    required this.username,
    required this.dob,
    required this.city,
    required this.state,
    this.locationSetupMode = 'city_state',
    required this.onboardingCompleted,
    required this.accountStatus,
    required this.verificationStatus,
    required this.paymentPreference,
    this.guardianSetupStatus = 'not_started',
    this.avatarPath,
    this.avatarUpdatedAt,
    this.avatarModerationStatus = 'active',
    this.bio,
    this.availability,
    this.preferredJobCategories = const [],
    this.transportationMethods = const [],
    this.maxTravelDistanceMiles,
    this.maxTravelMinutes,
    this.walkingDistanceOnly = false,
    this.guardianTransportationPossible = false,
    this.approximateArea,
    this.goals,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final UserRole? role;
  final String? displayName;
  final String? username;
  final DateTime? dob;
  final String? city;
  final String? state;
  final String locationSetupMode;
  final bool onboardingCompleted;
  final String accountStatus;
  final String verificationStatus;
  final String paymentPreference;
  final String guardianSetupStatus;
  final String? avatarPath;
  final DateTime? avatarUpdatedAt;
  final String avatarModerationStatus;
  final String? bio;
  final String? availability;
  final List<String> preferredJobCategories;
  final List<String> transportationMethods;
  final int? maxTravelDistanceMiles;
  final int? maxTravelMinutes;
  final bool walkingDistanceOnly;
  final bool guardianTransportationPossible;
  final String? approximateArea;
  final String? goals;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTeen => role == UserRole.teen;
  bool get isAdult => role == UserRole.adult;
  bool get isGuardian => role == UserRole.guardian;
  bool get isAdmin => role == UserRole.admin;
  bool get isActive => accountStatus == 'active';
  bool get hasAvatar => avatarPath?.isNotEmpty == true;

  List<ProfileCompletionItem> get completionChecklist => [
    ProfileCompletionItem(
      'Display name',
      displayName?.trim().isNotEmpty == true,
    ),
    ProfileCompletionItem('Username', username?.trim().isNotEmpty == true),
    ProfileCompletionItem('Profile photo', hasAvatar),
    ProfileCompletionItem('Bio', bio?.trim().isNotEmpty == true),
    ProfileCompletionItem(
      'Availability',
      availability?.trim().isNotEmpty == true,
    ),
    ProfileCompletionItem('Interests', preferredJobCategories.isNotEmpty),
    ProfileCompletionItem(
      'Location',
      locationSetupMode != 'city_state' ||
          (city?.trim().isNotEmpty == true && state?.trim().isNotEmpty == true),
    ),
    ProfileCompletionItem('Onboarding', onboardingCompleted),
  ];

  double get completionRatio {
    final items = completionChecklist;
    return items.where((item) => item.complete).length / items.length;
  }

  factory Profile.fromMap(Map<String, dynamic> json) {
    return Profile(
      id: json['id'].toString(),
      role: userRoleFromString(json['role'] as String?),
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      dob: DateOfBirthParser.tryParseIso(json['dob']?.toString()),
      city: json['city'] as String?,
      state: json['state'] as String?,
      locationSetupMode:
          (json['location_setup_mode'] as String?) ?? 'city_state',
      onboardingCompleted: json['onboarding_completed'] == true,
      accountStatus: (json['account_status'] as String?) ?? 'active',
      verificationStatus:
          (json['verification_status'] as String?) ?? 'not_started',
      paymentPreference: (json['payment_preference'] as String?) ?? 'none',
      guardianSetupStatus:
          (json['guardian_setup_status'] as String?) ?? 'not_started',
      avatarPath: json['avatar_path'] as String?,
      avatarUpdatedAt: DateTime.tryParse(
        json['avatar_updated_at']?.toString() ?? '',
      ),
      avatarModerationStatus:
          (json['avatar_moderation_status'] as String?) ?? 'active',
      bio: json['bio'] as String?,
      availability: json['availability'] as String?,
      preferredJobCategories: _stringList(json['preferred_job_categories']),
      transportationMethods: _stringList(json['transportation_methods']),
      maxTravelDistanceMiles: json['max_travel_distance_miles'] as int?,
      maxTravelMinutes: json['max_travel_minutes'] as int?,
      walkingDistanceOnly: json['walking_distance_only'] == true,
      guardianTransportationPossible:
          json['guardian_transportation_possible'] == true,
      approximateArea: json['approximate_area'] as String?,
      goals: json['goals'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}

class ProfileCompletionItem {
  const ProfileCompletionItem(this.label, this.complete);

  final String label;
  final bool complete;
}
