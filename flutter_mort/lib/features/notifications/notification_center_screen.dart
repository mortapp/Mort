import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/routing/notification_destination.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/providers.dart';
import '../../services/push/push_notification_coordinator.dart';
import '../../services/push/remote_push_provider.dart';

const _notificationCategoryLabels = <String, String>{
  'application_updates': 'Application updates',
  'job_updates': 'Job updates',
  'schedule_changes': 'Schedule changes',
  'new_messages': 'New messages',
  'work_reminders': 'Start, check-in, and completion reminders',
  'support_updates': 'Support updates',
  'guardian_updates': 'Guardian-authorized updates',
  'verification_updates': 'Verification updates',
  'dispute_updates': 'Dispute updates',
};

class _NotificationSettingsSnapshot {
  const _NotificationSettingsSnapshot({
    required this.preferences,
    required this.status,
    required this.permission,
  });

  final NotificationPreferences preferences;
  final PushRegistrationStatus status;
  final RemotePushPermission permission;
}

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  late Future<List<MortNotificationItem>> _future;
  late Future<_NotificationSettingsSnapshot> _settingsFuture;
  bool _busy = false;
  bool _settingsBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _settingsFuture = _loadSettings();
  }

  Future<List<MortNotificationItem>> _load() {
    return ref.read(notificationsRepositoryProvider).listMine();
  }

  void _reload() => setState(() => _future = _load());

  Future<_NotificationSettingsSnapshot> _loadSettings() async {
    final repository = ref.read(notificationsRepositoryProvider);
    return _NotificationSettingsSnapshot(
      preferences: await repository.getPreferences(),
      status: await repository.getPushStatus(),
      permission: await PushNotificationCoordinator.instance.permissionStatus(),
    );
  }

  void _reloadSettings() {
    setState(() => _settingsFuture = _loadSettings());
  }

  Future<void> _setPushEnabled(bool enabled) async {
    if (_settingsBusy) return;
    setState(() => _settingsBusy = true);
    try {
      if (enabled) {
        final permission = await PushNotificationCoordinator.instance
            .requestPermissionAndRegister();
        if (permission != RemotePushPermission.authorized &&
            permission != RemotePushPermission.provisional) {
          throw StateError(
            permission == RemotePushPermission.unavailable
                ? 'Remote alerts are not configured in this build.'
                : 'Notification permission was not granted.',
          );
        }
      } else {
        await PushNotificationCoordinator.instance
            .disableAllRemoteNotifications();
      }
      if (mounted) {
        MortToast.show(
          context,
          enabled ? 'Remote alerts enabled.' : 'Remote alerts disabled.',
        );
        _reloadSettings();
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _settingsBusy = false);
    }
  }

  Future<void> _savePreferences(NotificationPreferences preferences) async {
    if (_settingsBusy) return;
    setState(() => _settingsBusy = true);
    try {
      final timezone = await PushNotificationCoordinator.instance
          .localTimezoneName();
      await ref
          .read(notificationsRepositoryProvider)
          .updatePreferences(preferences.copyWith(timezoneName: timezone));
      if (mounted) _reloadSettings();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _settingsBusy = false);
    }
  }

  Future<void> _pickQuietTime(
    NotificationPreferences preferences, {
    required bool start,
  }) async {
    final initial = _parseTime(
      start ? preferences.quietStart : preferences.quietEnd,
    );
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? 'Quiet hours begin' : 'Quiet hours end',
    );
    if (selected == null || !mounted) return;
    final encoded = _encodeTime(selected);
    await _savePreferences(
      start
          ? preferences.copyWith(quietStart: encoded)
          : preferences.copyWith(quietEnd: encoded),
    );
  }

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
        FutureBuilder<_NotificationSettingsSnapshot>(
          future: _settingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return MortErrorState(
                title: 'Alert settings unavailable',
                message: snapshot.hasError
                    ? userFacingError(snapshot.error)
                    : 'MORT could not load alert settings.',
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reloadSettings,
                ),
              );
            }
            return _buildSettings(snapshot.data!);
          },
        ),
        const SizedBox(height: MortSpacing.lg),
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

  Widget _buildSettings(_NotificationSettingsSnapshot snapshot) {
    final preferences = snapshot.preferences;
    final coordinator = PushNotificationCoordinator.instance;
    final providerAvailable = coordinator.configured;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device alerts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(
            providerAvailable
                ? '${snapshot.status.activeDeviceCount} active device${snapshot.status.activeDeviceCount == 1 ? '' : 's'} using FCM.'
                : 'Remote alerts are not configured in this build. In-app updates remain available.',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow remote alerts'),
            subtitle: Text(_permissionLabel(snapshot.permission)),
            value: preferences.pushEnabled && providerAvailable,
            onChanged: _settingsBusy || !providerAvailable
                ? null
                : _setPushEnabled,
          ),
          const Divider(),
          Text(
            'Alert categories',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final entry in _notificationCategoryLabels.entries)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(entry.value),
              value: preferences.categories[entry.key] ?? true,
              onChanged: _settingsBusy
                  ? null
                  : (value) {
                      final categories = Map<String, bool>.from(
                        preferences.categories,
                      )..[entry.key] = value;
                      _savePreferences(
                        preferences.copyWith(categories: categories),
                      );
                    },
            ),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet hours'),
            subtitle: Text(
              'Uses ${preferences.timezoneName}. Safety and account-security alerts are not delayed.',
            ),
            value: preferences.quietHoursEnabled,
            onChanged: _settingsBusy
                ? null
                : (value) => _savePreferences(
                    preferences.copyWith(quietHoursEnabled: value),
                  ),
          ),
          if (preferences.quietHoursEnabled)
            Wrap(
              spacing: MortSpacing.sm,
              runSpacing: MortSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _settingsBusy
                      ? null
                      : () => _pickQuietTime(preferences, start: true),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text('From ${_displayTime(preferences.quietStart)}'),
                ),
                OutlinedButton.icon(
                  onPressed: _settingsBusy
                      ? null
                      : () => _pickQuietTime(preferences, start: false),
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('Until ${_displayTime(preferences.quietEnd)}'),
                ),
              ],
            ),
          const SizedBox(height: MortSpacing.sm),
          const Text(
            'Lock-screen alerts use generic text. MORT never puts exact addresses, job PINs, evidence, verification documents, or private message text in a push notification.',
          ),
        ],
      ),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

String _encodeTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

String _displayTime(String value) {
  final time = _parseTime(value);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';
}

String _permissionLabel(RemotePushPermission permission) =>
    switch (permission) {
      RemotePushPermission.authorized => 'Device permission granted',
      RemotePushPermission.provisional => 'Provisional device permission',
      RemotePushPermission.denied => 'Device permission denied',
      RemotePushPermission.notDetermined => 'Permission not requested',
      RemotePushPermission.unavailable => 'Provider setup required',
    };
