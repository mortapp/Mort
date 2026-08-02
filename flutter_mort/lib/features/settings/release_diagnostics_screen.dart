import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/observability/diagnostics_export.dart';
import '../../core/observability/product_analytics.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

final _serverReleaseStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.read(missionPilotRepositoryProvider).releaseModeStatus();
    });

class ReleaseDiagnosticsScreen extends ConsumerWidget {
  const ReleaseDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverStatus = ref.watch(_serverReleaseStatusProvider);
    final local = AppConfig.safeReleaseDiagnostics;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Non-secret diagnostics',
          title: 'Release status',
          subtitle:
              'Build capabilities and server safety gates. Credentials, tokens, URLs, and user data are never shown.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.sm),
              for (final entry in local.entries)
                _DiagnosticRow(label: entry.key, value: entry.value),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        serverStatus.when(
          loading: () => const MortSkeletonCard(),
          error: (_, _) => const MortSafetyBanner(
            message:
                'Server safety controls could not be verified. Protected app routes remain fail closed.',
          ),
          data: (status) => MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server-authoritative gates',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MortSpacing.sm),
                _DiagnosticRow(
                  label: 'Release mode',
                  value: status['release_mode']?.toString() ?? 'unavailable',
                ),
                _DiagnosticRow(
                  label: 'Marketplace mode',
                  value:
                      status['marketplace_mode']?.toString() ?? 'unavailable',
                ),
                _DiagnosticRow(
                  label: 'Public marketplace',
                  value: _enabled(status['public_marketplace_enabled'] == true),
                ),
                _DiagnosticRow(
                  label: 'Real ID collection',
                  value: _enabled(status['real_document_collection'] == true),
                ),
                _DiagnosticRow(
                  label: 'Payments disabled',
                  value: _enabled(status['payments_disabled'] != false),
                ),
                _DiagnosticRow(
                  label: 'Maintenance',
                  value: _enabled(status['maintenance_mode'] == true),
                ),
              ],
            ),
          ),
        ),
        if (AppConfig.validationErrors.isNotEmpty) ...[
          const SizedBox(height: MortSpacing.md),
          MortSafetyBanner(
            message:
                'This build is fail closed: ${AppConfig.validationErrors.join('; ')}.',
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        const _AnalyticsPrivacyCard(),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Copy safe diagnostics',
          icon: Icons.copy_all_outlined,
          onPressed: () async {
            final diagnostics = await MortDiagnosticsExport.json();
            await Clipboard.setData(ClipboardData(text: diagnostics));
            if (context.mounted) {
              MortToast.show(context, 'Safe diagnostics copied.');
            }
          },
        ),
      ],
    );
  }
}

class _AnalyticsPrivacyCard extends StatefulWidget {
  const _AnalyticsPrivacyCard();

  @override
  State<_AnalyticsPrivacyCard> createState() => _AnalyticsPrivacyCardState();
}

class _AnalyticsPrivacyCardState extends State<_AnalyticsPrivacyCard> {
  bool _busy = false;
  bool _optedIn = MortProductAnalytics.instance.optedIn;

  Future<void> _update(bool value) async {
    setState(() => _busy = true);
    try {
      final updated = await MortProductAnalytics.instance.setConsent(value);
      if (mounted) setState(() => _optedIn = updated);
    } catch (_) {
      if (mounted) {
        MortToast.show(context, 'Analytics privacy setting was not changed.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = AppConfig.productAnalyticsEnabled;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy-preserving analytics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            available
                ? 'Share fixed product events such as opening Jobs or Support. MORT never includes messages, location, PINs, evidence, identity data, or advertising identifiers.'
                : 'Product analytics are disabled in this build. No product events are collected.',
          ),
          const SizedBox(height: MortSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share product analytics'),
            value: available && _optedIn,
            onChanged: available && !_busy ? _update : null,
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final enabled = value == 'enabled';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MortSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: MortSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: enabled ? MortColors.safetyBlue : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _enabled(bool value) => value ? 'enabled' : 'disabled';
