import 'package:flutter/material.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import 'safety_device_status.dart';

class SafetyDeviceCard extends StatelessWidget {
  const SafetyDeviceCard({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<SafetyDeviceStatus>(
    valueListenable: safetyDeviceStatus,
    builder: (context, device, _) => MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MortSectionTitle(title: 'Device Safety'),
          Text(
            device.percent == null
                ? 'Battery unavailable'
                : 'Battery: ${device.percent}%',
          ),
          Text(device.label),
          Text(
            device.lastSync == null
                ? 'Connection not yet confirmed'
                : device.connected
                ? 'Last safety sync: ${device.lastSync!.toLocal()}'
                : 'Connection lost. Last sync: ${device.lastSync!.toLocal()}',
          ),
          const SizedBox(height: MortSpacing.sm),
          SwitchListTile.adaptive(
            title: const Text('MORT Safety Battery Saver'),
            subtitle: const Text(
              'Reduces motion, ads, analytics and location frequency. Calling, check-ins and safety sync stay available.',
            ),
            value: device.saver,
            onChanged: (enabled) async {
              if (!enabled) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Turn off MORT Battery Saver?'),
                    content: const Text(
                      'Ads, decorative motion and more frequent updates may use more battery. Safety tools remain available either way.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('Keep it on'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('Turn off'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              safetySaverOverride.value = enabled;
              safetyDeviceStatus.value = SafetyDeviceStatus(
                percent: device.percent,
                saver: enabled,
                label: device.label,
                lastSync: device.lastSync,
                connected: device.connected,
              );
              safetyMonitorRefresh.value++;
            },
          ),
          const Text(
            'MORT monitors while open. Android or iOS may pause it in the background; a lost connection is not proof of danger.',
          ),
        ],
      ),
    ),
  );
}
