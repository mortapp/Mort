import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

/// Evidence is added after a report is recorded; upload failure cannot delete
/// the report. The existing repository validates and strips image metadata.
class SafetyEvidenceButton extends ConsumerStatefulWidget {
  const SafetyEvidenceButton({super.key, required this.incidentId});
  final String incidentId;
  @override
  ConsumerState<SafetyEvidenceButton> createState() =>
      _SafetyEvidenceButtonState();
}

class _SafetyEvidenceButtonState extends ConsumerState<SafetyEvidenceButton> {
  bool _busy = false;
  Future<void> _upload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      if (await image.length() > 10 * 1024 * 1024)
        throw StateError('Image too large');
      final bytes = await image.readAsBytes();
      await ref
          .read(trustSafetyRepositoryProvider)
          .uploadIncidentEvidence(
            incidentId: widget.incidentId,
            evidenceType: 'Photo or screenshot supplied by reporter',
            sourceBytes: bytes,
          );
      if (mounted)
        MortToast.show(
          context,
          'Private evidence recorded for review. It was not shared with the poster.',
        );
    } catch (_) {
      if (mounted)
        MortToast.show(
          context,
          'Evidence upload not confirmed. Your report is still saved. Try a JPEG, PNG or WebP image under 10 MB, or add evidence later.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MortButton(
    label: 'Add Photo or Screenshot (optional)',
    style: MortButtonStyle.secondary,
    busy: _busy,
    onPressed: _busy ? null : _upload,
  );
}
