import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

class AdminMessageModerationScreen extends ConsumerStatefulWidget {
  const AdminMessageModerationScreen({super.key});

  @override
  ConsumerState<AdminMessageModerationScreen> createState() =>
      _AdminMessageModerationScreenState();
}

class _AdminMessageModerationScreenState
    extends ConsumerState<AdminMessageModerationScreen> {
  late Future<List<Map<String, dynamic>>> _queue;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _queue = ref.read(adminRepositoryProvider).messageModerationQueue();
  }

  void _refresh() => setState(_reload);

  Future<String?> _reason(String action) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$action message?'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Required moderation reason',
              errorText: validation,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 10) {
                  setDialogState(
                    () => validation = 'Enter at least 10 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _moderate(
    Map<String, dynamic> message,
    String status,
  ) async {
    final id = message['id']?.toString();
    if (id == null || id.isEmpty || _busyId != null) return;
    final reason = await _reason(switch (status) {
      'approved' => 'Approve and deliver this message',
      'blocked' => 'Keep this message blocked',
      _ => 'Remove this message',
    });
    if (reason == null || !mounted) return;
    setState(() => _busyId = id);
    try {
      await ref.read(adminRepositoryProvider).moderateMessage(
            messageId: id,
            status: status,
            reason: reason,
          );
      if (!mounted) return;
      MortToast.show(context, 'The moderation decision was recorded.');
      _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Restricted safety moderation',
          title: 'Message review queue',
          subtitle:
              'Messages held by the server-side safety scanner. Only authorized moderators can load this queue or change delivery status.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh message review queue',
            onPressed: _busyId == null ? _refresh : null,
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _queue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Message review queue unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final messages = snapshot.data ?? const [];
            if (messages.isEmpty) {
              return const MortEmptyState(
                title: 'No messages awaiting review',
                message: 'The server has no flagged or blocked messages in the queue.',
              );
            }
            return Column(
              children: [
                for (final message in messages) ...[
                  _MessageReviewCard(
                    message: message,
                    busy: _busyId == message['id']?.toString(),
                    onApprove: () => _moderate(message, 'approved'),
                    onKeepBlocked: () => _moderate(message, 'blocked'),
                    onRemove: () => _moderate(message, 'removed'),
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

class _MessageReviewCard extends StatelessWidget {
  const _MessageReviewCard({
    required this.message,
    required this.busy,
    required this.onApprove,
    required this.onKeepBlocked,
    required this.onRemove,
  });

  final Map<String, dynamic> message;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onKeepBlocked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = message['moderation_status']?.toString() ?? 'unknown';
    final hasAttachment = message['attachment_path'] != null;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              MortBadge(label: status),
              if (hasAttachment) const MortBadge(label: 'Attachment quarantined'),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          SelectableText(
            (message['body'] ?? '').toString(),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (message['moderation_reason'] != null) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(message['moderation_reason'].toString()),
          ],
          const SizedBox(height: MortSpacing.sm),
          Text('Sender: ${message['sender_id'] ?? 'unknown'}'),
          Text('Conversation: ${message['conversation_id'] ?? 'unknown'}'),
          Text('Received: ${message['created_at'] ?? 'unknown'}'),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Approve and deliver',
                icon: Icons.check_circle_outline,
                busy: busy,
                onPressed: onApprove,
              ),
              MortAction(
                label: 'Keep blocked',
                icon: Icons.block,
                busy: busy,
                onPressed: onKeepBlocked,
              ),
              MortAction(
                label: 'Remove',
                icon: Icons.delete_outline,
                busy: busy,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
