import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';

/// Pre-account suggestion only. Staff must independently verify and list a
/// school and its student domain before any teen can use it for registration.
class SchoolDirectoryRequestScreen extends ConsumerStatefulWidget {
  const SchoolDirectoryRequestScreen({super.key, this.initialSchoolName = ''});

  final String initialSchoolName;

  @override
  ConsumerState<SchoolDirectoryRequestScreen> createState() =>
      _SchoolDirectoryRequestScreenState();
}

class _SchoolDirectoryRequestScreenState
    extends ConsumerState<SchoolDirectoryRequestScreen> {
  late final _name = TextEditingController(text: widget.initialSchoolName);
  final _city = TextEditingController();
  final _state = TextEditingController(text: 'IN');
  final _website = TextEditingController();
  final _domain = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _state.dispose();
    _website.dispose();
    _domain.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _submitted) return;
    if (_name.text.trim().length < 3 ||
        _city.text.trim().length < 2 ||
        _state.text.trim().length != 2) {
      setState(
        () => _error = 'Enter the school name, city, and two-letter state.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(schoolDirectoryRepositoryProvider)
          .requestSchool(
            schoolName: _name.text,
            city: _city.text,
            state: _state.text,
            website: _website.text,
            studentDomain: _domain.text,
          );
      if (!mounted) return;
      if (result['ok'] == true) {
        setState(() => _submitted = true);
      } else {
        setState(
          () => _error = switch (result['code']) {
            'school_already_listed' =>
              'This school is already listed. Go back and search for it.',
            'rate_limited' =>
              'School requests are busy right now. Please try again later.',
            _ => 'Check the school details and try again.',
          },
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          title: 'Request your school',
          subtitle:
              'Help MORT review a school that is missing from the directory.',
          showBackButton: true,
        ),
        if (_submitted) ...[
          const MortCard(
            child: Text(
              'Request received. MORT must verify and list the school and approve its student email domain before a teen account can be created. Please check again later.',
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Back to schools',
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ] else ...[
          MortTextField(label: 'School name', controller: _name),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(label: 'City', controller: _city),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(
            label: 'State',
            controller: _state,
            maxLength: 2,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(
            label: 'School website (optional)',
            controller: _website,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(
            label: 'Student email domain (optional)',
            hint: 'Example: students.school.org — do not enter your email',
            controller: _domain,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: MortSpacing.md),
          const Text(
            'A request does not approve a school or student email domain. Teen signup stays unavailable until MORT completes its review.',
          ),
          if (_error != null) ...[
            const SizedBox(height: MortSpacing.sm),
            Semantics(liveRegion: true, child: MortCard(child: Text(_error!))),
          ],
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Submit school request',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
      ],
    );
  }
}
