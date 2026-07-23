import '../../core/utils/formatters.dart';

class Job {
  const Job({
    required this.id,
    required this.posterId,
    required this.title,
    required this.description,
    required this.category,
    required this.locationText,
    required this.city,
    required this.state,
    required this.status,
    required this.requiresGuardianApproval,
    this.summary,
    this.payAmountCents,
    this.payLabel,
    this.startsAt,
    this.endsAt,
    this.deadlineAt,
    this.expiresAt,
    this.posterName,
    this.posterVerificationStatus,
    this.posterAvatarPath,
    this.scheduleType = 'flexible',
    this.paymentType = 'fixed',
    this.paymentMethod = 'flexible',
    this.paymentTiming = 'after_completion',
    this.verificationRequirement = 'none',
    this.workEnvironment = 'unspecified',
    this.locationType = 'unspecified',
    this.experienceLevel = 'any',
    this.estimatedDurationMinutes,
    this.workersNeeded = 1,
    this.skillsNeeded = const [],
    this.physicalRequirements = const [],
    this.equipmentProvided,
    this.equipmentWorkerBrings,
    this.specialInstructions,
    this.safetyNotes,
    this.proofExpected = false,
    this.adultSupervisionPresent = false,
    this.tipAllowed = false,
    this.applicationsOpen = true,
    this.isTest = false,
    this.publishedAt,
    this.recurring = false,
    this.recurrenceRule,
    this.timezone = 'America/Indianapolis',
    this.urgency = 'normal',
    this.neighborhood,
    this.zipCode,
    this.travelRadiusMiles,
    this.teenMinAge = 13,
    this.teenMaxAge = 17,
  });

  final String id;
  final String posterId;
  final String title;
  final String? summary;
  final String description;
  final String category;
  final String locationText;
  final String city;
  final String state;
  final String status;
  final bool requiresGuardianApproval;
  final int? payAmountCents;
  final String? payLabel;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? deadlineAt;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final String? posterName;
  final String? posterVerificationStatus;
  final String? posterAvatarPath;
  final String scheduleType;
  final String paymentType;
  final String paymentMethod;
  final String paymentTiming;
  final String verificationRequirement;
  final String workEnvironment;
  final String locationType;
  final String experienceLevel;
  final int? estimatedDurationMinutes;
  final int workersNeeded;
  final List<String> skillsNeeded;
  final List<String> physicalRequirements;
  final String? equipmentProvided;
  final String? equipmentWorkerBrings;
  final String? specialInstructions;
  final String? safetyNotes;
  final bool proofExpected;
  final bool adultSupervisionPresent;
  final bool tipAllowed;
  final bool applicationsOpen;
  final bool isTest;
  final bool recurring;
  final String? recurrenceRule;
  final String timezone;
  final String urgency;
  final String? neighborhood;
  final String? zipCode;
  final int? travelRadiusMiles;
  final int teenMinAge;
  final int teenMaxAge;

  String get payDisplay => formatCents(payAmountCents, fallback: payLabel);
  bool get posterVerified => !isTest && posterVerificationStatus == 'approved';
  bool get isFlexible => scheduleType == 'flexible' || startsAt == null;
  bool get isOpen => status == 'open' && applicationsOpen;
  String get scheduleDisplay => isFlexible
      ? 'Flexible schedule'
      : '${formatDateTime(startsAt)}${endsAt == null ? '' : ' to ${formatDateTime(endsAt)}'}';
  String get verificationDisplay => isTest
      ? 'Approved pilot participant'
      : switch (posterVerificationStatus) {
          'approved' => 'Verified poster',
          'pending' => 'Poster verification pending',
          'rejected' => 'Poster verification not approved',
          _ => 'Poster verification not started',
        };

  factory Job.fromMap(Map<String, dynamic> json) {
    final poster = json['profiles'];
    final posterMap = poster is Map<String, dynamic> ? poster : null;
    return Job(
      id: json['id'].toString(),
      posterId: json['poster_id'].toString(),
      title: (json['title'] as String?) ?? 'Untitled job',
      summary: json['summary'] as String?,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'other safe local work',
      locationText: (json['location_text'] as String?) ?? 'General area',
      city: (json['city'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'draft',
      requiresGuardianApproval: json['requires_guardian_approval'] == true,
      payAmountCents: json['pay_amount_cents'] as int?,
      payLabel: json['pay_label'] as String?,
      startsAt: DateTime.tryParse((json['starts_at'] ?? '').toString()),
      endsAt: DateTime.tryParse((json['ends_at'] ?? '').toString()),
      deadlineAt: DateTime.tryParse((json['deadline_at'] ?? '').toString()),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()),
      posterName: posterMap?['display_name'] as String?,
      posterVerificationStatus: posterMap?['verification_status'] as String?,
      posterAvatarPath: posterMap?['avatar_path'] as String?,
      scheduleType: (json['schedule_type'] as String?) ?? 'flexible',
      paymentType: (json['payment_type'] as String?) ?? 'fixed',
      paymentMethod: (json['payment_method'] as String?) ?? 'flexible',
      paymentTiming: (json['payment_timing'] as String?) ?? 'after_completion',
      verificationRequirement:
          (json['verification_requirement'] as String?) ?? 'none',
      workEnvironment: (json['work_environment'] as String?) ?? 'unspecified',
      locationType: (json['location_type'] as String?) ?? 'unspecified',
      experienceLevel: (json['experience_level'] as String?) ?? 'any',
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      workersNeeded: (json['workers_needed'] as int?) ?? 1,
      skillsNeeded: _stringList(json['skills_needed']),
      physicalRequirements: _stringList(json['physical_requirements']),
      equipmentProvided: json['equipment_provided'] as String?,
      equipmentWorkerBrings: json['equipment_worker_brings'] as String?,
      specialInstructions: json['special_instructions'] as String?,
      safetyNotes: json['safety_notes'] as String?,
      proofExpected: json['proof_expected'] == true,
      adultSupervisionPresent: json['adult_supervision_present'] == true,
      tipAllowed: json['tip_allowed'] == true,
      applicationsOpen: json['applications_open'] != false,
      isTest: json['is_test'] == true,
      recurring: json['recurring'] == true,
      recurrenceRule: json['recurrence_rule'] as String?,
      timezone: (json['timezone'] as String?) ?? 'America/Indianapolis',
      urgency: (json['urgency'] as String?) ?? 'normal',
      neighborhood: json['neighborhood'] as String?,
      zipCode: json['zip_code'] as String?,
      travelRadiusMiles: json['travel_radius_miles'] as int?,
      teenMinAge: (json['teen_min_age'] as int?) ?? 13,
      teenMaxAge: (json['teen_max_age'] as int?) ?? 17,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}

class JobSearchFilters {
  const JobSearchFilters({
    this.keyword = '',
    this.category,
    this.minimumPayCents,
    this.paymentType,
    this.scheduleType,
    this.verificationRequirement,
    this.requiresGuardianApproval,
    this.workEnvironment,
    this.city,
    this.state,
    this.sort = JobSort.newest,
  });

  final String keyword;
  final String? category;
  final int? minimumPayCents;
  final String? paymentType;
  final String? scheduleType;
  final String? verificationRequirement;
  final bool? requiresGuardianApproval;
  final String? workEnvironment;
  final String? city;
  final String? state;
  final JobSort sort;
}

enum JobSort { newest, highestPay, soonestStart }

class JobDraft {
  JobDraft({required this.clientRequestId});

  final String clientRequestId;
  String? id;
  String title = '';
  String summary = '';
  String description = '';
  String category = 'cleaning';
  int? estimatedDurationMinutes;
  int workersNeeded = 1;
  String experienceLevel = 'any';
  List<String> skillsNeeded = [];
  String equipmentProvided = '';
  String equipmentWorkerBrings = '';
  List<String> physicalRequirements = [];
  bool proofExpected = false;
  String specialInstructions = '';
  String scheduleType = 'flexible';
  DateTime? startsAt;
  DateTime? endsAt;
  DateTime? deadlineAt;
  bool recurring = false;
  String recurrenceRule = '';
  String timezone = 'America/Indianapolis';
  String urgency = 'normal';
  String locationText = '';
  String city = '';
  String state = '';
  String neighborhood = '';
  String zipCode = '';
  int? travelRadiusMiles;
  String workEnvironment = 'unspecified';
  String locationType = 'unspecified';
  int? payAmountCents;
  String paymentType = 'fixed';
  String paymentMethod = 'flexible';
  String paymentTiming = 'after_completion';
  bool tipAllowed = false;
  int teenMinAge = 13;
  int teenMaxAge = 17;
  bool adultSupervisionPresent = false;
  String verificationRequirement = 'none';
  bool requiresGuardianApproval = false;
  String safetyNotes = '';

  Map<String, dynamic> toMap() => {
    'title': title,
    'summary': summary,
    'description': description,
    'category': category,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'workers_needed': workersNeeded,
    'experience_level': experienceLevel,
    'skills_needed': skillsNeeded,
    'equipment_provided': equipmentProvided,
    'equipment_worker_brings': equipmentWorkerBrings,
    'physical_requirements': physicalRequirements,
    'proof_expected': proofExpected,
    'special_instructions': specialInstructions,
    'schedule_type': scheduleType,
    'starts_at': startsAt?.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'deadline_at': deadlineAt?.toIso8601String(),
    'recurring': recurring,
    'recurrence_rule': recurrenceRule,
    'timezone': timezone,
    'urgency': urgency,
    'location_text': locationText,
    'city': city,
    'state': state,
    'neighborhood': neighborhood,
    'zip_code': zipCode,
    'travel_radius_miles': travelRadiusMiles,
    'work_environment': workEnvironment,
    'location_type': locationType,
    'pay_amount_cents': payAmountCents,
    'payment_type': paymentType,
    'payment_method': paymentMethod,
    'payment_timing': paymentTiming,
    'tip_allowed': tipAllowed,
    'teen_min_age': teenMinAge,
    'teen_max_age': teenMaxAge,
    'adult_supervision_present': adultSupervisionPresent,
    'verification_requirement': verificationRequirement,
    'requires_guardian_approval': requiresGuardianApproval,
    'safety_notes': safetyNotes,
  };
}
