import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import 'dart:async';
import 'dart:typed_data';

Future<String?> requestSafetyReviewReason(BuildContext context, String title) =>
    showDialog<String>(
      context: context,
      builder: (_) => _SafetyReviewReasonDialog(title: title),
    );

class _SafetyReviewReasonDialog extends StatefulWidget {
  const _SafetyReviewReasonDialog({required this.title});
  final String title;
  @override
  State<_SafetyReviewReasonDialog> createState() =>
      _SafetyReviewReasonDialogState();
}

class _SafetyReviewReasonDialogState extends State<_SafetyReviewReasonDialog> {
  final text = TextEditingController();
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: text,
      maxLength: 500,
      minLines: 3,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: 'Required review reason (private audit)',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (text.text.trim().length < 10) {
            setState(() => error = 'Enter at least 10 characters.');
            return;
          }
          Navigator.pop(context, text.text.trim());
        },
        child: const Text('Continue'),
      ),
    ],
  );
}

class StaffSafetyContextButton extends ConsumerWidget {
  const StaffSafetyContextButton({super.key, required this.incidentId});
  final String incidentId;
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final reason = await requestSafetyReviewReason(
      context,
      'Open restricted Safety context?',
    );
    if (reason == null || !context.mounted) return;
    try {
      final data = await ref
          .read(safetyRepositoryProvider)
          .getStaffSafetyContext(incidentId, reason);
      final evidence = await ref
          .read(safetyRepositoryProvider)
          .staffEvidenceManifest(incidentId);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Authorized Safety context'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Exit: ${data['safety_exit'] == true ? 'Yes' : 'No'}',
                ),
                Text(
                  'Review hold: ${data['review_hold'] == true ? 'Yes' : 'No'}',
                ),
                Text('Device state: ${data['safety_state'] ?? 'unavailable'}'),
                Text(
                  'Last battery: ${data['battery_percent'] ?? 'unavailable'}',
                ),
                Text(
                  'Last connection: ${data['last_seen_at'] ?? 'unavailable'}',
                ),
                Text(
                  'Last check-in: ${data['last_checkin_at'] ?? 'unavailable'}',
                ),
                Text(
                  'Evidence count: ${data['evidence_count'] ?? 'unavailable'}',
                ),
                for (final row in evidence)
                  TextButton(
                    onPressed:
                        row['content_type'] == 'image/jpeg' &&
                            (row['byte_size'] as num? ?? 0) <= 10 * 1024 * 1024
                        ? () => _viewEvidence(
                            context,
                            ref,
                            row['evidence_id'].toString(),
                          )
                        : null,
                    child: Text(
                      'Review ${row['evidence_type']} (${row['evidence_status']})',
                    ),
                  ),
                const Text(
                  'Access was recorded with your reason. Location and unrelated message history are not returned.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (context.mounted)
        MortToast.show(
          context,
          'Safety context unavailable for this case or staff role.',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MortButton(
    label: 'Open Audited Safety Context',
    style: MortButtonStyle.secondary,
    onPressed: () => _open(context, ref),
  );

  Future<void> _viewEvidence(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final reason = await requestSafetyReviewReason(
      context,
      'Review private evidence?',
    );
    if (reason == null || !context.mounted) return;
    try {
      final bytes = await ref
          .read(safetyRepositoryProvider)
          .staffEvidenceImage(id, reason);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _PrivateEvidencePreview(bytes: bytes),
      );
    } catch (_) {
      if (context.mounted)
        MortToast.show(
          context,
          'Evidence access unavailable. No public link was created.',
        );
    }
  }
}

class _PrivateEvidencePreview extends StatefulWidget {
  const _PrivateEvidencePreview({required this.bytes});
  final Uint8List bytes;
  @override
  State<_PrivateEvidencePreview> createState() =>
      _PrivateEvidencePreviewState();
}

class _PrivateEvidencePreviewState extends State<_PrivateEvidencePreview> {
  late final ImageProvider _image = ResizeImage(
    MemoryImage(widget.bytes),
    width: 1600,
  );
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    _expiry = Timer(const Duration(seconds: 60), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    unawaited(_image.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Private evidence — audited access'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Preview closes after one minute. Handle only within your authorized case.',
          ),
          Image(
            image: _image,
            errorBuilder: (_, _, _) =>
                const Text('Evidence could not be decoded.'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
