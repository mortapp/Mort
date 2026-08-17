import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/safe_uri.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/support_assistant_repository.dart';

class SupportAssistantScreen extends ConsumerStatefulWidget {
  const SupportAssistantScreen({super.key, this.initialConversationId});

  final String? initialConversationId;

  @override
  ConsumerState<SupportAssistantScreen> createState() =>
      _SupportAssistantScreenState();
}

class _SupportAssistantScreenState
    extends ConsumerState<SupportAssistantScreen> {
  final _composer = TextEditingController();
  final _messages = <SupportAssistantMessage>[];
  String? _conversationId;
  String? _ticketId;
  String? _caseNumber;
  String? _error;
  String? _retryMessage;
  bool _loading = true;
  bool _sending = false;
  bool _attachmentBusy = false;
  bool _assistantEnabled = true;
  // True once the conversation currently held in `_conversationId` has been
  // handed to a person (status = 'handed_off' server-side). The backend
  // refuses to append further automated messages to a closed conversation,
  // so once this is true a new send starts a fresh conversation rather than
  // surfacing a confusing "conversation not found" error.
  bool _currentConversationClosed = false;

  SupportAssistantRepository get _repository =>
      ref.read(supportAssistantRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _conversationId = widget.initialConversationId;
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final config = await _repository.getConfig();
      SupportAssistantThread? thread;
      if (_conversationId != null) {
        thread = await _repository.getConversation(_conversationId!);
      }
      if (!mounted) return;
      setState(() {
        _assistantEnabled = config['assistant_enabled'] != false;
        _messages
          ..clear()
          ..addAll(thread?.messages ?? const []);
        _ticketId = thread?.conversation.ticketId;
        _currentConversationClosed =
            thread?.conversation.status == 'handed_off';
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

  Future<void> _send([String? suggested]) async {
    final text = (suggested ?? _composer.text).trim();
    if (_sending || text.length < 3) return;
    final startingNewThread =
        _currentConversationClosed && _conversationId != null;
    final optimistic = SupportAssistantMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
      responseMode: 'deterministic',
      safetyLevel: 0,
    );
    setState(() {
      _sending = true;
      _error = null;
      _retryMessage = null;
      _composer.clear();
      _messages.add(optimistic);
    });
    try {
      final reply = await _repository.send(
        message: text,
        conversationId: startingNewThread ? null : _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = reply.conversationId;
        _messages.add(reply.message);
        _currentConversationClosed = reply.ticketId != null;
        // A ticket created by *this* reply belongs to the still-current
        // conversation and case card. A ticket carried over from an earlier,
        // now-closed conversation stays visible above as the prior case, so
        // it is left in place rather than cleared here.
        _ticketId = reply.ticketId ?? _ticketId;
        _caseNumber = reply.caseNumber ?? _caseNumber;
      });
      if (startingNewThread && mounted) {
        MortToast.show(
          context,
          'Your previous case is with a person. Continuing in a new conversation.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((message) => message.id == optimistic.id);
        _retryMessage = text;
        _composer.text = text;
        _error = userFacingError(error);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _requestHuman() async {
    if (_sending) return;
    if (_conversationId == null) {
      await _send('I want to talk to a real support person.');
      return;
    }
    setState(() => _sending = true);
    try {
      final response = await _repository.requestHuman(
        conversationId: _conversationId!,
        subject: 'User requested human support',
        summary:
            'The user explicitly requested a support person from the Support Assistant screen.',
      );
      final handoff = response['handoff'] is Map
          ? Map<String, dynamic>.from(response['handoff'] as Map)
          : response;
      if (!mounted) return;
      setState(() {
        _ticketId = handoff['ticket_id']?.toString() ?? _ticketId;
        _caseNumber = handoff['case_number']?.toString() ?? _caseNumber;
        _currentConversationClosed = true;
      });
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _chooseAttachment() async {
    if (_conversationId == null || _attachmentBusy) {
      MortToast.show(context, 'Send a message before adding a screenshot.');
      return;
    }
    final source = await MortBottomSheet.show<ImageSource>(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a private screenshot',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.sm),
          const Text(
            'MORT removes image metadata and re-encodes the image. Do not include IDs, payment cards, exact addresses, faces, private keys, PINs, or unrelated messages.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Choose photo',
            icon: Icons.photo_library_outlined,
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Use camera',
            icon: Icons.camera_alt_outlined,
            style: MortButtonStyle.secondary,
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _attachmentBusy = true);
    try {
      final file = await _repository.chooseAttachment(source: source);
      if (file == null) return;
      await _repository.uploadAttachment(
        conversationId: _conversationId!,
        file: file,
      );
      if (mounted) {
        MortToast.show(
          context,
          'Private screenshot submitted. A public link was not created.',
        );
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _attachmentBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MortLoading(label: 'Opening private MORT Support...');
    }
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: _assistantEnabled
              ? 'Automated support'
              : 'Guided support - assistant off',
          title: 'MORT Support Assistant',
          subtitle:
              'Approved MORT Help, deterministic safety routing, and a direct handoff to a person.',
          trailing: MortIconButton(
            icon: Icons.history,
            tooltip: 'Support Assistant history',
            onPressed: () => context.go('/support/chat/history'),
          ),
        ),
        const MortSafetyBanner(
          message:
              'Do not share passwords, PINs, job start/end codes, payment credentials, government IDs, exact home addresses, or emergency evidence. MORT has not dispatched help.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_ticketId != null) ...[
          SupportAssistantStatusCard(
            ticketId: _ticketId!,
            caseNumber: _caseNumber,
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        if (_messages.isEmpty && _error == null)
          SupportAssistantQuickReplies(onSelected: _send)
        else
          for (final message in _messages) ...[
            SupportAssistantMessageBubble(
              message: message,
              onHelpful: message.isAssistant
                  ? () => _repository.feedback(
                      messageId: message.id,
                      rating: 'helpful',
                    )
                  : null,
              onReport: message.isAssistant
                  ? () => SupportAssistantReportSheet.show(
                      context,
                      repository: _repository,
                      messageId: message.id,
                    )
                  : null,
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
        if (_sending) ...[
          const SupportAssistantTypingIndicator(),
          const SizedBox(height: MortSpacing.sm),
        ],
        if (_error != null) ...[
          MortErrorState(
            title: 'Support connection interrupted',
            message: _error!,
            action: _retryMessage == null
                ? MortButton(
                    label: 'Reload',
                    icon: Icons.refresh,
                    onPressed: _load,
                  )
                : MortButton(
                    label: 'Retry message',
                    icon: Icons.refresh,
                    onPressed: () => _send(_retryMessage),
                  ),
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        SupportAssistantComposer(
          controller: _composer,
          sending: _sending,
          attachmentBusy: _attachmentBusy,
          onSend: _send,
          onAttachment: _chooseAttachment,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Talk to a person',
              icon: Icons.support_agent,
              onPressed: _requestHuman,
            ),
            const MortAction(
              label: 'Safety Center',
              icon: Icons.health_and_safety_outlined,
              route: '/safety',
              style: MortButtonStyle.danger,
            ),
          ],
        ),
      ],
    );
  }
}

class SupportAssistantMessageBubble extends StatelessWidget {
  const SupportAssistantMessageBubble({
    super.key,
    required this.message,
    this.onHelpful,
    this.onReport,
  });

  final SupportAssistantMessage message;
  final Future<void> Function()? onHelpful;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: MortCard(
        color: message.isUser ? MortColors.roseGoldDeep : MortColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!message.isUser) ...[
                  const MortBrandMark(size: 24),
                  const SizedBox(width: MortSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    message.isUser ? 'You' : 'MORT - automated support',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: message.isUser
                          ? MortColors.text
                          : MortColors.roseGoldLight,
                    ),
                  ),
                ),
                if (!message.isUser)
                  MortBadge(
                    label: message.responseMode == 'anthropic'
                        ? 'AI assisted'
                        : 'Guided',
                    color: MortColors.lightBlue,
                  ),
              ],
            ),
            const SizedBox(height: MortSpacing.xs),
            Text(message.content),
            for (final source in message.citations) ...[
              const SizedBox(height: MortSpacing.sm),
              SupportAssistantSourceCard(source: source),
            ],
            if (onHelpful != null || onReport != null) ...[
              const SizedBox(height: MortSpacing.xs),
              Wrap(
                spacing: MortSpacing.xs,
                children: [
                  if (onHelpful != null)
                    TextButton.icon(
                      onPressed: () async {
                        await onHelpful!();
                        if (context.mounted) {
                          MortToast.show(context, 'Feedback saved.');
                        }
                      },
                      icon: const Icon(Icons.thumb_up_outlined, size: 17),
                      label: const Text('Helpful'),
                    ),
                  if (onReport != null)
                    TextButton.icon(
                      onPressed: onReport,
                      icon: const Icon(Icons.flag_outlined, size: 17),
                      label: const Text('Report answer'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SupportAssistantComposer extends StatelessWidget {
  const SupportAssistantComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.attachmentBusy,
    required this.onSend,
    required this.onAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final bool attachmentBusy;
  final VoidCallback onSend;
  final VoidCallback onAttachment;

  @override
  Widget build(BuildContext context) => MortGlassSheet(
    padding: const EdgeInsets.all(MortSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MortIconButton(
          icon: Icons.add_photo_alternate_outlined,
          tooltip: 'Add private screenshot',
          onPressed: attachmentBusy ? null : onAttachment,
        ),
        const SizedBox(width: MortSpacing.xs),
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Message MORT Support',
              counterText: '',
            ),
            onSubmitted: (_) => sending ? null : onSend(),
          ),
        ),
        const SizedBox(width: MortSpacing.xs),
        MortIconButton(
          icon: Icons.send_rounded,
          tooltip: 'Send message',
          onPressed: sending ? null : onSend,
        ),
      ],
    ),
  );
}

class SupportAssistantQuickReplies extends StatelessWidget {
  const SupportAssistantQuickReplies({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const replies = [
    'How do I apply for a job?',
    'I cannot sign in to my account.',
    'How do I report or block someone?',
    'I need help with a payment dispute.',
    'I want to talk to a real support person.',
  ];

  @override
  Widget build(BuildContext context) => MortCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What do you need help with?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MortSpacing.sm),
        Wrap(
          spacing: MortSpacing.sm,
          runSpacing: MortSpacing.sm,
          children: [
            for (final reply in replies)
              ActionChip(
                label: Text(reply),
                avatar: const Icon(Icons.arrow_outward, size: 17),
                onPressed: () => onSelected(reply),
              ),
          ],
        ),
      ],
    ),
  );
}

class SupportAssistantTypingIndicator extends StatelessWidget {
  const SupportAssistantTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: MortCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: MortSpacing.sm),
          Text('Checking approved MORT Help...'),
        ],
      ),
    ),
  );
}

class SupportAssistantStatusCard extends StatelessWidget {
  const SupportAssistantStatusCard({
    super.key,
    required this.ticketId,
    this.caseNumber,
  });

  final String ticketId;
  final String? caseNumber;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    infoAccent: true,
    child: Row(
      children: [
        const Icon(Icons.support_agent, color: MortColors.lightBlue),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Human support requested',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(caseNumber ?? 'A private case was created.'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.go('/support/ticket/$ticketId'),
          child: const Text('Open case'),
        ),
      ],
    ),
  );
}

class SupportAssistantSourceCard extends StatelessWidget {
  const SupportAssistantSourceCard({super.key, required this.source});

  final SupportAssistantCitation source;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final route = safeInternalHelpRoute(source.navigationRoute);
      if (route != null) {
        context.go(route);
        return;
      }
      final uri = safeExternalHttpsUri(source.sourceUrl ?? '');
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted)
          MortToast.show(context, 'This source is unavailable.');
      }
    },
    child: Row(
      children: [
        const Icon(
          Icons.menu_book_outlined,
          color: MortColors.lightBlue,
          size: 18,
        ),
        const SizedBox(width: MortSpacing.xs),
        Expanded(child: Text('Source: ${source.title}')),
        const Icon(Icons.chevron_right, size: 18),
      ],
    ),
  );
}

class SupportAssistantReportSheet {
  const SupportAssistantReportSheet._();

  static Future<void> show(
    BuildContext context, {
    required SupportAssistantRepository repository,
    required String messageId,
  }) => MortBottomSheet.show<void>(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Report this answer',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: MortSpacing.sm),
        const Text(
          'A trained person reviews reports. The assistant does not decide the outcome.',
        ),
        const SizedBox(height: MortSpacing.md),
        for (final item in const [
          ('Unsafe', 'unsafe'),
          ('Incorrect', 'incorrect'),
          ('Privacy concern', 'privacy'),
          ('Biased', 'bias'),
        ]) ...[
          MortButton(
            label: item.$1,
            style: item.$2 == 'unsafe'
                ? MortButtonStyle.danger
                : MortButtonStyle.secondary,
            onPressed: () async {
              await repository.report(messageId: messageId, category: item.$2);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
      ],
    ),
  );
}

class SupportAssistantHistoryScreen extends ConsumerWidget {
  const SupportAssistantHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(supportAssistantConversationsProvider);
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Private history',
          title: 'Support Assistant history',
          subtitle:
              'Guardian Mode does not grant automatic access to these conversations.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh support history',
            onPressed: () =>
                ref.invalidate(supportAssistantConversationsProvider),
          ),
        ),
        conversations.when(
          loading: () => const MortLoading(
            label: 'Loading support history...',
            fullScreen: false,
          ),
          error: (error, _) => MortErrorState(
            title: 'Support history unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () =>
                  ref.invalidate(supportAssistantConversationsProvider),
            ),
          ),
          data: (conversations) {
            if (conversations.isEmpty) {
              return const MortEmptyState(
                title: 'No Support Assistant conversations',
                message: 'Start a private support chat when you need help.',
              );
            }
            return Column(
              children: [
                for (final conversation in conversations) ...[
                  MortCard(
                    onTap: () => context.go('/support/chat/${conversation.id}'),
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
                                conversation.ticketId == null
                                    ? 'Private guided support'
                                    : 'Human case linked',
                              ),
                            ],
                          ),
                        ),
                        MortBadge(label: conversation.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
