import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/utils/safe_image.dart';
import 'repository_base.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.caseNumber,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.source,
    required this.waitingOnParty,
    required this.aiAssisted,
    required this.humanReviewed,
    required this.safeAttachmentCount,
    required this.createdAt,
    required this.updatedAt,
    this.relatedJobId,
    this.relatedApplicationId,
    this.relatedContractId,
    this.relatedDisputeId,
  });

  final String id;
  final String caseNumber;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String source;
  final String waitingOnParty;
  final bool aiAssisted;
  final bool humanReviewed;
  final int safeAttachmentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? relatedJobId;
  final String? relatedApplicationId;
  final String? relatedContractId;
  final String? relatedDisputeId;

  bool get canUploadEvidence => relatedDisputeId != null;
  bool get isClosed => status == 'closed';

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'].toString(),
    caseNumber: json['case_number']?.toString() ?? 'Case unavailable',
    subject: json['subject']?.toString() ?? 'Support case',
    category: json['category']?.toString() ?? 'other',
    priority: json['priority']?.toString() ?? 'normal',
    status: json['status']?.toString() ?? 'open',
    source: json['source']?.toString() ?? 'human_support',
    waitingOnParty: json['waiting_on_party']?.toString() ?? 'staff',
    aiAssisted: json['ai_assisted'] == true,
    humanReviewed: json['human_reviewed'] == true,
    safeAttachmentCount: _integer(json['safe_attachment_count']),
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
        DateTime.now(),
    relatedJobId: json['related_job_id']?.toString(),
    relatedApplicationId: json['related_application_id']?.toString(),
    relatedContractId: json['related_contract_id']?.toString(),
    relatedDisputeId: json['related_dispute_id']?.toString(),
  );

  static int _integer(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.senderKind,
    required this.source,
    required this.body,
    required this.createdAt,
    required this.safeAttachmentCount,
  });

  final String id;
  final String senderKind;
  final String source;
  final String body;
  final DateTime createdAt;
  final int safeAttachmentCount;

  bool get isUser => senderKind == 'user';
  bool get isHumanStaff => senderKind == 'support_staff';

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) =>
      SupportTicketMessage(
        id: json['id'].toString(),
        senderKind: json['sender_kind']?.toString() ?? 'user',
        source: json['message_source']?.toString() ?? 'human_support',
        body: json['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        safeAttachmentCount: SupportTicket._integer(
          json['safe_attachment_count'],
        ),
      );
}

class SupportThread {
  const SupportThread({
    required this.ticket,
    required this.messages,
    this.evidence = const [],
  });

  final SupportTicket ticket;
  final List<SupportTicketMessage> messages;
  final List<SupportEvidenceRecord> evidence;
}

class SupportEvidenceRecord {
  const SupportEvidenceRecord({
    required this.id,
    required this.category,
    required this.status,
    required this.reviewStatus,
    required this.processedByteSize,
    required this.preservationHold,
    this.createdAt,
    this.retentionDeleteAt,
  });

  final String id;
  final String category;
  final String status;
  final String reviewStatus;
  final int processedByteSize;
  final bool preservationHold;
  final DateTime? createdAt;
  final DateTime? retentionDeleteAt;

  factory SupportEvidenceRecord.fromJson(Map<String, dynamic> json) =>
      SupportEvidenceRecord(
        id: json['id'].toString(),
        category: json['category']?.toString() ?? 'work_result',
        status: json['status']?.toString() ?? 'submitted',
        reviewStatus: json['review_status']?.toString() ?? 'not_reviewed',
        processedByteSize: SupportTicket._integer(json['processed_byte_size']),
        preservationHold: json['preservation_hold'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        retentionDeleteAt: DateTime.tryParse(
          json['retention_delete_at']?.toString() ?? '',
        ),
      );
}

class SupportEvidenceAttachment {
  const SupportEvidenceAttachment({
    required this.id,
    required this.objectPath,
    required this.status,
  });

  final String id;
  final String objectPath;
  final String status;
}

class SupportRepository extends RepositoryBase {
  SupportRepository({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const evidenceBucket = 'support-evidence';
  static const maximumEvidenceSourceBytes = 10 * 1024 * 1024;
  static const savedPaymentWarning =
      'Do not include passwords, verification codes, full card numbers, exact residential addresses, government IDs, or unrelated private information.';

  final ImagePicker _picker;
  static const _uuid = Uuid();

  Future<SupportTicket> createConversation({
    required String category,
    required String subject,
    required String message,
    String source = 'automated_support',
    String? relatedJobId,
    String? relatedApplicationId,
    String? relatedContractId,
    String? relatedDisputeId,
  }) async {
    requireUserId();
    final raw = await client.rpc(
      'create_support_conversation',
      params: {
        'p_category': category,
        'p_subject': subject.trim(),
        'p_message': message.trim(),
        'p_source': source,
        'p_related_job_id': relatedJobId,
        'p_related_application_id': relatedApplicationId,
        'p_related_contract_id': relatedContractId,
        'p_related_dispute_id': relatedDisputeId,
        'p_client_request_id': _uuid.v4(),
      },
    );
    final result = _result(raw, 'The support case could not be created.');
    return SupportTicket.fromJson(
      Map<String, dynamic>.from(result['ticket'] as Map),
    );
  }

  Future<String> createTicket({
    required String subject,
    required String message,
  }) async => (await createConversation(
    category: 'other',
    subject: subject,
    message: message,
    source: 'human_support',
  )).id;

  Future<List<SupportTicket>> listTickets() async {
    requireUserId();
    final raw = await client.rpc('list_my_support_tickets');
    return (raw as List<dynamic>? ?? const [])
        .map(
          (item) =>
              SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listMyTickets() async =>
      (await listTickets())
          .map(
            (ticket) => {
              'id': ticket.id,
              'case_number': ticket.caseNumber,
              'subject': ticket.subject,
              'status': ticket.status,
              'created_at': ticket.createdAt.toIso8601String(),
              'updated_at': ticket.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false);

  Future<SupportThread> getThread(String ticketId) async {
    requireUserId();
    final result = _result(
      await client.rpc(
        'get_my_support_ticket_thread',
        params: {'p_ticket_id': ticketId},
      ),
      'The support conversation could not be loaded.',
    );
    return SupportThread(
      ticket: SupportTicket.fromJson(
        Map<String, dynamic>.from(result['ticket'] as Map),
      ),
      messages: (result['messages'] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportTicketMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<SupportTicket>> listStaffQueue({
    String? status,
    bool unassignedOnly = false,
  }) async {
    requireUserId();
    final raw = await client.rpc(
      'support_staff_list_queue',
      params: {
        'p_status': status,
        'p_unassigned_only': unassignedOnly,
        'p_limit': 100,
      },
    );
    return (raw as List<dynamic>? ?? const [])
        .map(
          (item) =>
              SupportTicket.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<SupportThread> getStaffThread(String ticketId) async {
    requireUserId();
    final result = _result(
      await client.rpc(
        'support_staff_get_ticket_thread',
        params: {'p_ticket_id': ticketId},
      ),
      'The staff support thread could not be loaded.',
    );
    return SupportThread(
      ticket: SupportTicket.fromJson(
        Map<String, dynamic>.from(result['ticket'] as Map),
      ),
      messages: (result['messages'] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportTicketMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      evidence: (result['evidence'] as List<dynamic>? ?? const [])
          .map(
            (item) => SupportEvidenceRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> postStaffReply(String ticketId, String message) async {
    _result(
      await client.rpc(
        'support_staff_post_reply',
        params: {
          'p_ticket_id': ticketId,
          'p_message': message.trim(),
          'p_client_request_id': _uuid.v4(),
        },
      ),
      'The staff reply could not be posted.',
    );
  }

  Future<void> changeStaffStatus({
    required String ticketId,
    required String status,
    String? resolutionCode,
    String? reason,
  }) async {
    _result(
      await client.rpc(
        'support_staff_change_status',
        params: {
          'p_ticket_id': ticketId,
          'p_status': status,
          'p_resolution_code': resolutionCode,
          'p_reason': reason,
        },
      ),
      'The support status could not be changed.',
    );
  }

  Future<String> signedEvidenceUrl(String evidenceId) async {
    requireUserId();
    final response = await client.functions.invoke(
      'support-evidence-url',
      body: {'evidenceId': evidenceId},
    );
    if (response.data is! Map || response.data['ok'] != true) {
      throw const MortCodedError(
        'evidence_preview_unavailable',
        'The private evidence preview is unavailable.',
      );
    }
    return response.data['signedUrl'].toString();
  }

  Future<SupportTicketMessage> postMessage(
    String ticketId,
    String message,
  ) async {
    final result = _result(
      await client.rpc(
        'post_support_ticket_message',
        params: {
          'p_ticket_id': ticketId,
          'p_message': message.trim(),
          'p_client_request_id': _uuid.v4(),
        },
      ),
      'The message could not be sent.',
    );
    return SupportTicketMessage.fromJson(
      Map<String, dynamic>.from(result['message'] as Map),
    );
  }

  Future<void> requestHumanReview(String ticketId) async {
    _result(
      await client.rpc(
        'request_support_human_review',
        params: {'p_ticket_id': ticketId},
      ),
      'Human review could not be requested.',
    );
  }

  Future<void> reopen(String ticketId, String reason) async {
    _result(
      await client.rpc(
        'reopen_my_support_ticket',
        params: {'p_ticket_id': ticketId, 'p_reason': reason.trim()},
      ),
      'The support case could not be reopened.',
    );
  }

  Future<XFile?> chooseEvidence({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
      requestFullMetadata: false,
    );
  }

  Future<SupportEvidenceAttachment> createEvidenceDraft({
    required String ticketId,
    required String disputeId,
    required String category,
    required XFile file,
    String? statement,
  }) async {
    final userId = requireUserId();
    final source = await file.readAsBytes();
    final processed = SafeImageProcessor.proof(
      source,
      maximumBytes: maximumEvidenceSourceBytes,
    );
    if (processed.length > 4 * 1024 * 1024) {
      throw const MortCodedError(
        'evidence_file_size_invalid',
        'Choose a smaller image and try again.',
      );
    }
    final path = '$userId/${_uuid.v4()}.jpg';
    await client.storage
        .from(evidenceBucket)
        .uploadBinary(
          path,
          Uint8List.fromList(processed),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '300',
            upsert: false,
          ),
        );
    try {
      final result = _result(
        await client.rpc(
          'register_support_evidence',
          params: {
            'p_ticket_id': ticketId,
            'p_dispute_id': disputeId,
            'p_evidence_category': category,
            'p_object_path': path,
            'p_sha256': sha256.convert(processed).toString(),
            'p_processed_byte_size': processed.length,
            'p_statement': statement,
            'p_client_request_id': _uuid.v4(),
          },
        ),
        'The evidence manifest could not be registered.',
      );
      final map = Map<String, dynamic>.from(result['evidence'] as Map);
      final attachment = SupportEvidenceAttachment(
        id: map['id'].toString(),
        objectPath: map['object_path'].toString(),
        status: map['status']?.toString() ?? 'draft',
      );
      return attachment;
    } catch (_) {
      try {
        await client.storage.from(evidenceBucket).remove([path]);
      } catch (_) {
        // The private owner-scoped object is not exposed and can be reconciled.
      }
      rethrow;
    }
  }

  Future<void> submitEvidence(String evidenceId) async {
    _result(
      await client.rpc(
        'submit_support_evidence',
        params: {'p_evidence_id': evidenceId},
      ),
      'The evidence could not be submitted.',
    );
  }

  Future<void> removeDraftEvidence(SupportEvidenceAttachment attachment) async {
    final authorization = _result(
      await client.rpc(
        'remove_draft_support_evidence',
        params: {'p_evidence_id': attachment.id},
      ),
      'The draft evidence could not be removed.',
    );
    final authorizedPath = authorization['object_path']?.toString();
    if (authorizedPath != attachment.objectPath ||
        authorization['storage_delete_allowed'] != true) {
      throw const MortCodedError(
        'evidence_delete_not_authorized',
        'The draft evidence could not be removed.',
      );
    }
    await client.storage.from(evidenceBucket).remove([authorizedPath!]);
    _result(
      await client.rpc(
        'confirm_draft_support_evidence_removed',
        params: {'p_evidence_id': attachment.id},
      ),
      'The removed draft could not be finalized.',
    );
  }

  Future<SupportEvidenceAttachment> uploadEvidence({
    required String ticketId,
    required String disputeId,
    required String category,
    required XFile file,
    String? statement,
  }) async {
    final draft = await createEvidenceDraft(
      ticketId: ticketId,
      disputeId: disputeId,
      category: category,
      file: file,
      statement: statement,
    );
    await submitEvidence(draft.id);
    return draft;
  }

  Map<String, dynamic> _result(Object? value, String message) {
    if (value is! Map) {
      throw MortCodedError('invalid_support_response', message);
    }
    final result = Map<String, dynamic>.from(value);
    if (result['ok'] != true) {
      throw MortCodedError(
        result['code']?.toString() ?? 'support_operation_failed',
        message,
      );
    }
    return result;
  }
}
