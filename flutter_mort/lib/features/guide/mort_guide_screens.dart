import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/mort_guide_repository.dart';
import '../../data/repositories/providers.dart';

class MortGuideEntryButton extends StatelessWidget {
  const MortGuideEntryButton({super.key});

  @override
  Widget build(BuildContext context) => MortButton(
    label: 'Ask MORT Guide',
    icon: Icons.assistant_outlined,
    onPressed: () => context.go('/guide'),
  );
}

class MortGuideView extends ConsumerStatefulWidget {
  const MortGuideView({super.key, this.initialConversationId});

  final String? initialConversationId;

  @override
  ConsumerState<MortGuideView> createState() => _MortGuideViewState();
}

class _MortGuideViewState extends ConsumerState<MortGuideView> {
  final _question = TextEditingController();
  final List<MortGuideMessage> _messages = [];
  String? _conversationId;
  String _mode = 'faq_only';
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _safetyEscalation = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.initialConversationId;
    _load();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = ref.read(mortGuideRepositoryProvider);
      final config = await repository.getConfig();
      final messages = _conversationId == null
          ? const <MortGuideMessage>[]
          : await repository.getMessages(_conversationId!);
      if (!mounted) return;
      setState(() {
        _mode = config['mode']?.toString() ?? 'faq_only';
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFacingError(error);
      });
    }
  }

  Future<void> _ask([String? suggested]) async {
    final text = (suggested ?? _question.text).trim();
    if (text.length < 3 || _sending) return;
    final userMessage = MortGuideMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _sending = true;
      _error = null;
      _question.clear();
      _messages.add(userMessage);
    });
    try {
      final reply = await ref
          .read(mortGuideRepositoryProvider)
          .ask(question: text, conversationId: _conversationId);
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId;
        _mode = reply.mode;
        _safetyEscalation = reply.safetyEscalation;
        _messages.add(reply.message);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((message) => message.id == userMessage.id);
        _question.text = text;
        _error = userFacingError(error);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const MortLoading(label: 'Opening MORT Guide...');
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: _mode == 'faq_only' ? 'Approved MORT help' : 'AI assisted',
          title: 'MORT Guide',
          subtitle:
              'Ask about MORT, jobs, applications, contracts, payments, reports, or account controls.',
          trailing: MortIconButton(
            icon: Icons.history,
            tooltip: 'MORT Guide history',
            onPressed: () => context.go('/guide/history'),
          ),
        ),
        const MortSafetyBanner(
          message:
              'AI may make mistakes. Do not share IDs, passwords, exact addresses, or emergency evidence. MORT Guide is not emergency, legal, or medical assistance.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_messages.isEmpty)
          MortGuideSuggestedQuestions(onSelected: _ask)
        else
          for (final message in _messages) ...[
            MortGuideMessageBubble(
              message: message,
              onFeedback: message.role == 'assistant'
                  ? () => MortGuideFeedbackSheet.show(
                      context,
                      repository: ref.read(mortGuideRepositoryProvider),
                      messageId: message.id,
                    )
                  : null,
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
        if (_safetyEscalation) ...[
          const MortGuideSafetyEscalation(),
          const SizedBox(height: MortSpacing.md),
        ],
        if (_error != null) ...[
          MortErrorState(
            title: 'MORT Guide could not answer',
            message: _error!,
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        MortTextArea(
          label: 'Ask a MORT question',
          controller: _question,
          hint: 'How do completion checks work?',
          maxLines: 3,
          maxLength: 500,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Send',
          icon: Icons.send_outlined,
          busy: _sending,
          busyLabel: 'Checking MORT help...',
          onPressed: _sending ? null : _ask,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Privacy',
              icon: Icons.privacy_tip_outlined,
              onPressed: () => MortGuidePrivacySheet.show(context),
            ),
            const MortAction(
              label: 'Human support',
              icon: Icons.support_agent,
              route: '/support',
            ),
          ],
        ),
      ],
    );
  }
}

class MortGuideMessageBubble extends StatelessWidget {
  const MortGuideMessageBubble({
    super.key,
    required this.message,
    this.onFeedback,
  });

  final MortGuideMessage message;
  final VoidCallback? onFeedback;

  @override
  Widget build(BuildContext context) {
    final assistant = message.role == 'assistant';
    return Align(
      alignment: assistant ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: MortCard(
          color: assistant ? MortColors.card : MortColors.neonDeep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assistant ? 'MORT Guide' : 'You',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: assistant ? MortColors.neon : MortColors.text,
                ),
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(message.content),
              if (message.source != null) ...[
                const SizedBox(height: MortSpacing.sm),
                MortGuideSourceCard(source: message.source!),
              ],
              if (onFeedback != null) ...[
                const SizedBox(height: MortSpacing.xs),
                TextButton.icon(
                  onPressed: onFeedback,
                  icon: const Icon(Icons.rate_review_outlined, size: 17),
                  label: const Text('Rate answer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MortGuideSuggestedQuestions extends StatelessWidget {
  const MortGuideSuggestedQuestions({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const questions = [
    'How do I apply for a job?',
    'How do completion checks work?',
    'How do I report or block someone?',
    'How do I delete my account?',
    'What stays free without MORT Plus?',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: MortSpacing.sm,
    runSpacing: MortSpacing.sm,
    children: [
      for (final question in questions)
        ActionChip(
          label: Text(question),
          avatar: const Icon(Icons.help_outline, size: 18),
          onPressed: () => onSelected(question),
        ),
    ],
  );
}

class MortGuideSourceCard extends StatelessWidget {
  const MortGuideSourceCard({super.key, required this.source});

  final MortGuideSource source;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final route = safeInternalHelpRoute(source.route);
      if (route != null) {
        context.go(route);
      } else if (source.url.isNotEmpty) {
        final uri = safeExternalHttpsUri(source.url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            MortToast.show(context, 'This source link could not be opened.');
          }
        }
      }
    },
    child: Row(
      children: [
        const Icon(
          Icons.menu_book_outlined,
          size: 18,
          color: MortColors.safetyBlue,
        ),
        const SizedBox(width: MortSpacing.xs),
        Expanded(child: Text('Source: ${source.title}')),
        const Icon(Icons.open_in_new, size: 16),
      ],
    ),
  );
}

class MortGuideSafetyEscalation extends StatelessWidget {
  const MortGuideSafetyEscalation({super.key});

  @override
  Widget build(BuildContext context) => MortCard(
    color: MortColors.danger.withValues(alpha: 0.12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Immediate safety', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: MortSpacing.xs),
        const Text(
          'If anyone may be in immediate danger, contact local emergency services. MORT has not dispatched help.',
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Open Safety Center',
          icon: Icons.health_and_safety_outlined,
          onPressed: () => context.go('/safety'),
          style: MortButtonStyle.danger,
        ),
      ],
    ),
  );
}

class MortGuideFeedbackSheet {
  const MortGuideFeedbackSheet._();

  static Future<void> show(
    BuildContext context, {
    required MortGuideRepository repository,
    required String messageId,
  }) {
    return MortBottomSheet.show<void>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rate this answer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.md),
          for (final item in const [
            ('Helpful', 'helpful', Icons.thumb_up_outlined),
            ('Not helpful', 'not_helpful', Icons.thumb_down_outlined),
            ('Unsafe', 'unsafe', Icons.report_outlined),
          ]) ...[
            MortButton(
              label: item.$1,
              icon: item.$3,
              style: item.$2 == 'unsafe'
                  ? MortButtonStyle.danger
                  : MortButtonStyle.secondary,
              onPressed: () async {
                await repository.feedback(
                  messageId: messageId,
                  rating: item.$2,
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class MortGuidePrivacySheet {
  const MortGuidePrivacySheet._();

  static Future<void> show(BuildContext context) => MortBottomSheet.show<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MORT Guide privacy',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: MortSpacing.sm),
        const Text(
          'FAQ mode searches approved MORT help inside Supabase and sends nothing to an external AI provider. Conversation history is private, expires automatically, and can be deleted here. Never send IDs, face captures, passwords, exact addresses, private messages, payment tokens, or incident evidence.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Manage history',
          icon: Icons.history,
          onPressed: () {
            Navigator.pop(context);
            context.go('/guide/history');
          },
        ),
      ],
    ),
  );
}

class MortGuideHistoryView extends ConsumerWidget {
  const MortGuideHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<MortGuideConversation>>(
      future: ref.read(mortGuideRepositoryProvider).listConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? const <MortGuideConversation>[];
        return MortScreen(
          children: [
            const MortHeader(
              eyebrow: 'Private history',
              title: 'MORT Guide history',
              subtitle:
                  'Open one conversation or delete all MORT Guide history.',
            ),
            if (snapshot.connectionState != ConnectionState.done)
              const MortLoading(label: 'Loading history...', fullScreen: false)
            else if (snapshot.hasError)
              MortErrorState(
                title: 'History unavailable',
                message: userFacingError(snapshot.error),
              )
            else if (conversations.isEmpty)
              const MortEmptyState(
                title: 'No saved conversations',
                message: 'New MORT Guide questions will appear here.',
              )
            else
              for (final conversation in conversations) ...[
                MortCard(
                  onTap: () =>
                      context.go('/guide/conversation/${conversation.id}'),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      const SizedBox(width: MortSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(conversation.title),
                            Text(
                              '${conversation.mode.replaceAll('_', ' ')} help',
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.sm),
              ],
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Delete all MORT Guide history',
              icon: Icons.delete_outline,
              style: MortButtonStyle.danger,
              onPressed: () => context.go('/guide/delete-history'),
            ),
          ],
        );
      },
    );
  }
}

class MortGuideDeleteHistoryView extends ConsumerStatefulWidget {
  const MortGuideDeleteHistoryView({super.key});

  @override
  ConsumerState<MortGuideDeleteHistoryView> createState() =>
      _MortGuideDeleteHistoryViewState();
}

class _MortGuideDeleteHistoryViewState
    extends ConsumerState<MortGuideDeleteHistoryView> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Delete MORT Guide history?',
      message: 'This permanently removes your saved MORT Guide conversations.',
      confirmLabel: 'Delete history',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    await ref.read(mortGuideRepositoryProvider).deleteAllHistory();
    if (mounted) context.go('/guide/history');
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Privacy control',
        title: 'Delete MORT Guide history',
        subtitle:
            'This removes your conversation messages. Safety and provider audit records retain only minimal non-content metadata under policy.',
      ),
      MortButton(
        label: 'Delete all history',
        icon: Icons.delete_forever_outlined,
        style: MortButtonStyle.danger,
        busy: _busy,
        onPressed: _busy ? null : _delete,
      ),
    ],
  );
}
