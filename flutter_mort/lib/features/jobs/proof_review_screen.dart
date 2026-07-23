import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/proof.dart';
import '../../data/repositories/providers.dart';
import '../../data/repositories/uploads_repository.dart';

class ProofReviewScreen extends ConsumerStatefulWidget {
  const ProofReviewScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  ConsumerState<ProofReviewScreen> createState() => _ProofReviewScreenState();
}

class _ProofReviewScreenState extends ConsumerState<ProofReviewScreen> {
  final _reviewNote = TextEditingController();
  late Future<List<ProofUpload>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _reviewNote.dispose();
    super.dispose();
  }

  Future<List<ProofUpload>> _load() {
    return ref
        .read(applicationsRepositoryProvider)
        .listProofs(widget.applicationId);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _review(ProofUpload proof, String action) async {
    if (_busy) return;
    final note = _reviewNote.text.trim();
    if (action != 'approved' && note.length < 10) {
      MortToast.show(
        context,
        'Add at least 10 characters explaining what the worker should change.',
      );
      return;
    }
    final label = switch (action) {
      'approved' => 'Approve this proof?',
      'resubmission_requested' => 'Request a new proof?',
      _ => 'Reject this proof?',
    };
    final confirmed = await MortConfirmSheet.show(
      context,
      title: label,
      message: action == 'approved'
          ? 'The job can be completed after approval.'
          : 'The application will return to in progress so the teen can submit replacement proof.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .reviewProof(proof.id, action: action, note: note);
      if (!mounted) return;
      _reviewNote.clear();
      MortToast.show(
        context,
        action == 'approved'
            ? 'Proof approved.'
            : 'The worker was asked to submit a new proof.',
      );
      _reload();
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    if (_busy) return;
    final confirmed = await MortConfirmSheet.show(
      context,
      title: 'Mark this job complete?',
      message:
          'This protected action keeps approved proof in the private job record.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationsRepositoryProvider)
          .updateStatus(widget.applicationId, 'completed');
      if (mounted) context.go('/adult/applicants');
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
        MortHeader(
          eyebrow: 'Private evidence',
          title: 'Review completion proof',
          subtitle:
              'Approve the current proof or explain what needs to be resubmitted. Proof access remains limited to authorized participants.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh proof',
            onPressed: _reload,
          ),
        ),
        const MortSafetyBanner(
          message:
              'Review only the work shown. Do not download, repost, or use a teen proof image outside this job workflow.',
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<ProofUpload>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Proof unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _reload,
                ),
              );
            }
            final proofs = snapshot.data ?? const [];
            if (proofs.isEmpty) {
              return const MortEmptyState(
                title: 'No proof submitted',
                message:
                    'The accepted worker has not submitted completion evidence for this application.',
              );
            }
            return _proof(proofs.first);
          },
        ),
      ],
    );
  }

  Widget _proof(ProofUpload proof) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<String>(
          future: ref
              .read(uploadsRepositoryProvider)
              .signedUrl(UploadsRepository.proofBucket, proof.storagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AspectRatio(
                aspectRatio: 4 / 3,
                child: MortLoading(),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return MortErrorState(
                title: 'Private image unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            return Semantics(
              label: 'Private completion proof image',
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const MortEmptyState(
                      title: 'Image could not load',
                      message: 'Refresh the signed proof link and try again.',
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MortBadge(
                label: proof.statusLabel,
                color: _statusColor(proof.status),
              ),
              if (proof.note?.trim().isNotEmpty == true) ...[
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Worker note',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(proof.note!),
              ],
              if (proof.reviewNote?.trim().isNotEmpty == true) ...[
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Review note',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(proof.reviewNote!),
              ],
              const SizedBox(height: MortSpacing.sm),
              Text(
                'Submitted ${formatDateTime(proof.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        if (proof.status == 'submitted') ...[
          MortTextArea(
            label: 'Review note',
            hint: 'Required when requesting a replacement proof.',
            controller: _reviewNote,
            maxLength: 500,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Approve proof',
                icon: Icons.check_circle_outline,
                busy: _busy,
                onPressed: () => _review(proof, 'approved'),
                style: MortButtonStyle.primary,
              ),
              MortAction(
                label: 'Request new proof',
                icon: Icons.refresh,
                busy: _busy,
                onPressed: () => _review(proof, 'resubmission_requested'),
              ),
              MortAction(
                label: 'Reject proof',
                icon: Icons.cancel_outlined,
                busy: _busy,
                onPressed: () => _review(proof, 'rejected'),
                style: MortButtonStyle.danger,
              ),
            ],
          ),
        ] else if (proof.status == 'approved') ...[
          MortButton(
            label: 'Mark job complete',
            busyLabel: 'Completing...',
            busy: _busy,
            icon: Icons.task_alt,
            onPressed: _complete,
          ),
        ] else
          const MortCard(
            child: Text(
              'The application is back in progress while the teen prepares replacement proof.',
            ),
          ),
      ],
    );
  }

  static Color _statusColor(String status) => switch (status) {
    'approved' => MortColors.neon,
    'submitted' => MortColors.safetyBlue,
    _ => MortColors.warning,
  };
}
