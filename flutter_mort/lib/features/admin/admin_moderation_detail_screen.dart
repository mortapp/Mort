import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

enum AdminModerationRecordType { report, identityVerification }

extension on AdminModerationRecordType {
  String get wireName => switch (this) {
    AdminModerationRecordType.report => 'report',
    AdminModerationRecordType.identityVerification => 'identity_verification',
  };

  String get title => switch (this) {
    AdminModerationRecordType.report => 'Report detail',
    AdminModerationRecordType.identityVerification =>
      'Identity verification detail',
  };
}

class AdminModerationDetailScreen extends ConsumerStatefulWidget {
  const AdminModerationDetailScreen({
    super.key,
    required this.recordType,
    required this.recordId,
  });

  final AdminModerationRecordType recordType;
  final String recordId;

  @override
  ConsumerState<AdminModerationDetailScreen> createState() =>
      _AdminModerationDetailScreenState();
}

class _AdminModerationDetailScreenState
    extends ConsumerState<AdminModerationDetailScreen> {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  late Future<Map<String, dynamic>> _record;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _record = _uuid.hasMatch(widget.recordId)
        ? ref
              .read(adminRepositoryProvider)
              .moderationRecord(
                recordType: widget.recordType.wireName,
                recordId: widget.recordId,
              )
        : Future.error(const FormatException('Invalid moderation record ID.'));
  }

  void _refresh() => setState(_reload);

  Future<String?> _reason({required String title}) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Required decision reason',
              errorText: error,
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
                  setDialogState(() => error = 'Enter at least 10 characters.');
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

  Future<void> _run(
    String title,
    Future<void> Function(String reason) operation,
  ) async {
    if (_busy) return;
    final reason = await _reason(title: title);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await operation(reason);
      if (!mounted) return;
      MortToast.show(context, 'The server confirmed the moderation action.');
      _refresh();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateReport(String status) => _run(
    '${_label(status)} report?',
    (reason) => ref
        .read(adminRepositoryProvider)
        .updateReportStatus(
          reportId: widget.recordId,
          status: status,
          reason: reason,
        ),
  );

  Future<void> _setAccountStatus(String userId, String status) => _run(
    '${_label(status)} target account?',
    (reason) => ref
        .read(adminRepositoryProvider)
        .setAccountStatus(userId: userId, status: status, reason: reason),
  );

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Restricted moderation',
          title: widget.recordType.title,
          subtitle:
              'Server authorization is checked for every load and action. Raw identity files and private storage paths are not returned here.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh record',
            onPressed: _busy ? null : _refresh,
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _record,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Record unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final record = Map<String, dynamic>.from(
              snapshot.data?['record'] as Map? ?? const {},
            );
            if (record.isEmpty) {
              return const MortEmptyState(
                title: 'No record returned',
                message:
                    'The record no longer exists or this reviewer no longer has access.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in record.entries)
                        if (entry.value != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: MortSpacing.sm,
                            ),
                            child: Semantics(
                              label: '${_label(entry.key)}: ${entry.value}',
                              child: Text(
                                '${_label(entry.key)}: ${entry.value}',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: MortSpacing.md),
                if (widget.recordType == AdminModerationRecordType.report)
                  _reportActions(record)
                else
                  const MortSafetyBanner(
                    message:
                        'Actual provider verification is not connected. Real ID collection is disabled, sandbox verification is QA-only, and no client-side approval action is available. Production decisions must come from a signed provider workflow after external approval.',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _reportActions(Map<String, dynamic> record) {
    final targetUserId = record['target_user_id']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortActionRow(
          actions: [
            MortAction(
              label: 'Begin review',
              icon: Icons.manage_search,
              busy: _busy,
              onPressed: () => _updateReport('reviewing'),
            ),
            MortAction(
              label: 'Resolve',
              icon: Icons.task_alt,
              busy: _busy,
              onPressed: () => _updateReport('resolved'),
            ),
            MortAction(
              label: 'Dismiss',
              icon: Icons.remove_circle_outline,
              busy: _busy,
              onPressed: () => _updateReport('dismissed'),
            ),
          ],
        ),
        if (targetUserId != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Suspend target account',
                icon: Icons.block,
                busy: _busy,
                onPressed: () => _setAccountStatus(targetUserId, 'suspended'),
              ),
              MortAction(
                label: 'Restore target account',
                icon: Icons.person_outline,
                busy: _busy,
                onPressed: () => _setAccountStatus(targetUserId, 'active'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _label(Object value) => value
    .toString()
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
