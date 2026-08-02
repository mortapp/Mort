import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/utils/safe_image.dart';
import 'repository_base.dart';

class SupportAssistantCitation {
  const SupportAssistantCitation({
    required this.id,
    required this.title,
    this.sourceUrl,
    this.navigationRoute,
  });

  final String id;
  final String title;
  final String? sourceUrl;
  final String? navigationRoute;

  factory SupportAssistantCitation.fromJson(Map<String, dynamic> json) =>
      SupportAssistantCitation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'MORT Help',
        sourceUrl: json['source_url']?.toString(),
        navigationRoute: json['navigation_route']?.toString(),
      );
}

class SupportAssistantMessage {
  const SupportAssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.responseMode,
    required this.safetyLevel,
    this.intent = 'general_support',
    this.citations = const [],
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final String responseMode;
  final int safetyLevel;
  final String intent;
  final List<SupportAssistantCitation> citations;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory SupportAssistantMessage.fromJson(
    Map<String, dynamic> json, {
    List<SupportAssistantCitation> citations = const [],
  }) => SupportAssistantMessage(
    id: json['id']?.toString() ?? const Uuid().v4(),
    role: json['role']?.toString() ?? 'assistant',
    content: json['content']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    responseMode: json['response_mode']?.toString() ?? 'deterministic',
    safetyLevel: _integer(json['safety_level']),
    intent: json['intent']?.toString() ?? 'general_support',
    citations: citations,
  );

  static int _integer(Object? value) =>
      value is int ? value : int.tryParse('$value') ?? 0;
}

class SupportAssistantConversation {
  const SupportAssistantConversation({
    required this.id,
    required this.title,
    required this.status,
    required this.responseMode,
    required this.updatedAt,
    this.ticketId,
  });

  final String id;
  final String title;
  final String status;
  final String responseMode;
  final DateTime updatedAt;
  final String? ticketId;

  factory SupportAssistantConversation.fromJson(Map<String, dynamic> json) =>
      SupportAssistantConversation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'MORT Support conversation',
        status: json['status']?.toString() ?? 'active',
        responseMode: json['response_mode']?.toString() ?? 'deterministic',
        updatedAt:
            DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        ticketId: json['ticket_id']?.toString(),
      );
}

class SupportAssistantThread {
  const SupportAssistantThread({
    required this.conversation,
    required this.messages,
    required this.citations,
  });

  final SupportAssistantConversation conversation;
  final List<SupportAssistantMessage> messages;
  final List<SupportAssistantCitation> citations;
}

class SupportAssistantReply {
  const SupportAssistantReply({
    required this.conversationId,
    required this.message,
    required this.citations,
    required this.classification,
    this.ticketId,
    this.caseNumber,
  });

  final String conversationId;
  final SupportAssistantMessage message;
  final List<SupportAssistantCitation> citations;
  final Map<String, dynamic> classification;
  final String? ticketId;
  final String? caseNumber;
}

class SupportAssistantAttachment {
  const SupportAssistantAttachment({
    required this.id,
    required this.objectPath,
  });

  final String id;
  final String objectPath;
}

class SupportAssistantRepository extends RepositoryBase {
  SupportAssistantRepository({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const attachmentBucket = 'support-attachments';
  static const maximumSourceBytes = 10 * 1024 * 1024;
  static const _uuid = Uuid();
  final ImagePicker _picker;

  Future<Map<String, dynamic>> getConfig() async {
    requireUserId();
    return _rpcMap(
      await client.rpc('support_get_config'),
      'Support settings are unavailable.',
    );
  }

  Future<SupportAssistantReply> send({
    required String message,
    String? conversationId,
  }) async {
    requireUserId();
    final data = await _invoke(
      'support-chat',
      body: {
        'message': message.trim(),
        'conversation_id': conversationId,
        'client_request_id': _uuid.v4(),
      },
    );
    final citations = _citations(data['citations']);
    final handoff = data['handoff'] is Map
        ? Map<String, dynamic>.from(data['handoff'] as Map)
        : const <String, dynamic>{};
    return SupportAssistantReply(
      conversationId: data['conversation_id'].toString(),
      message: SupportAssistantMessage.fromJson(
        Map<String, dynamic>.from(data['message'] as Map),
        citations: citations,
      ),
      citations: citations,
      classification: data['classification'] is Map
          ? Map<String, dynamic>.from(data['classification'] as Map)
          : const {},
      ticketId: handoff['ticket_id']?.toString(),
      caseNumber: handoff['case_number']?.toString(),
    );
  }

  Future<List<SupportAssistantConversation>> listConversations() async {
    requireUserId();
    final raw = await client.rpc('support_list_my_conversations');
    return (raw as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => SupportAssistantConversation.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<SupportAssistantThread> getConversation(String conversationId) async {
    requireUserId();
    final data = _rpcMap(
      await client.rpc(
        'support_get_my_conversation',
        params: {'p_conversation_id': conversationId},
      ),
      'The support conversation is unavailable.',
    );
    final citations = _citations(data['citations']);
    return SupportAssistantThread(
      conversation: SupportAssistantConversation.fromJson(
        Map<String, dynamic>.from(data['conversation'] as Map),
      ),
      messages: (data['messages'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => SupportAssistantMessage.fromJson(
              Map<String, dynamic>.from(item),
              citations: citations,
            ),
          )
          .toList(growable: false),
      citations: citations,
    );
  }

  Future<bool> deleteConversation(String conversationId) async {
    requireUserId();
    final data = _rpcMap(
      await client.rpc(
        'support_delete_my_conversation',
        params: {'p_conversation_id': conversationId},
      ),
      'The support conversation could not be deleted.',
    );
    return data['ok'] == true;
  }

  Future<void> feedback({
    required String messageId,
    required String rating,
    String? comment,
  }) async {
    await _invoke(
      'support-feedback',
      body: {'message_id': messageId, 'rating': rating, 'comment': comment},
    );
  }

  Future<void> report({
    required String messageId,
    required String category,
    String? comment,
  }) async {
    await _invoke(
      'support-report-ai-response',
      body: {'message_id': messageId, 'category': category, 'comment': comment},
    );
  }

  Future<Map<String, dynamic>> requestHuman({
    required String conversationId,
    required String subject,
    required String summary,
    String category = 'other',
  }) => _invoke(
    'support-create-ticket',
    body: {
      'conversation_id': conversationId,
      'subject': subject,
      'summary': summary,
      'category': category,
    },
  );

  Future<XFile?> chooseAttachment({ImageSource source = ImageSource.gallery}) =>
      _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
        requestFullMetadata: false,
      );

  Future<SupportAssistantAttachment> uploadAttachment({
    required String conversationId,
    required XFile file,
    String purpose = 'Screenshot of the visible support issue',
  }) async {
    requireUserId();
    final source = await file.readAsBytes();
    final processed = SafeImageProcessor.proof(
      source,
      maximumBytes: maximumSourceBytes,
    );
    if (processed.length > 5 * 1024 * 1024) {
      throw const MortCodedError(
        'support_attachment_size_invalid',
        'Choose a smaller image and try again.',
      );
    }
    final authorization = await _invoke(
      'support-upload-authorize',
      body: {
        'action': 'authorize',
        'conversation_id': conversationId,
        'original_name': 'support-image.jpg',
        'content_type': 'image/jpeg',
        'byte_size': processed.length,
        'sha256': sha256.convert(processed).toString(),
        'purpose': purpose,
        'client_request_id': _uuid.v4(),
      },
    );
    final id = authorization['attachment_id']?.toString() ?? '';
    final objectPath = authorization['object_path']?.toString() ?? '';
    if (id.isEmpty || objectPath.isEmpty) {
      throw const MortCodedError(
        'invalid_support_response',
        'The private upload could not be prepared.',
      );
    }
    try {
      await client.storage
          .from(attachmentBucket)
          .uploadBinary(
            objectPath,
            Uint8List.fromList(processed),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '300',
              upsert: false,
            ),
          );
      await _invoke(
        'support-upload-authorize',
        body: {'action': 'submit', 'attachment_id': id},
      );
      return SupportAssistantAttachment(id: id, objectPath: objectPath);
    } catch (_) {
      try {
        await client.storage.from(attachmentBucket).remove([objectPath]);
      } catch (_) {
        // The opaque private manifest expires and remains unavailable publicly.
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String function, {
    required Map<String, dynamic> body,
  }) async {
    requireUserId();
    final response = await client.functions.invoke(function, body: body);
    if (response.data is! Map) {
      throw const MortCodedError(
        'invalid_support_response',
        'MORT Support returned an invalid response.',
      );
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['ok'] != true) {
      final code = data['code']?.toString() ?? 'support_operation_failed';
      throw MortCodedError(code, _messageForCode(code));
    }
    return data;
  }

  Map<String, dynamic> _rpcMap(Object? value, String message) {
    if (value is! Map) {
      throw MortCodedError('invalid_support_response', message);
    }
    final data = Map<String, dynamic>.from(value);
    if (data['ok'] != true) {
      final code = data['code']?.toString() ?? 'support_operation_failed';
      throw MortCodedError(code, _messageForCode(code));
    }
    return data;
  }

  List<SupportAssistantCitation> _citations(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => SupportAssistantCitation.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);

  String _messageForCode(String code) => switch (code) {
    'support_rate_limited' =>
      'Ordinary chat is temporarily limited. Your case is not deleted. Safety Center and human support remain available.',
    'repeated_support_message' =>
      'That message was already sent. Wait a moment or add new details.',
    'prohibited_attachment' =>
      'That file or description may contain prohibited sensitive information.',
    'support_timeout' =>
      'MORT Support took too long to respond. Check your connection and retry.',
    _ => 'MORT Support could not complete that request. Try again.',
  };
}
