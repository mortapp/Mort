import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../profile/profile_avatar_widgets.dart';

class GuardianSafetyPingsScreen extends ConsumerStatefulWidget {
  const GuardianSafetyPingsScreen({super.key});

  @override
  ConsumerState<GuardianSafetyPingsScreen> createState() =>
      _GuardianSafetyPingsScreenState();
}

class _GuardianSafetyPingsScreenState
    extends ConsumerState<GuardianSafetyPingsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref.read(safetyRepositoryProvider).listVisibleSafetyPings();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Guardian Mode',
          title: 'Safety pings',
          subtitle:
              'Only pings from actively linked teens with Safety Ping sharing enabled are visible here.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh safety pings',
            onPressed: _refresh,
          ),
        ),
        const MortSafetyBanner(
          message:
              'A Safety Ping is not emergency dispatch. Contact local emergency services when someone is in immediate danger.',
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Safety pings unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            }
            final rows = snapshot.data ?? const [];
            if (rows.isEmpty) {
              return const MortEmptyState(
                title: 'No shared safety pings',
                message:
                    'New pings appear only while a Guardian Mode link and its Safety Ping alert setting are active.',
              );
            }
            return Column(
              children: [
                for (final row in rows) ...[
                  _SafetyPingCard(row: row),
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

class _SafetyPingCard extends StatelessWidget {
  const _SafetyPingCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rawTeen = row['teen'];
    final teen = rawTeen is Map
        ? Map<String, dynamic>.from(rawTeen)
        : const <String, dynamic>{};
    final teenId = teen['id']?.toString() ?? row['teen_id'].toString();
    final name = teen['display_name']?.toString() ?? 'Linked teen';
    final status = (row['status'] ?? 'needs_help').toString().replaceAll(
      '_',
      ' ',
    );
    final createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatarView(
                profileId: teenId,
                avatarPath: teen['avatar_path']?.toString(),
                fallbackLabel: name,
                radius: 24,
              ),
              const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (createdAt != null)
                      Text(
                        _formatTimestamp(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              MortBadge(label: status, color: MortColors.warning),
            ],
          ),
          if ((row['note'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(row['note'].toString()),
          ],
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} at $hour:$minute $period';
  }
}
