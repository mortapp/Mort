import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/account_trust.dart';
import '../../data/repositories/providers.dart';
import '../../services/passkey_capability.dart';
import '../../services/app_lock_controller.dart';

class AccountTrustScreen extends ConsumerWidget {
  const AccountTrustScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountTrustProfileProvider);
    return profile.when(
      loading: () => const MortLoading(label: 'Loading account trust'),
      error: (error, _) => MortScreen(
        children: [
          MortHeader(
            eyebrow: 'Account trust',
            title: 'Trust profile unavailable',
            subtitle: userFacingError(error),
          ),
          MortButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () => ref.invalidate(accountTrustProfileProvider),
          ),
        ],
      ),
      data: (trust) => MortScreen(
        children: [
          MortHeader(
            eyebrow: trust.signalEnvironment == 'sandbox'
                ? 'TEST MODE'
                : 'Account trust',
            title: 'Your trust profile',
            subtitle: 'Signals are precise and server-derived. No badge guarantees identity, behavior, or safety.',
            trailing: MortIconButton(
              icon: Icons.refresh,
              tooltip: 'Refresh trust profile',
              onPressed: () => ref.invalidate(accountTrustProfileProvider),
            ),
          ),
          TrustLevelCard(profile: trust),
          const SizedBox(height: MortSpacing.md),
          _MarketplaceEligibilityCard(
            eligibility: trust.marketplaceEligibility,
          ),
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What this means',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Email and phone checks confirm control of contact methods. Device biometrics and passkeys protect account access. School and partner checks confirm affiliation. Business registry checks confirm a public record. These are different signals, not interchangeable identity proof.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Read trust-level details',
                  icon: Icons.info_outline,
                  style: MortButtonStyle.ghost,
                  onPressed: () => TrustExplanationSheet.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          Text(
            'Current indicators',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.sm),
          if (trust.indicators.isEmpty)
            const MortCard(
              child: Text(
                'No verified indicators are available yet. A basic account is not identity verified.',
              ),
            )
          else
            ...trust.indicators.map(
              (indicator) => Padding(
                padding: const EdgeInsets.only(bottom: MortSpacing.sm),
                child: _TrustIndicatorCard(indicator: indicator),
              ),
            ),
          const SizedBox(height: MortSpacing.sm),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy boundaries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: MortSpacing.sm),
                const Text('School names are private by default.'),
                const Text(
                  'Residential addresses are never public trust fields.',
                ),
                const Text(
                  'Email and phone values are not exposed in trust badges.',
                ),
                const Text(
                  'MORT does not use people-search or data-broker lookups.',
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              const MortAction(
                label: 'Device security',
                icon: Icons.phonelink_lock,
                route: '/settings/device-security',
              ),
              const MortAction(
                label: 'Passkeys',
                icon: Icons.key,
                route: '/settings/passkeys',
              ),
              const MortAction(
                label: 'School affiliation',
                icon: Icons.school_outlined,
                route: '/settings/school-affiliation',
              ),
              const MortAction(
                label: 'Partner code',
                icon: Icons.groups_outlined,
                route: '/settings/partner-code',
              ),
              const MortAction(
                label: 'Business registry',
                icon: Icons.business_outlined,
                route: '/settings/business-registry',
              ),
              const MortAction(
                label: 'Digital ID availability',
                icon: Icons.wallet_outlined,
                route: '/settings/digital-id',
              ),
              const MortAction(
                label: 'Appeal a trust decision',
                icon: Icons.support_agent,
                route: '/settings/trust-appeal',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrustLevelCard extends StatelessWidget {
  const TrustLevelCard({super.key, required this.profile});

  final AccountTrustProfile profile;

  @override
  Widget build(BuildContext context) {
    final progress = (profile.currentLevel / 5).clamp(0.0, 1.0).toDouble();
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.levelTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              MortBadge(
                label: 'Level ${profile.currentLevel} of 5',
                color: MortColors.safetyBlue,
                icon: Icons.shield_outlined,
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: MortColors.line,
            color: MortColors.safetyBlue,
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(
            'Policy version ${profile.policyVersion}. Trust levels describe completed checks; they are not a safety score.',
          ),
        ],
      ),
    );
  }
}

class TrustExplanationSheet extends StatelessWidget {
  const TrustExplanationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MortColors.card,
      builder: (_) => const TrustExplanationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const levels = [
      '0 - Basic account: an account exists; legal identity is not verified.',
      '1 - Account secured: account-security signals only, not identity.',
      '2 - Affiliation verified: an approved organization relationship was checked.',
      '3 - Government digital ID verified: reserved for a signed, server-validated credential.',
      '4 - Provider identity verified: reserved for an approved production provider result.',
      '5 - Enhanced adult screening: reserved for an approved screening policy and provider.',
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MortSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trust levels',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: MortSpacing.md),
            ...levels.map(
              (level) => Padding(
                padding: const EdgeInsets.only(bottom: MortSpacing.sm),
                child: Text(level),
              ),
            ),
            const Text(
              'Guardian Mode is optional. A specific job may still require guardian approval based on its risk policy.',
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceSecuritySettingsScreen extends ConsumerStatefulWidget {
  const DeviceSecuritySettingsScreen({super.key});

  @override
  ConsumerState<DeviceSecuritySettingsScreen> createState() =>
      _DeviceSecuritySettingsScreenState();
}

class _DeviceSecuritySettingsScreenState
    extends ConsumerState<DeviceSecuritySettingsScreen> {
  final _controller = AppLockController.instance;
  bool _enabled = false;
  double _minutes = 15;
  bool _ready = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _controller.initialize();
    if (!mounted) return;
    setState(() {
      _enabled = _controller.enabled;
      _minutes = _controller.inactivityMinutes.toDouble();
      _ready = true;
    });
  }

  Future<void> _save() async {
    final saved = await _controller.updateSettings(
      requireLock: _enabled,
      minutes: _minutes.round(),
    );
    if (!mounted) return;
    setState(() {
      _enabled = _controller.enabled;
      _message = saved
          ? _enabled
                ? 'App lock is enabled on this device.'
                : 'App lock is disabled on this device.'
          : _controller.failureMessage;
    });
  }

  Future<void> _test() async {
    final result = await _controller.testAuthentication();
    if (mounted) setState(() => _message = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(accountTrustProfileProvider).asData?.value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Account security',
          title: 'Device authentication',
          subtitle: 'Face ID, Touch ID, or a device passcode can protect sensitive actions. They do not verify legal identity.',
        ),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kIsWeb ? 'Web preview boundary' : 'On-device protection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.sm),
              Text(
                kIsWeb
                    ? 'A web page cannot invoke native Face ID, fingerprint, PIN, pattern, or passcode authentication. MORT does not receive or store biometric material.'
                    : '${_controller.capability.label} can protect MORT on this device. Android and iOS use the operating system prompt; MORT receives only success or failure.',
              ),
              const SizedBox(height: MortSpacing.sm),
              Text(
                'Server indicator configured: ${profile?.accountSecurity['device_biometrics_are_local_account_security_only'] == true ? 'local-security-only policy active' : 'profile unavailable'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                title: const Text('Require app lock'),
                subtitle: const Text(
                  'Lock after the app remains in the background for the selected time.',
                ),
                onChanged: _ready && !kIsWeb
                    ? (value) => setState(() => _enabled = value)
                    : null,
              ),
              Text('Lock after ${_minutes.round()} minute(s)'),
              Slider(
                value: _minutes,
                min: 1,
                max: 240,
                divisions: 239,
                label: '${_minutes.round()} min',
                onChanged: _ready && !kIsWeb
                    ? (value) => setState(() => _minutes = value)
                    : null,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'Save app-lock settings',
                icon: Icons.save_outlined,
                busy: _controller.authenticating,
                onPressed: _ready && !kIsWeb ? _save : null,
              ),
              const SizedBox(height: MortSpacing.sm),
              MortButton(
                label: 'Test device authentication',
                icon: Icons.fingerprint,
                style: MortButtonStyle.secondary,
                busy: _controller.authenticating,
                onPressed: _ready && !kIsWeb ? _test : null,
              ),
              if (_controller.enabled) ...[
                const SizedBox(height: MortSpacing.sm),
                MortButton(
                  label: 'Lock MORT now',
                  icon: Icons.lock_outline,
                  style: MortButtonStyle.ghost,
                  onPressed: _controller.lockNow,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: MortSpacing.sm),
                Text(_message!),
              ],
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const SensitiveActionGate(
          actionLabel: 'Local security boundary',
          child: Text(
            'Device authentication protects access on this phone. It never raises a MORT identity level, proves age, or uploads a face or fingerprint template.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortActionRow(
          actions: [
            MortAction(
              label: 'Review active sessions',
              icon: Icons.devices,
              route: '/settings/active-sessions',
            ),
          ],
        ),
      ],
    );
  }
}

class PasskeySettingsScreen extends ConsumerWidget {
  const PasskeySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverEnabled =
        ref
            .watch(accountTrustProfileProvider)
            .asData
            ?.value
            .passkeysEnabledByServer ??
        false;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Account security',
          title: 'Passkeys',
          subtitle: 'Passkeys can protect sign-in. They do not prove legal identity, age, address, or safety.',
        ),
        FutureBuilder<PasskeyCapability>(
          future: detectPasskeyCapability(),
          builder: (context, snapshot) {
            final capability = snapshot.data;
            return MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MortTrustBadge(
                    label: serverEnabled
                        ? 'Server enrollment enabled'
                        : 'Server enrollment disabled',
                    verified: serverEnabled,
                  ),
                  const SizedBox(height: MortSpacing.sm),
                  Text(capability?.detail ?? 'Checking browser capability...'),
                  const SizedBox(height: MortSpacing.sm),
                  Text(
                    'Browser API: ${capability?.browserApiAvailable == true ? 'available' : 'unavailable'}',
                  ),
                  Text(
                    'Secure context: ${capability?.secureContext == true ? 'yes' : 'no'}',
                  ),
                  Text(
                    'Platform authenticator: ${capability?.platformAuthenticatorAvailable == true ? 'reported available' : 'not confirmed'}',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        const VerificationUnavailableScreen(
          embedded: true,
          title: 'Enrollment is not active',
          detail: 'Passkeys remain disabled until account recovery and cross-platform testing are complete. No sign-in credential is simulated.',
        ),
      ],
    );
  }
}

class SchoolEmailVerificationScreen extends ConsumerStatefulWidget {
  const SchoolEmailVerificationScreen({super.key});

  @override
  ConsumerState<SchoolEmailVerificationScreen> createState() =>
      _SchoolEmailVerificationScreenState();
}

class _SchoolEmailVerificationScreenState
    extends ConsumerState<SchoolEmailVerificationScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      MortToast.show(
        context,
        'Enter the confirmed email used by this account.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(accountTrustRepositoryProvider)
          .requestSchoolAffiliation(_email.text);
      if (!mounted) return;
      setState(
        () => _result = value['message'] as String? ?? 'Request recorded.',
      );
      ref.invalidate(accountTrustProfileProvider);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Affiliation',
          title: 'School email',
          subtitle: 'An approved school domain can confirm affiliation. It does not verify government identity, age, enrollment status, or safety.',
        ),
        MortTextField(
          label: 'Confirmed account email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Check approved domain',
          icon: Icons.school_outlined,
          busy: _busy,
          onPressed: _submit,
        ),
        if (_result != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(child: Text(_result!)),
        ],
        const SizedBox(height: MortSpacing.md),
        const Text(
          'The address must already be the confirmed email for this account. MORT does not collect school documents or expose school names publicly by default.',
        ),
      ],
    );
  }
}

class PartnerCodeVerificationScreen extends ConsumerStatefulWidget {
  const PartnerCodeVerificationScreen({super.key});

  @override
  ConsumerState<PartnerCodeVerificationScreen> createState() =>
      _PartnerCodeVerificationScreenState();
}

class _PartnerCodeVerificationScreenState
    extends ConsumerState<PartnerCodeVerificationScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _result;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().length < 6) {
      MortToast.show(context, 'Enter the full partner code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(accountTrustRepositoryProvider)
          .redeemPartnerCode(_code.text);
      if (!mounted) return;
      setState(
        () => _result = value['message'] as String? ?? 'Affiliation recorded.',
      );
      _code.clear();
      ref.invalidate(accountTrustProfileProvider);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Affiliation',
          title: 'Partner program code',
          subtitle: 'A valid code confirms membership in an approved program. It does not verify legal identity or guarantee safety.',
        ),
        MortTextField(
          label: 'One-time or limited-use code',
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Redeem securely',
          icon: Icons.key,
          busy: _busy,
          onPressed: _submit,
        ),
        if (_result != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(child: Text(_result!)),
        ],
        const SizedBox(height: MortSpacing.md),
        const Text(
          'MORT stores a one-way code hash, enforces expiry and use limits, and does not expose the original code in review queues.',
        ),
      ],
    );
  }
}

class BusinessRegistryMatchScreen extends ConsumerStatefulWidget {
  const BusinessRegistryMatchScreen({super.key});

  @override
  ConsumerState<BusinessRegistryMatchScreen> createState() =>
      _BusinessRegistryMatchScreenState();
}

class _BusinessRegistryMatchScreenState
    extends ConsumerState<BusinessRegistryMatchScreen> {
  final _jurisdiction = TextEditingController(text: 'US-IN');
  final _legalName = TextEditingController();
  final _registration = TextEditingController();
  final _entityType = TextEditingController();
  final _source = TextEditingController(text: 'https://inbiz.in.gov/');
  bool _busy = false;
  String? _checkId;
  String? _result;

  @override
  void dispose() {
    _jurisdiction.dispose();
    _legalName.dispose();
    _registration.dispose();
    _entityType.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_legalName.text.trim().length < 2 ||
        _registration.text.trim().length < 2 ||
        !_source.text.trim().startsWith('https://')) {
      MortToast.show(
        context,
        'Enter the legal name, registry number, and official HTTPS source.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(accountTrustRepositoryProvider)
          .requestBusinessRegistryMatch(
            jurisdiction: _jurisdiction.text,
            legalName: _legalName.text,
            registrationNumber: _registration.text,
            entityType: _entityType.text,
            officialSourceUrl: _source.text,
          );
      if (!mounted) return;
      setState(() {
        _checkId = value['check_id'] as String?;
        _result = value['message'] as String? ?? 'Manual review requested.';
      });
      ref.invalidate(accountTrustProfileProvider);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    final id = _checkId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(accountTrustRepositoryProvider)
          .requestBusinessRepresentativeClaim(
            checkId: id,
            relationship: 'owner',
          );
      if (!mounted) return;
      setState(
        () => _result = value['message'] as String? ?? 'Claim recorded.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Business trust',
          title: 'Official registry match',
          subtitle: 'MORT accepts allowlisted official government registry sources for manual review. People-search and data-broker sources are rejected.',
        ),
        MortTextField(label: 'Jurisdiction code', controller: _jurisdiction),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(label: 'Legal business name', controller: _legalName),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(label: 'Registration number', controller: _registration),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(label: 'Entity type (optional)', controller: _entityType),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Official source URL',
          controller: _source,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Request manual registry review',
          icon: Icons.business_outlined,
          busy: _busy,
          onPressed: _submit,
        ),
        if (_checkId != null) ...[
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Attest owner relationship',
            icon: Icons.assignment_ind_outlined,
            style: MortButtonStyle.secondary,
            busy: _busy,
            onPressed: _claim,
          ),
        ],
        if (_result != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(child: Text(_result!)),
        ],
        const SizedBox(height: MortSpacing.md),
        const Text(
          'A registry match confirms a public business record exists. It does not prove that this account owns the business or is authorized to represent it. Representative identity requires a future approved provider.',
        ),
      ],
    );
  }
}

class DigitalIDAvailabilityScreen extends ConsumerWidget {
  const DigitalIDAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(accountTrustProfileProvider).asData?.value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Future identity route',
          title: 'Government digital credentials',
          subtitle: 'MORT does not collect physical ID images. Digital credential support is prepared but disabled.',
        ),
        _AvailabilityCard(
          title: 'Apple Verify with Wallet',
          enabled: profile?.appleWalletEnabled == true,
          detail: 'Requires Apple approval, the correct entitlement, an approved bundle, and server-side signed-response validation.',
        ),
        const SizedBox(height: MortSpacing.sm),
        _AvailabilityCard(
          title: 'Android digital credentials',
          enabled: profile?.androidDigitalCredentialsEnabled == true,
          detail: 'Requires Android Credential Manager integration, issuer/type policy, nonce binding, signature validation, and real-device QA.',
        ),
        const SizedBox(height: MortSpacing.md),
        const VerificationUnavailableScreen(
          embedded: true,
          title: 'Digital ID verification unavailable',
          detail: 'No wallet request is sent, no document is uploaded, and no identity result is granted. Invalid, expired, mismatched, unknown, and reused credential events are rejected.',
        ),
      ],
    );
  }
}

class VerificationUnavailableScreen extends StatelessWidget {
  const VerificationUnavailableScreen({
    super.key,
    required this.title,
    required this.detail,
    this.embedded = false,
  });

  final String title;
  final String detail;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_outlined, color: MortColors.warning),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.sm),
          Text(detail),
        ],
      ),
    );
    return embedded
        ? content
        : MortScreen(
            children: [
              const MortHeader(eyebrow: 'Unavailable', title: 'Verification'),
              content,
            ],
          );
  }
}

class VerificationAppealScreen extends ConsumerStatefulWidget {
  const VerificationAppealScreen({super.key});

  @override
  ConsumerState<VerificationAppealScreen> createState() =>
      _VerificationAppealScreenState();
}

class _VerificationAppealScreenState
    extends ConsumerState<VerificationAppealScreen> {
  final _reason = TextEditingController();
  bool _busy = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 20) {
      MortToast.show(context, 'Explain the issue in at least 20 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(accountTrustRepositoryProvider)
          .submitAppeal(reason: _reason.text);
      if (!mounted) return;
      setState(() => _submitted = true);
      _reason.clear();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Review',
          title: 'Appeal a trust decision',
          subtitle: 'Appeals enter a restricted human-review queue. Submitting one does not automatically change trust level or marketplace access.',
        ),
        MortTextArea(
          label: 'Reason for review',
          controller: _reason,
          maxLength: 2000,
          maxLines: 6,
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Submit appeal',
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: _submit,
        ),
        if (_submitted) ...[
          const SizedBox(height: MortSpacing.md),
          const MortCard(
            child: Text(
              'Appeal submitted. Access remains unchanged while a permitted reviewer evaluates it.',
            ),
          ),
        ],
      ],
    );
  }
}

class SensitiveActionGate extends StatelessWidget {
  const SensitiveActionGate({
    super.key,
    required this.actionLabel,
    required this.child,
  });

  final String actionLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: MortColors.warning),
              const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class TrustAdminReviewScreen extends ConsumerStatefulWidget {
  const TrustAdminReviewScreen({super.key});

  @override
  ConsumerState<TrustAdminReviewScreen> createState() =>
      _TrustAdminReviewScreenState();
}

class _TrustAdminReviewScreenState
    extends ConsumerState<TrustAdminReviewScreen> {
  final _reason = TextEditingController();
  final _caseId = TextEditingController();
  String _queue = 'school_domains';
  bool _busy = false;
  List<Map<String, dynamic>>? _items;

  static const _queues = {
    'school_domains': 'School domain requests',
    'partner_organizations': 'Partner organizations',
    'partner_codes': 'Partner code audit',
    'business_registry': 'Business registry reviews',
    'business_representatives': 'Business representatives',
    'verification_appeals': 'Verification appeals',
    'risk_signals': 'Risk signals',
    'account_security': 'Account security events',
    'provider_events': 'Provider events',
  };

  @override
  void dispose() {
    _reason.dispose();
    _caseId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_reason.text.trim().length < 12 || _caseId.text.trim().length < 4) {
      MortToast.show(
        context,
        'Enter an access reason and case ID for the audit log.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final items = await ref
          .read(accountTrustRepositoryProvider)
          .getAdminQueue(
            queue: _queue,
            accessReason: _reason.text,
            caseId: _caseId.text,
          );
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Restricted admin',
          title: 'Account trust review',
          subtitle: 'Queue access is role-scoped and logged with a reason and case ID. This screen never requests raw identity evidence.',
        ),
        MortDropdown<String>(
          label: 'Review queue',
          value: _queue,
          items: _queues,
          onChanged: (value) => setState(() => _queue = value ?? _queue),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(label: 'Case ID', controller: _caseId),
        const SizedBox(height: MortSpacing.sm),
        MortTextArea(
          label: 'Access reason',
          controller: _reason,
          maxLength: 800,
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Open audited queue',
          icon: Icons.policy_outlined,
          busy: _busy,
          onPressed: _load,
        ),
        if (_items != null) ...[
          const SizedBox(height: MortSpacing.md),
          Text(
            '${_items!.length} item(s)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MortSpacing.sm),
          if (_items!.isEmpty)
            const MortCard(child: Text('No records are waiting in this queue.'))
          else
            ..._items!.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: MortSpacing.sm),
                child: MortCard(child: SelectableText(_formatAdminItem(item))),
              ),
            ),
        ],
      ],
    );
  }
}

class _MarketplaceEligibilityCard extends StatelessWidget {
  const _MarketplaceEligibilityCard({required this.eligibility});

  final MarketplaceTrustEligibility eligibility;

  @override
  Widget build(BuildContext context) {
    final isSandbox = eligibility.testMode;
    final status = eligibility.allowed
        ? isSandbox
              ? 'QA sandbox access only'
              : 'Eligible under current policy'
        : eligibility.productionMarketplaceEnabled
        ? 'Requirements incomplete'
        : 'Marketplace access unavailable';
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortTrustBadge(label: status, verified: eligibility.allowed),
          const SizedBox(height: MortSpacing.sm),
          Text(
            eligibility.allowed && isSandbox
                ? 'This access is isolated test data and is not production verification.'
                : eligibility.allowed
                ? 'Server policy currently permits this account.'
                : 'Ordinary production users cannot enter the marketplace until approved production verification and launch policy are active.',
          ),
          if (eligibility.missingRequirements.isNotEmpty) ...[
            const SizedBox(height: MortSpacing.sm),
            Text(
              'Missing: ${eligibility.missingRequirements.map(_humanize).join(', ')}',
            ),
          ],
          const SizedBox(height: MortSpacing.sm),
          const Text(
            'Guardian Mode remains optional unless a specific job requires approval.',
          ),
        ],
      ),
    );
  }
}

class _TrustIndicatorCard extends StatelessWidget {
  const _TrustIndicatorCard({required this.indicator});

  final TrustIndicator indicator;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  indicator.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              MortBadge(
                label: _humanize(indicator.status),
                color:
                    indicator.status == 'verified' ||
                        indicator.status == 'configured'
                    ? MortColors.neon
                    : MortColors.warning,
              ),
            ],
          ),
          const SizedBox(height: MortSpacing.sm),
          Text('Checked: ${indicator.whatWasChecked}'),
          const SizedBox(height: MortSpacing.xs),
          Text('Not checked: ${indicator.whatWasNotChecked}'),
          if (indicator.environment == 'sandbox') ...[
            const SizedBox(height: MortSpacing.sm),
            const MortBadge(
              label: 'TEST MODE - not production verification',
              color: MortColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.title,
    required this.enabled,
    required this.detail,
  });

  final String title;
  final bool enabled;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortTrustBadge(
            label: enabled ? '$title enabled' : '$title disabled',
            verified: enabled,
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(detail),
        ],
      ),
    );
  }
}

String _humanize(String value) => value.replaceAll('_', ' ');

String _formatAdminItem(Map<String, dynamic> item) {
  final hiddenKeys = {'email', 'phone', 'address', 'raw_evidence', 'document'};
  return item.entries
      .where((entry) => !hiddenKeys.contains(entry.key.toLowerCase()))
      .map((entry) => '${_humanize(entry.key)}: ${entry.value}')
      .join('\n');
}
