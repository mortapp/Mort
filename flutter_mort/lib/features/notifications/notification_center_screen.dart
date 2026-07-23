import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/routing/notification_destination.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/providers.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  late Future<List<MortNotificationItem>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MortNotificationItem>> _load() {
    return ref.read(notificationsRepositoryProvider).listMine();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _markAllRead() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      if (!mounted) return;
      MortToast.show(context, 'Notifications marked read.');
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(MortNotificationItem item) async {
    if (item.isUnread) {
      try {
        await ref.read(notificationsRepositoryProvider).markRead(item.id);
      } catch (error) {
        if (mounted) MortToast.show(context, userFacingError(error));
        return;
      }
    }
    if (!mounted) return;
    final profile = ref.read(currentProfileProvider).asData?.value;
    context.go(notificationDestination(item.data, profile?.role));
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Notification center',
          title: 'Updates',
          subtitle:
              'Application, message, job, proof, review, guardian, safety, support, and verification events appear here.',
          trailing: MortIconButton(
            icon: Icons.done_all,
            tooltip: 'Mark all notifications read',
            onPressed: _busy ? null : _markAllRead,
          ),
        ),
        FutureBuilder<List<MortNotificationItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Notifications unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const MortEmptyState(
                title: 'No notifications',
                message:
                    'New application, message, safety, guardian, and job updates will appear here.',
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  MortCard(
                    color: item.isUnread
                        ? MortColors.safetyBlue.withValues(alpha: 0.1)
                        : MortColors.card,
                    onTap: () => _open(item),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isUnread
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none,
                          color: item.isUnread
                              ? MortColors.safetyBlue
                              : MortColors.textMuted,
                        ),
                        const SizedBox(width: MortSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: MortSpacing.xs),
                              Text(item.body),
                            ],
                          ),
                        ),
                        if (item.isUnread)
                          const MortBadge(label: 'new', color: MortColors.neon),
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
