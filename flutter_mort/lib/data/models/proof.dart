class ProofUpload {
  const ProofUpload({
    required this.id,
    required this.applicationId,
    required this.uploadedBy,
    required this.storagePath,
    required this.status,
    this.note,
    this.reviewedBy,
    this.reviewNote,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String applicationId;
  final String uploadedBy;
  final String storagePath;
  final String status;
  final String? note;
  final String? reviewedBy;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => switch (status) {
    'submitted' => 'Awaiting review',
    'approved' => 'Approved',
    'resubmission_requested' => 'New proof requested',
    'rejected' => 'Needs attention',
    _ => status.replaceAll('_', ' '),
  };

  factory ProofUpload.fromMap(Map<String, dynamic> json) {
    return ProofUpload(
      id: json['id'].toString(),
      applicationId: json['application_id'].toString(),
      uploadedBy: json['uploaded_by'].toString(),
      storagePath: (json['storage_path'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'submitted',
      note: json['note'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewNote: json['review_note'] as String?,
      reviewedAt: DateTime.tryParse((json['reviewed_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}
