import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

class AdminOperationalAlertsScreen extends ConsumerStatefulWidget {
  const AdminOperationalAlertsScreen({super.key});

  @override
  ConsumerState<AdminOperationalAlertsScreen> createState() =>
      _AdminOperationalAlertsScreenState();
}

class _AdminOperationalAlertsScreenState
    extends ConsumerState<AdminOperationalAlertsScreen> {
  late Future<List<Map<String, dynamic>>> _alerts;
  String _status = 'open';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _alerts = ref
        .read(adminRepositoryProvider)
        .operationalAlerts(status: _status);
  }

  void _refresh() => setState(_reload);

  Future<String?> _reason(String action) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('$action alert'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Required operational reason',
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
                final reason = controller.text.trim();
                if (reason.length < 10) {
                  setDialogState(
                    () => validation = 'Enter at least 10 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, reason);
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

  Future<void> _update(String id, String status) async {
    if (_busyId != null) return;
    final reason = await _reason(
      status == 'resolved' ? 'Resolve' : 'Acknowledge',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyId = id);
    try {
      await ref
          .read(adminRepositoryProvider)
          .acknowledgeOperationalAlert(
            alertId: id,
            status: status,
            reason: reason,
          );
      if (!mounted) return;
      MortToast.show(context, 'The server recorded the operational action.');
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
          eyebrow: 'Restricted operations',
          title: 'Operational alerts',
          subtitle:
              'Redacted reliability and safety signals. Every load and action requires a specialized server role.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh operational alerts',
            onPressed: _busyId == null ? _refresh : null,
          ),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'open', label: Text('Open')),
            ButtonSegment(value: 'acknowledged', label: Text('Acknowledged')),
            ButtonSegment(value: 'resolved', label: Text('Resolved')),
          ],
          selected: {_status},
          onSelectionChanged: _busyId == null
              ? (selection) {
                  setState(() {
                    _status = selection.first;
                    _reload();
                  });
                }
              : null,
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _alerts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Operational queue unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final alerts = snapshot.data ?? const [];
            if (alerts.isEmpty) {
              return const MortEmptyState(
                title: 'No alerts in this queue',
                message:
                    'Refresh after an incident or provider reconciliation event.',
              );
            }
            return Column(
              children: [
                for (final alert in alerts) ...[
                  _AlertCard(
                    alert: alert,
                    busy: _busyId == alert['id']?.toString(),
                    onAcknowledge: () =>
                        _update(alert['id'].toString(), 'acknowledged'),
                    onResolve: () =>
                        _update(alert['id'].toString(), 'resolved'),
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

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.busy,
    required this.onAcknowledge,
    required this.onResolve,
  });

  final Map<String, dynamic> alert;
  final bool busy;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity']?.toString() ?? 'warning';
    final actionable = alert['status'] != 'resolved';
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MortSpacing.xs,
            runSpacing: MortSpacing.xs,
            children: [
              MortBadge(
                label: _label(severity),
                color: severity == 'critical'
                    ? MortColors.danger
                    : severity == 'high'
                    ? MortColors.warning
                    : MortColors.safetyBlue,
              ),
              MortBadge(label: _label(alert['category'])),
              MortBadge(label: _label(alert['status'])),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(
            _label(alert['safe_code']),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Source: ${alert['source'] ?? 'unknown'}'),
          Text('Occurrences: ${alert['occurrence_count'] ?? 1}'),
          Text('Last observed: ${alert['last_observed_at'] ?? 'unknown'}'),
          if (alert['correlation_id'] != null)
            SelectableText('Correlation: ${alert['correlation_id']}'),
          if (actionable) ...[
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                if (alert['status'] == 'open')
                  MortAction(
                    label: 'Acknowledge',
                    icon: Icons.visibility_outlined,
                    busy: busy,
                    onPressed: onAcknowledge,
                  ),
                MortAction(
                  label: 'Resolve',
                  icon: Icons.task_alt,
                  busy: busy,
                  onPressed: onResolve,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _label(Object? value) {
  final words = (value?.toString() ?? 'unknown')
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty);
  return words
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
