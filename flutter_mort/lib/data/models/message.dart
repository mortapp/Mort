class MessageThread {
  const MessageThread({
    required this.id,
    this.jobId,
    this.applicationId,
    this.teenId,
    this.adultId,
    this.guardianId,
    this.updatedAt,
    this.unreadCount = 0,
  });

  final String id;
  final String? jobId;
  final String? applicationId;
  final String? teenId;
  final String? adultId;
  final String? guardianId;
  final DateTime? updatedAt;
  final int unreadCount;

  factory MessageThread.fromMap(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id'].toString(),
      jobId: json['job_id'] as String?,
      applicationId: json['application_id'] as String?,
      teenId: json['teen_id'] as String?,
      adultId: json['adult_id'] as String?,
      guardianId: json['guardian_id'] as String?,
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class MortMessage {
  const MortMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.scannerStatus,
    this.scannerReason,
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final String scannerStatus;
  final String? scannerReason;
  final DateTime? createdAt;

  bool get blocked => scannerStatus == 'blocked';
  bool get flagged => scannerStatus == 'flagged';

  factory MortMessage.fromMap(Map<String, dynamic> json) {
    return MortMessage(
      id: json['id'].toString(),
      threadId: json['thread_id'].toString(),
      senderId: json['sender_id'].toString(),
      body: (json['body'] as String?) ?? '',
      scannerStatus: (json['scanner_status'] as String?) ?? 'clean',
      scannerReason: json['scanner_reason'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }
}
