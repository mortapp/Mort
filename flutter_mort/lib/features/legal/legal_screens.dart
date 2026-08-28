import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

class LegalCenterScreen extends ConsumerWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Legal center',
          title: 'Exact versions, affirmative choices',
          subtitle:
              'Browsing MORT never creates acceptance. Only a published, effective, exact-hash version can be accepted.',
        ),
        const _LegalDraftWarning(),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<Map<String, dynamic>>(
          future: ref.read(legalContractRepositoryProvider).legalRequirements(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Legal requirements unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final requirements =
                (snapshot.data?['requirements'] as List? ?? const [])
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList(growable: false);
            if (requirements.isEmpty) {
              return const MortEmptyState(
                title: 'No approved clickwrap is published',
                message:
                    'These documents remain publication candidates and have not been approved by an attorney. MORT will not treat a draft as user consent.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in requirements) ...[
                  MortCard(
                    onTap: () {
                      final title = Uri.encodeQueryComponent(
                        item['title']?.toString() ?? 'Legal document',
                      );
                      final signature =
                          item['requires_electronic_signature'] == true;
                      context.push(
                        '/legal-center/version/${item['version_id']}?title=$title&signature=$signature',
                      );
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title']?.toString() ?? 'Legal document',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Version ${item['version_label']} | ${_shortHash(item['content_hash'])}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        MortBadge(
                          label: item['acceptance_id'] == null
                              ? 'Review'
                              : 'Accepted',
                          color: item['acceptance_id'] == null
                              ? MortColors.warning
                              : MortColors.neon,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: MortSpacing.lg),
        MortButton(
          label: 'Teen plain-language summary',
          icon: Icons.menu_book_outlined,
          style: MortButtonStyle.secondary,
          onPressed: () => context.push('/legal-center/teen-summary'),
        ),
        const SizedBox(height: MortSpacing.sm),
        const MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BoundaryLine('No prechecked boxes'),
              _BoundaryLine('No acceptance inferred from browsing'),
              _BoundaryLine('Material revisions require reacceptance'),
              _BoundaryLine('Guardian Mode remains optional'),
              _BoundaryLine(
                'Minor capacity and enforceability require jurisdiction-specific attorney review',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TeenTermsSummaryScreen extends StatelessWidget {
  const TeenTermsSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Plain language',
          title: 'Teen terms summary',
          subtitle:
              'This draft summary helps with understanding. It does not replace the full agreement or attorney review.',
        ),
        _SummaryCard(
          'Use MORT honestly',
          'Use your real role and age information. Do not impersonate anyone or evade account restrictions.',
        ),
        _SummaryCard(
          'Only do work that is safe for you',
          'Do not accept prohibited, sexual, illegal, hazardous, overnight, or age-inappropriate work. Leave any situation that feels unsafe.',
        ),
        _SummaryCard(
          'Protect private details',
          'Use general locations until an accepted job reaches the authorized release stage. Keep communication in MORT.',
        ),
        _SummaryCard(
          'Payment stays off-platform',
          'MORT records the agreement and status, but does not process money, hold escrow, or guarantee payment or recovery.',
        ),
        _SummaryCard(
          'Reports are not automatic guilt findings',
          'Reports stay private, evidence can be preserved, and consequential decisions require review and appeal.',
        ),
        _SummaryCard(
          'Verification signals have limits',
          'Document quality, web-image reuse, live presence, school email, and device authentication do not by themselves prove legal identity or safety.',
        ),
        _SummaryCard(
          'Guardian Mode is optional',
          'Guardian Mode is separate from any jurisdiction-specific legal requirement or closed-pilot eligibility rule.',
        ),
        MortSafetyBanner(),
      ],
    );
  }
}

class LegalClickwrapScreen extends ConsumerStatefulWidget {
  const LegalClickwrapScreen({
    super.key,
    required this.versionId,
    required this.title,
    required this.signatureRequired,
  });

  final String versionId;
  final String title;
  final bool signatureRequired;

  @override
  ConsumerState<LegalClickwrapScreen> createState() =>
      _LegalClickwrapScreenState();
}

class _LegalClickwrapScreenState extends ConsumerState<LegalClickwrapScreen> {
  final _signature = TextEditingController();
  late Future<Map<String, dynamic>> _versionFuture;
  bool _summaryViewed = false;
  bool _affirmative = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersion();
  }

  @override
  void didUpdateWidget(covariant LegalClickwrapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.versionId != widget.versionId) {
      _versionFuture = _loadVersion();
    }
  }

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadVersion() => ref
      .read(legalContractRepositoryProvider)
      .publishedLegalVersion(widget.versionId);

  void _retryVersion() {
    setState(() => _versionFuture = _loadVersion());
  }

  Future<void> _accept() async {
    if (!_summaryViewed || !_affirmative || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(legalContractRepositoryProvider)
          .acceptLegalVersion(
            versionId: widget.versionId,
            teenSummaryViewed: _summaryViewed,
            signature: _signature.text,
          );
      if (!mounted) return;
      setState(() => _affirmative = false);
      MortToast.show(
        context,
        'Acceptance recorded for the exact version and content hash.',
      );
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _summaryViewed &&
        _affirmative &&
        (!widget.signatureRequired || _signature.text.trim().length >= 3);
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Affirmative clickwrap',
          title: widget.title,
          subtitle:
              'Acceptance is never inferred from opening, scrolling, or using MORT.',
        ),
        const _LegalDraftWarning(),
        const SizedBox(height: MortSpacing.md),
        const _SummaryCard(
          'Read the teen summary first',
          'The summary highlights safety, payment, privacy, reports, verification limits, and optional Guardian Mode. The full text below still controls once legally approved and published.',
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _summaryViewed,
          title: const Text('I reviewed the teen plain-language summary first'),
          onChanged: (value) => setState(() => _summaryViewed = value == true),
        ),
        const SizedBox(height: MortSpacing.sm),
        FutureBuilder<Map<String, dynamic>>(
          future: _versionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Exact version unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry exact version',
                  icon: Icons.refresh,
                  onPressed: _retryVersion,
                ),
              );
            }
            final version = snapshot.data ?? const {};
            return MortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version ${version['version_label']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MortSpacing.xs),
                  SelectableText(
                    'SHA-256: ${version['content_hash']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: MortSpacing.lg),
                  SelectableText(version['content_markdown']?.toString() ?? ''),
                ],
              ),
            );
          },
        ),
        if (widget.signatureRequired) ...[
          const SizedBox(height: MortSpacing.md),
          MortTextField(
            label: 'Electronic signature name',
            controller: _signature,
            onChanged: (_) => setState(() {}),
          ),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _affirmative,
          title: const Text('I affirmatively agree to this exact version'),
          onChanged: (value) => setState(() => _affirmative = value == true),
        ),
        MortButton(
          label: 'Accept exact version',
          icon: Icons.verified_outlined,
          busy: _busy,
          onPressed: ready ? _accept : null,
        ),
      ],
    );
  }
}

class _LegalDraftWarning extends StatelessWidget {
  const _LegalDraftWarning();

  @override
  Widget build(BuildContext context) {
    return const MortCard(
      color: MortColors.cardAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, color: MortColors.warning),
          SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              'DRAFT — NOT ATTORNEY REVIEWED OR LEGALLY APPROVED. Public launch and enforceability require qualified legal, privacy, youth-labor, and teen-safety review.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.sm),
      child: MortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: MortSpacing.xs),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: MortColors.neon,
            size: 18,
          ),
          const SizedBox(width: MortSpacing.xs),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _shortHash(dynamic value) {
  final text = value?.toString() ?? '';
  return text.length <= 12 ? text : '${text.substring(0, 12)}...';
}
