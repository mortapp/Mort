class MessageThread {
  const MessageThread({
    required this.id,
    this.jobId,
    this.applicationId,
    this.teenId,
    this.adultId,
    this.guardianId,
    this.lifecycleStatus = 'active',
    this.updatedAt,
    this.unreadCount = 0,
    this.jobTitle,
    this.counterpartyId,
    this.counterpartyDisplayName,
    this.counterpartyRole,
    this.counterpartyVerificationStatus,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String id;
  final String? jobId;
  final String? applicationId;
  final String? teenId;
  final String? adultId;
  final String? guardianId;
  final String lifecycleStatus;
  final DateTime? updatedAt;
  final int unreadCount;
  final String? jobTitle;
  final String? counterpartyId;
  final String? counterpartyDisplayName;
  final String? counterpartyRole;
  final String? counterpartyVerificationStatus;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;

  factory MessageThread.fromMap(Map<String, dynamic> json) {
    return MessageThread(
      id: json['id'].toString(),
      jobId: json['job_id'] as String?,
      applicationId: json['application_id'] as String?,
      teenId: json['teen_id'] as String?,
      adultId: json['adult_id'] as String?,
      guardianId: json['guardian_id'] as String?,
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'active',
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      jobTitle: json['job_title'] as String?,
      counterpartyId: json['counterparty_id']?.toString(),
      counterpartyDisplayName: json['counterparty_display_name'] as String?,
      counterpartyRole: json['counterparty_role'] as String?,
      counterpartyVerificationStatus:
          json['counterparty_verification_status'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: DateTime.tryParse(
        (json['last_message_at'] ?? '').toString(),
      ),
    );
  }
}

class MessageThreadPageCursor {
  const MessageThreadPageCursor({required this.updatedAt, required this.id});

  final DateTime updatedAt;
  final String id;

  factory MessageThreadPageCursor.fromMap(Map<String, dynamic> json) =>
      MessageThreadPageCursor(
        updatedAt: DateTime.parse(json['updated_at'].toString()),
        id: json['id'].toString(),
      );
}

class MessageThreadPage {
  const MessageThreadPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<MessageThread> items;
  final bool hasMore;
  final MessageThreadPageCursor? nextCursor;

  factory MessageThreadPage.fromMap(Map<String, dynamic> json) {
    final rawCursor = json['next_cursor'];
    return MessageThreadPage(
      items: List<Map<String, dynamic>>.from(
        (json['items'] as List?) ?? const [],
      ).map(MessageThread.fromMap).toList(growable: false),
      hasMore: json['has_more'] == true,
      nextCursor: rawCursor is Map
          ? MessageThreadPageCursor.fromMap(
              Map<String, dynamic>.from(rawCursor),
            )
          : null,
    );
  }
}

class MessagePageCursor {
  const MessagePageCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;

  factory MessagePageCursor.fromMap(Map<String, dynamic> json) {
    return MessagePageCursor(
      createdAt: DateTime.parse(json['created_at'].toString()),
      id: json['id'].toString(),
    );
  }
}

class MessagePage {
  const MessagePage({
    required this.items,
    required this.hasMore,
    required this.lifecycleStatus,
    this.nextCursor,
    this.thread,
  });

  final List<MortMessage> items;
  final bool hasMore;
  final String lifecycleStatus;
  final MessagePageCursor? nextCursor;
  final MessageThread? thread;

  factory MessagePage.fromMap(Map<String, dynamic> json) {
    final rawCursor = json['next_cursor'];
    return MessagePage(
      items: List<Map<String, dynamic>>.from(
        (json['items'] as List?) ?? const [],
      ).map(MortMessage.fromMap).toList(),
      hasMore: json['has_more'] == true,
      lifecycleStatus: json['lifecycle_status']?.toString() ?? 'active',
      nextCursor: rawCursor is Map
          ? MessagePageCursor.fromMap(Map<String, dynamic>.from(rawCursor))
          : null,
      thread: json['thread'] is Map
          ? MessageThread.fromMap(
              Map<String, dynamic>.from(json['thread'] as Map),
            )
          : null,
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
