import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/widgets/mort_widgets.dart';

/// Uses an explicitly entered, already-known number. MORT never discloses a
/// private account phone number or claims the recipient answered.
Future<void> openKnownSafetyContactCall(
  BuildContext context,
  String person,
) async {
  final number = await showDialog<String>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (_) => _KnownNumberDialog(person: person),
  );
  if (number == null || !context.mounted) return;
  try {
    final opened = await launchUrl(Uri(scheme: 'tel', path: number));
    if (context.mounted)
      MortToast.show(
        context,
        opened
            ? 'Phone call opened. Connection to the person is not confirmed.'
            : 'Open your Phone app to call this person.',
      );
  } catch (_) {
    if (context.mounted)
      MortToast.show(context, 'Open your Phone app to call this person.');
  }
}

class _KnownNumberDialog extends StatefulWidget {
  const _KnownNumberDialog({required this.person});
  final String person;
  @override
  State<_KnownNumberDialog> createState() => _KnownNumberDialogState();
}

class _KnownNumberDialogState extends State<_KnownNumberDialog> {
  final _number = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Call ${widget.person}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Use a phone number you already know and have confirmed for this person. MORT does not have a verified number available here. The number is not saved.',
          ),
          TextField(
            controller: _number,
            keyboardType: TextInputType.phone,
            maxLength: 25,
            decoration: InputDecoration(
              labelText: 'Known phone number',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _number.text.replaceAll(RegExp(r'[\s()\-]'), '');
          if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(value)) {
            setState(() => _error = 'Enter a complete phone number.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Open Phone Call'),
      ),
    ],
  );
}
