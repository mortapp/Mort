import 'job.dart';

class MortApplication {
  const MortApplication({
    required this.id,
    required this.jobId,
    required this.teenId,
    required this.status,
    this.note,
    this.guardianId,
    this.job,
    this.availabilityConfirmed = false,
    this.createdAt,
    this.viewedAt,
    this.withdrawnAt,
    this.teenName,
    this.teenAvatarPath,
  });

  final String id;
  final String jobId;
  final String teenId;
  final String status;
  final String? note;
  final String? guardianId;
  final Job? job;
  final bool availabilityConfirmed;
  final DateTime? createdAt;
  final DateTime? viewedAt;
  final DateTime? withdrawnAt;
  final String? teenName;
  final String? teenAvatarPath;

  factory MortApplication.fromMap(Map<String, dynamic> json) {
    final jobData = json['jobs'];
    final teenData = json['teen'];
    final teen = teenData is Map<String, dynamic> ? teenData : null;
    return MortApplication(
      id: json['id'].toString(),
      jobId: json['job_id'].toString(),
      teenId: json['teen_id'].toString(),
      status: (json['status'] as String?) ?? 'submitted',
      note: json['note'] as String?,
      guardianId: json['guardian_id'] as String?,
      job: jobData is Map<String, dynamic> ? Job.fromMap(jobData) : null,
      availabilityConfirmed: json['availability_confirmed'] == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      viewedAt: DateTime.tryParse((json['viewed_at'] ?? '').toString()),
      withdrawnAt: DateTime.tryParse((json['withdrawn_at'] ?? '').toString()),
      teenName: teen?['display_name'] as String?,
      teenAvatarPath: teen?['avatar_path'] as String?,
    );
  }
}

class ApplicationEligibility {
  const ApplicationEligibility({
    required this.eligible,
    required this.code,
    required this.message,
    required this.guardianRequiredForThisJob,
    required this.guardianLinked,
    this.verificationRequirement = 'none',
    this.scheduleType = 'flexible',
  });

  final bool eligible;
  final String code;
  final String message;
  final bool guardianRequiredForThisJob;
  final bool guardianLinked;
  final String verificationRequirement;
  final String scheduleType;

  factory ApplicationEligibility.fromMap(Map<String, dynamic> map) {
    return ApplicationEligibility(
      eligible: map['eligible'] == true,
      code: (map['code'] as String?) ?? 'unknown_permission_failure',
      message: (map['message'] as String?) ?? 'We could not check eligibility.',
      guardianRequiredForThisJob: map['guardian_required_for_this_job'] == true,
      guardianLinked: map['guardian_linked'] == true,
      verificationRequirement:
          (map['verification_requirement'] as String?) ?? 'none',
      scheduleType: (map['schedule_type'] as String?) ?? 'flexible',
    );
  }
}
