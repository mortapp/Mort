import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../services/native_permissions_service.dart';

class NativePermissionsScreen extends StatefulWidget {
  const NativePermissionsScreen({super.key});

  @override
  State<NativePermissionsScreen> createState() =>
      _NativePermissionsScreenState();
}

class _NativePermissionsScreenState extends State<NativePermissionsScreen> {
  final _service = const NativePermissionsService();
  late Future<NativePermissionSnapshot> _future;
  bool _busy = false;
  String? _areaMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _service.snapshot();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _refresh();
        });
      }
    }
  }

  Future<void> _resolveArea() async {
    await _run(() async {
      final area = await _service.resolveCurrentGeneralArea();
      if (!mounted) return;
      setState(() {
        _areaMessage =
            'General area found: ${area.city}, ${area.state}. Raw coordinates were discarded and were not uploaded.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Device controls',
          title: 'Permissions',
          subtitle:
              'MORT asks only when you use a related feature. Background location is not requested.',
        ),
        FutureBuilder<NativePermissionSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortLoading(
                label: 'Checking device permissions...',
                fullScreen: false,
              );
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Permission status unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => setState(_refresh),
                ),
              );
            }
            final status = snapshot.requireData;
            return Column(
              children: [
                _PermissionCard(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  status: _permissionLabel(status.notifications),
                  detail:
                      'Permission enables alerts on this device. Remote push delivery is not active in this closed-test build; in-app notifications still work.',
                  onRequest: _busy
                      ? null
                      : () => _run(() async {
                          await _service.requestNotifications();
                        }),
                ),
                const SizedBox(height: MortSpacing.sm),
                _PermissionCard(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  status: _permissionLabel(status.camera),
                  detail:
                      'Used only after you choose camera capture for job proof, profile images, or report evidence. Real ID collection remains disabled.',
                  onRequest: _busy
                      ? null
                      : () => _run(() async {
                          await _service.requestCamera();
                        }),
                ),
                const SizedBox(height: MortSpacing.sm),
                _PermissionCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  status: status.photoPickerNeedsBroadPermission
                      ? _permissionLabel(status.photos)
                      : 'System picker - no broad library permission',
                  detail: status.photoPickerNeedsBroadPermission
                      ? 'iOS can grant selected-photo or full-library access. MORT uses only the item you choose.'
                      : 'Android uses the system photo picker so MORT does not request broad media-library access.',
                  onRequest: _busy || !status.photoPickerNeedsBroadPermission
                      ? null
                      : () => _run(() async {
                          await _service.requestPhotos();
                        }),
                ),
                const SizedBox(height: MortSpacing.sm),
                _PermissionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Foreground location',
                  status:
                      '${status.location.name.replaceAll('_', ' ')}; services ${status.locationServicesEnabled ? 'on' : 'off'}',
                  detail:
                      'A user-initiated lookup may resolve the current position to city/state for coarse job search. MORT discards the raw coordinates. Manual city/state search always remains available.',
                  onRequest: _busy || kIsWeb ? null : _resolveArea,
                ),
              ],
            );
          },
        ),
        if (_areaMessage != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            color: MortColors.neon.withValues(alpha: 0.08),
            child: Text(_areaMessage!),
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Open device settings',
          icon: Icons.settings_outlined,
          style: MortButtonStyle.ghost,
          onPressed: kIsWeb ? null : _service.openSettings,
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Location sharing is off by default. MORT does not request Android background location and does not expose a teen\'s live location to a job poster.',
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;
  final VoidCallback? onRequest;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MortColors.safetyBlue),
              const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          MortBadge(label: status, color: MortColors.safetyBlue),
          const SizedBox(height: MortSpacing.sm),
          Text(detail),
          if (onRequest != null) ...[
            const SizedBox(height: MortSpacing.md),
            MortButton(
              label: 'Request when needed',
              icon: Icons.check_circle_outline,
              style: MortButtonStyle.secondary,
              onPressed: onRequest,
            ),
          ],
        ],
      ),
    );
  }
}

String _permissionLabel(PermissionStatus status) =>
    status.name.replaceAll('_', ' ');
