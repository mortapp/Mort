import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'repository_base.dart';

class MortGuideSource {
  const MortGuideSource({required this.title, required this.url, this.route});

  final String title;
  final String url;
  final String? route;

  factory MortGuideSource.fromJson(Map<String, dynamic> json) =>
      MortGuideSource(
        title: json['title']?.toString() ?? 'MORT Help',
        url: json['url']?.toString() ?? '',
        route: json['route']?.toString(),
      );
}

class MortGuideMessage {
  const MortGuideMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.source,
    this.providerGenerated = false,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final MortGuideSource? source;
  final bool providerGenerated;

  factory MortGuideMessage.fromJson(Map<String, dynamic> json) {
    final sourceUrl = json['source_url']?.toString();
    return MortGuideMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      providerGenerated: json['provider_generated'] == true,
      source: sourceUrl == null || sourceUrl.isEmpty
          ? null
          : MortGuideSource(
              title: json['source_title']?.toString() ?? 'MORT Help',
              url: sourceUrl,
              route: json['source_route']?.toString(),
            ),
    );
  }
}

class MortGuideReply {
  const MortGuideReply({
    required this.conversationId,
    required this.message,
    required this.safetyEscalation,
    required this.mode,
  });

  final String conversationId;
  final MortGuideMessage message;
  final bool safetyEscalation;
  final String mode;
}

class MortGuideConversation {
  const MortGuideConversation({
    required this.id,
    required this.title,
    required this.mode,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String mode;
  final DateTime updatedAt;

  factory MortGuideConversation.fromJson(Map<String, dynamic> json) =>
      MortGuideConversation(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? 'MORT Guide conversation',
        mode: json['mode']?.toString() ?? 'faq_only',
        updatedAt:
            DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class MortGuideRepository extends RepositoryBase {
  Future<Map<String, dynamic>> getConfig() async {
    final response = await client.rpc('get_mort_guide_config');
    return response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
  }

  Future<MortGuideReply> ask({
    required String question,
    String? conversationId,
  }) async {
    requireUserId();
    final response = await client.functions.invoke(
      'ai-support',
      body: {
        'question': question,
        'conversation_id': conversationId,
        'client_request_id': const Uuid().v4(),
      },
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : const <String, dynamic>{};
    if (data['ok'] != true) {
      throw FunctionException(
        status: response.status,
        details: data,
        reasonPhrase: data['code']?.toString() ?? 'MORT Guide unavailable',
      );
    }
    final sourceData = data['source'];
    final source = sourceData is Map
        ? MortGuideSource.fromJson(Map<String, dynamic>.from(sourceData))
        : null;
    return MortGuideReply(
      conversationId: data['conversation_id'].toString(),
      mode: data['mode']?.toString() ?? 'faq_only',
      safetyEscalation: data['safety_escalation'] == true,
      message: MortGuideMessage(
        id: data['message_id']?.toString() ?? const Uuid().v4(),
        role: 'assistant',
        content: data['answer']?.toString() ?? '',
        source: source,
        providerGenerated: data['provider_generated'] == true,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<MortGuideConversation>> listConversations() async {
    final response = await client.rpc('list_my_mort_guide_conversations');
    return (response as List<dynamic>? ?? const [])
        .map(
          (item) => MortGuideConversation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<List<MortGuideMessage>> getMessages(String conversationId) async {
    final response = await client.rpc(
      'get_my_mort_guide_messages',
      params: {'p_conversation_id': conversationId},
    );
    return (response as List<dynamic>? ?? const [])
        .map(
          (item) =>
              MortGuideMessage.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<bool> deleteConversation(String conversationId) async {
    final response = await client.rpc(
      'delete_my_mort_guide_conversation',
      params: {'p_conversation_id': conversationId},
    );
    return response == true;
  }

  Future<int> deleteAllHistory() async {
    final response = await client.rpc('delete_all_my_mort_guide_history');
    return response is int ? response : int.tryParse('$response') ?? 0;
  }

  Future<void> feedback({
    required String messageId,
    required String rating,
    String? comment,
  }) async {
    final response = await client.rpc(
      'submit_mort_guide_feedback',
      params: {
        'p_message_id': messageId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );
    if (response is! Map || response['ok'] != true) {
      throw StateError('MORT Guide feedback was not saved.');
    }
  }
}
