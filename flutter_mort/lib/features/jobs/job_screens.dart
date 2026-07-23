import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';

const safeJobCategories = [
  'cleaning',
  'lawn care',
  'dog walking',
  'pet care',
  'snow removal',
  'trash and recycling',
  'moving/light lifting',
  'tutoring',
  'technology help',
  'organization',
  'errands',
  'event setup',
  'car washing',
  'painting/light maintenance',
  'delivery where legally appropriate',
  'other safe local work',
];

class JobCreationScreen extends ConsumerStatefulWidget {
  const JobCreationScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<JobCreationScreen> createState() => _JobCreationScreenState();
}

class _JobCreationScreenState extends ConsumerState<JobCreationScreen> {
  final _draft = JobDraft(clientRequestId: const Uuid().v4());
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _workers = TextEditingController(text: '1');
  final _skills = TextEditingController();
  final _equipmentProvided = TextEditingController();
  final _equipmentBrings = TextEditingController();
  final _instructions = TextEditingController();
  final _recurrenceRule = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _neighborhood = TextEditingController();
  final _zip = TextEditingController();
  final _radius = TextEditingController();
  final _pay = TextEditingController();
  final _safetyNotes = TextEditingController();
  int _step = 0;
  bool _busy = false;
  bool _loaded = false;
  bool _prohibitedConfirmed = false;
  String _category = safeJobCategories.first;
  String _experience = 'any';
  String _scheduleType = 'flexible';
  String _urgency = 'normal';
  String _timezone = 'America/Indianapolis';
  String _environment = 'unspecified';
  String _locationType = 'unspecified';
  String _paymentType = 'fixed';
  String _paymentMethod = 'flexible';
  String _paymentTiming = 'after_completion';
  String _verification = 'none';
  bool _proofExpected = false;
  bool _recurring = false;
  bool _tipAllowed = false;
  bool _adultSupervision = false;
  bool _guardianApproval = false;
  int _teenMinAge = 13;
  final Set<String> _physicalRequirements = {};
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _deadlineAt;

  static const _stepTitles = [
    'Job basics',
    'Work details',
    'Schedule',
    'Location and travel',
    'Payment',
    'Safety and requirements',
    'Preview',
    'Publish',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadJob());
    }
  }

  Future<void> _loadJob() async {
    final job = await ref.read(jobsRepositoryProvider).getJob(widget.jobId!);
    if (!mounted || job == null) return;
    _draft.id = job.id;
    _title.text = job.title == 'Untitled draft' ? '' : job.title;
    _summary.text = job.summary ?? '';
    _description.text = job.description == 'Draft details not completed.'
        ? ''
        : job.description;
    _category = job.category;
    _duration.text = job.estimatedDurationMinutes?.toString() ?? '';
    _workers.text = job.workersNeeded.toString();
    _experience = job.experienceLevel;
    _skills.text = job.skillsNeeded.join(', ');
    _equipmentProvided.text = job.equipmentProvided ?? '';
    _equipmentBrings.text = job.equipmentWorkerBrings ?? '';
    _instructions.text = job.specialInstructions ?? '';
    _proofExpected = job.proofExpected;
    _scheduleType = job.scheduleType;
    _startsAt = job.startsAt;
    _endsAt = job.endsAt;
    _deadlineAt = job.deadlineAt;
    _recurring = job.recurring;
    _recurrenceRule.text = job.recurrenceRule ?? '';
    _urgency = job.urgency;
    _timezone = job.timezone;
    _area.text = job.locationText;
    _city.text = job.city;
    _state.text = job.state;
    _neighborhood.text = job.neighborhood ?? '';
    _zip.text = job.zipCode ?? '';
    _radius.text = job.travelRadiusMiles?.toString() ?? '';
    _environment = job.workEnvironment;
    _locationType = job.locationType;
    _pay.text = job.payAmountCents == null
        ? ''
        : (job.payAmountCents! / 100).toStringAsFixed(2);
    _paymentType = job.paymentType;
    _paymentMethod = job.paymentMethod;
    _paymentTiming = job.paymentTiming;
    _tipAllowed = job.tipAllowed;
    _adultSupervision = job.adultSupervisionPresent;
    _verification = job.verificationRequirement;
    _guardianApproval = job.requiresGuardianApproval;
    _teenMinAge = job.teenMinAge;
    _physicalRequirements
      ..clear()
      ..addAll(job.physicalRequirements);
    _safetyNotes.text = job.safetyNotes ?? '';
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _description,
      _duration,
      _workers,
      _skills,
      _equipmentProvided,
      _equipmentBrings,
      _instructions,
      _recurrenceRule,
      _area,
      _city,
      _state,
      _neighborhood,
      _zip,
      _radius,
      _pay,
      _safetyNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncDraft() {
    _draft
      ..title = _title.text.trim()
      ..summary = _summary.text.trim()
      ..description = _description.text.trim()
      ..category = _category
      ..estimatedDurationMinutes = int.tryParse(_duration.text)
      ..workersNeeded = int.tryParse(_workers.text) ?? 1
      ..experienceLevel = _experience
      ..skillsNeeded = _commaList(_skills.text)
      ..equipmentProvided = _equipmentProvided.text.trim()
      ..equipmentWorkerBrings = _equipmentBrings.text.trim()
      ..physicalRequirements = _physicalRequirements.toList()
      ..proofExpected = _proofExpected
      ..specialInstructions = _instructions.text.trim()
      ..scheduleType = _scheduleType
      ..startsAt = _startsAt
      ..endsAt = _endsAt
      ..deadlineAt = _deadlineAt
      ..recurring = _recurring
      ..recurrenceRule = _recurrenceRule.text.trim()
      ..timezone = _timezone
      ..urgency = _urgency
      ..locationText = _area.text.trim()
      ..city = _city.text.trim()
      ..state = _state.text.trim().toUpperCase()
      ..neighborhood = _neighborhood.text.trim()
      ..zipCode = _zip.text.trim()
      ..travelRadiusMiles = int.tryParse(_radius.text)
      ..workEnvironment = _environment
      ..locationType = _locationType
      ..payAmountCents = MortValidators.dollarsToCents(_pay.text)
      ..paymentType = _paymentType
      ..paymentMethod = _paymentMethod
      ..paymentTiming = _paymentTiming
      ..tipAllowed = _tipAllowed
      ..adultSupervisionPresent = _adultSupervision
      ..teenMinAge = _teenMinAge
      ..teenMaxAge = 17
      ..verificationRequirement = _verification
      ..requiresGuardianApproval = _guardianApproval
      ..safetyNotes = _safetyNotes.text.trim();
  }

  List<String> _commaList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(12)
      .toList();

  String? _validateStep() {
    if (_step == 0) {
      if (_title.text.trim().length < 5 || _title.text.trim().length > 80) {
        return 'Use a clear title between 5 and 80 characters.';
      }
      if (_summary.text.trim().length < 10 ||
          _summary.text.trim().length > 240) {
        return 'Add a short summary between 10 and 240 characters.';
      }
      if (_description.text.trim().length < 20) {
        return 'Add at least 20 characters of job detail.';
      }
      return MortValidators.teenSafeJobText(
        '${_title.text}\n${_summary.text}\n${_description.text}',
      );
    }
    if (_step == 1) {
      final duration = int.tryParse(_duration.text);
      if (duration == null || duration < 15 || duration > 1440) {
        return 'Estimated duration must be between 15 and 1,440 minutes.';
      }
      final workers = int.tryParse(_workers.text);
      if (workers == null || workers < 1 || workers > 10) {
        return 'Workers needed must be between 1 and 10.';
      }
    }
    if (_step == 2 && _scheduleType == 'exact') {
      if (_startsAt == null || !_startsAt!.isAfter(DateTime.now())) {
        return 'Choose a future start date and time.';
      }
      if (_endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
        return 'End time must be after the start time.';
      }
    }
    if (_step == 2 && _recurring && _recurrenceRule.text.trim().length < 3) {
      return 'Describe the recurring schedule, such as weekly on Saturday.';
    }
    if (_step == 3) {
      if (_area.text.trim().isEmpty || _city.text.trim().isEmpty) {
        return 'Add a general area and city.';
      }
      if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(_state.text.trim())) {
        return 'Use a two-letter state code.';
      }
    }
    if (_step == 4 && (MortValidators.dollarsToCents(_pay.text) ?? 0) <= 0) {
      return 'Enter a positive payment amount.';
    }
    if (_step == 5 && !_prohibitedConfirmed) {
      return 'Confirm that the job does not include prohibited work or upfront fees.';
    }
    return null;
  }

  Future<void> _save({required bool publish}) async {
    if (_busy) return;
    if (publish) {
      final original = _step;
      for (var step = 0; step <= 5; step++) {
        _step = step;
        final error = _validateStep();
        if (error != null) {
          _step = step;
          setState(() {});
          MortToast.show(context, error);
          return;
        }
      }
      _step = original;
    }
    _syncDraft();
    setState(() => _busy = true);
    try {
      final job = publish
          ? await ref.read(jobsRepositoryProvider).publish(_draft)
          : await ref.read(jobsRepositoryProvider).saveDraft(_draft);
      if (!mounted) return;
      MortToast.show(context, publish ? 'Job published.' : 'Draft saved.');
      if (publish) {
        context.go('/adult/jobs/${job.id}');
      } else {
        setState(() {});
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    final error = _validateStep();
    if (error != null) {
      MortToast.show(context, error);
      return;
    }
    _syncDraft();
    setState(() => _step = (_step + 1).clamp(0, 7));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobId != null && !_loaded && _draft.id == null) {
      return const MortLoading(label: 'Loading job draft');
    }
    return MortScreen(
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          MortSpacing.md,
          MortSpacing.xs,
          MortSpacing.md,
          MortSpacing.md,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: MortColors.bg),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: MortButton(
                    label: 'Back',
                    icon: Icons.arrow_back,
                    style: MortButtonStyle.ghost,
                    onPressed: () => setState(() => _step--),
                  ),
                ),
              if (_step > 0) const SizedBox(width: MortSpacing.sm),
              Expanded(
                child: MortButton(
                  label: _step == 7 ? 'Publish job' : 'Continue',
                  icon: _step == 7 ? Icons.publish : Icons.arrow_forward,
                  busy: _busy,
                  busyLabel: _step == 7 ? 'Publishing...' : 'Saving...',
                  onPressed: _step == 7 ? () => _save(publish: true) : _next,
                ),
              ),
            ],
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        MortSpacing.md,
        MortSpacing.md,
        MortSpacing.md,
        140,
      ),
      children: [
        MortHeader(
          eyebrow: 'Step ${_step + 1} of 8',
          title: _stepTitles[_step],
          subtitle:
              'Create a job listing. Exact addresses and private contact details do not belong in public fields.',
        ),
        MortStepper(current: _step, total: 8),
        const SizedBox(height: MortSpacing.md),
        _buildStep(),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save as draft',
          icon: Icons.save_outlined,
          style: MortButtonStyle.secondary,
          busy: _busy,
          onPressed: () => _save(publish: false),
        ),
      ],
    );
  }

  Widget _buildStep() => switch (_step) {
    0 => _basics(),
    1 => _workDetails(),
    2 => _schedule(),
    3 => _location(),
    4 => _payment(),
    5 => _safety(),
    6 => _preview(),
    _ => _publish(),
  };

  Widget _basics() => Column(
    children: [
      MortTextField(label: 'Title', controller: _title, maxLength: 80),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Category',
        value: _category,
        items: {for (final value in safeJobCategories) value: value},
        onChanged: (value) => setState(() => _category = value ?? _category),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Short summary',
        controller: _summary,
        maxLines: 2,
        maxLength: 240,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Detailed description',
        controller: _description,
        maxLength: 4000,
        hint: 'Explain the work, expected result, and safe boundaries.',
      ),
    ],
  );

  Widget _workDetails() => Column(
    children: [
      MortTextField(
        label: 'Estimated duration (minutes)',
        controller: _duration,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Workers needed',
        controller: _workers,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Experience level',
        value: _experience,
        items: const {
          'any': 'Any experience',
          'beginner': 'Beginner',
          'some': 'Some experience',
          'experienced': 'Experienced',
        },
        onChanged: (value) => setState(() => _experience = value ?? 'any'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Skills needed',
        controller: _skills,
        hint: 'Separate skills with commas',
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(label: 'Equipment provided', controller: _equipmentProvided),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Equipment worker should bring',
        controller: _equipmentBrings,
      ),
      const SizedBox(height: MortSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Physical requirements',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: MortSpacing.xs),
      Wrap(
        spacing: MortSpacing.xs,
        runSpacing: MortSpacing.xs,
        children: [
          for (final requirement in const [
            'light lifting',
            'standing',
            'outdoor work',
            'stairs',
            'bending',
            'no physical requirement',
          ])
            FilterChip(
              label: Text(requirement),
              selected: _physicalRequirements.contains(requirement),
              onSelected: (selected) => setState(() {
                if (requirement == 'no physical requirement' && selected) {
                  _physicalRequirements
                    ..clear()
                    ..add(requirement);
                } else {
                  _physicalRequirements.remove('no physical requirement');
                  if (selected) {
                    _physicalRequirements.add(requirement);
                  } else {
                    _physicalRequirements.remove(requirement);
                  }
                }
              }),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _proofExpected,
        title: const Text('Proof expected'),
        subtitle: const Text(
          'Explain what a safe completion photo should show.',
        ),
        onChanged: (value) => setState(() => _proofExpected = value),
      ),
      MortTextArea(
        label: 'Special instructions',
        controller: _instructions,
        maxLength: 1000,
      ),
    ],
  );

  Widget _schedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MortDropdown<String>(
        label: 'Schedule type',
        value: _scheduleType,
        items: const {
          'flexible': 'Flexible schedule',
          'exact': 'Exact date and time',
        },
        onChanged: (value) =>
            setState(() => _scheduleType = value ?? 'flexible'),
      ),
      if (_scheduleType == 'exact') ...[
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: _startsAt == null
              ? 'Choose start'
              : 'Starts ${formatDateTime(_startsAt)}',
          icon: Icons.event,
          onPressed: () => _pickDateTime(start: true),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: _endsAt == null
              ? 'Choose estimated end'
              : 'Ends ${formatDateTime(_endsAt)}',
          icon: Icons.schedule,
          style: MortButtonStyle.secondary,
          onPressed: () => _pickDateTime(start: false),
        ),
      ],
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _recurring,
        title: const Text('Recurring job'),
        subtitle: const Text('Recurring details must still use future dates.'),
        onChanged: (value) => setState(() => _recurring = value),
      ),
      if (_recurring) ...[
        MortTextField(
          label: 'Recurring schedule',
          controller: _recurrenceRule,
          hint: 'For example, weekly on Saturday morning',
          maxLength: 240,
        ),
        const SizedBox(height: MortSpacing.sm),
      ],
      MortDropdown<String>(
        label: 'Urgency',
        value: _urgency,
        items: const {'low': 'Low', 'normal': 'Normal', 'soon': 'Soon'},
        onChanged: (value) => setState(() => _urgency = value ?? 'normal'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Timezone',
        value: _timezone,
        items: const {
          'America/New_York': 'Eastern',
          'America/Chicago': 'Central',
          'America/Denver': 'Mountain',
          'America/Los_Angeles': 'Pacific',
          'America/Phoenix': 'Arizona',
          'America/Indianapolis': 'Indiana (Indianapolis)',
        },
        onChanged: (value) =>
            setState(() => _timezone = value ?? 'America/Indianapolis'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortButton(
        label: _deadlineAt == null
            ? 'Add deadline (optional)'
            : 'Deadline ${formatDateTime(_deadlineAt)}',
        icon: Icons.timer_outlined,
        style: MortButtonStyle.ghost,
        onPressed: _pickDeadline,
      ),
    ],
  );

  Widget _location() => Column(
    children: [
      MortTextField(
        label: 'Approximate area',
        controller: _area,
        hint: 'North side, downtown, or nearby landmark area',
      ),
      const SizedBox(height: MortSpacing.sm),
      Row(
        children: [
          Expanded(
            child: MortTextField(label: 'City', controller: _city),
          ),
          const SizedBox(width: MortSpacing.sm),
          SizedBox(
            width: 100,
            child: MortTextField(
              label: 'State',
              controller: _state,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
            ),
          ),
        ],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Neighborhood (optional)',
        controller: _neighborhood,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'ZIP code (optional)',
        controller: _zip,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Travel radius miles (optional)',
        controller: _radius,
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Work environment',
        value: _environment,
        items: const {
          'unspecified': 'Not specified',
          'indoor': 'Indoor',
          'outdoor': 'Outdoor',
          'both': 'Indoor and outdoor',
        },
        onChanged: (value) =>
            setState(() => _environment = value ?? 'unspecified'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Location type',
        value: _locationType,
        items: const {
          'unspecified': 'Not specified',
          'public': 'Public location',
          'private_residence': 'Private residence',
          'business': 'Business',
        },
        onChanged: (value) =>
            setState(() => _locationType = value ?? 'unspecified'),
      ),
      const SizedBox(height: MortSpacing.sm),
      const MortSafetyBanner(
        message:
            'Only the approximate area appears publicly. Do not put a street address, access code, or teen location in these fields.',
      ),
    ],
  );

  Widget _payment() => Column(
    children: [
      MortTextField(
        label: 'Payment amount dollars',
        controller: _pay,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Payment type',
        value: _paymentType,
        items: const {'fixed': 'Fixed amount', 'hourly': 'Hourly'},
        onChanged: (value) => setState(() => _paymentType = value ?? 'fixed'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'Payment method preference',
        value: _paymentMethod,
        items: const {
          'cash': 'Cash',
          'cash_app': 'Cash App',
          'square': 'Square invoice or link',
          'flexible': 'Flexible / agree later',
        },
        onChanged: (value) =>
            setState(() => _paymentMethod = value ?? 'flexible'),
      ),
      const SizedBox(height: MortSpacing.sm),
      MortDropdown<String>(
        label: 'When payment is expected',
        value: _paymentTiming,
        items: const {
          'after_completion': 'After completion',
          'same_day': 'Same day',
          'agreed_later': 'Agree later',
        },
        onChanged: (value) =>
            setState(() => _paymentTiming = value ?? 'after_completion'),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _tipAllowed,
        title: const Text('Optional tip allowed'),
        onChanged: (value) => setState(() => _tipAllowed = value),
      ),
      const MortPaymentDisclaimer(),
    ],
  );

  Widget _safety() => Column(
    children: [
      MortDropdown<int>(
        label: 'Minimum recommended age',
        value: _teenMinAge,
        items: const {13: '13+', 14: '14+', 15: '15+', 16: '16+', 17: '17'},
        onChanged: (value) => setState(() => _teenMinAge = value ?? 13),
      ),
      const SizedBox(height: MortSpacing.sm),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _adultSupervision,
        title: const Text('Adult supervision present'),
        onChanged: (value) => setState(() => _adultSupervision = value),
      ),
      MortDropdown<String>(
        label: 'Applicant verification',
        value: _verification,
        items: const {
          'none': 'No additional requirement',
          'preferred': 'Verified applicants preferred',
          'required': 'Verified applicants required',
        },
        onChanged: (value) => setState(() => _verification = value ?? 'none'),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _guardianApproval,
        title: const Text('Request guardian approval for this job'),
        subtitle: const Text(
          'Optional. Turning this on may reduce the number of eligible applicants.',
        ),
        onChanged: (value) => setState(() => _guardianApproval = value),
      ),
      MortTextArea(
        label: 'Safety notes',
        controller: _safetyNotes,
        maxLength: 1000,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _prohibitedConfirmed,
        onChanged: (value) =>
            setState(() => _prohibitedConfirmed = value ?? false),
        title: const Text(
          'I confirm this job has no dangerous heights, weapons, hazardous chemicals, illegal activity, alcohol/drug handling, overnight isolation, upfront fee, gift card, or cryptocurrency demand.',
        ),
      ),
    ],
  );

  Widget _preview() {
    _syncDraft();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MortBadge(label: _draft.category),
              const SizedBox(height: MortSpacing.sm),
              Text(
                _draft.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${formatCents(_draft.payAmountCents)} · ${_draft.locationText}',
              ),
              const SizedBox(height: MortSpacing.sm),
              Text(_draft.summary),
              const SizedBox(height: MortSpacing.sm),
              MortBadge(
                label: _draft.scheduleType == 'flexible'
                    ? 'Flexible schedule'
                    : formatDateTime(_draft.startsAt),
              ),
              if (_draft.requiresGuardianApproval)
                const Padding(
                  padding: EdgeInsets.only(top: MortSpacing.xs),
                  child: MortBadge(
                    label: 'Poster requested guardian approval',
                    color: MortColors.safetyBlue,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(child: Text(_draft.description)),
        const SizedBox(height: MortSpacing.md),
        const MortPaymentDisclaimer(),
      ],
    );
  }

  Widget _publish() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const MortSafetyBanner(
        message:
            'MORT will validate every section, run the server safety rules, enforce the posting limit, and publish one idempotent job record.',
      ),
      const SizedBox(height: MortSpacing.md),
      _JobChecklist(
        items: [
          'Title: ${_title.text.trim()}',
          'Category: $_category',
          'Schedule: ${_scheduleType == 'flexible' ? 'Flexible schedule' : formatDateTime(_startsAt)}',
          'Approximate location: ${_area.text.trim()}, ${_city.text.trim()}, ${_state.text.trim().toUpperCase()}',
          'Guardian approval: ${_guardianApproval ? 'Requested for this job' : 'Not required'}',
          'Payment: ${formatCents(MortValidators.dollarsToCents(_pay.text))}',
        ],
      ),
    ],
  );

  Future<void> _pickDateTime({required bool start}) async {
    final now = DateTime.now();
    final current =
        (start ? _startsAt : _endsAt) ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: current.isBefore(now) ? now : current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = value;
      } else {
        _endsAt = value;
      }
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _deadlineAt ?? now.add(const Duration(days: 7)),
    );
    if (date != null) setState(() => _deadlineAt = date);
  }
}

class AdultJobsScreen extends ConsumerWidget {
  const AdultJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Adult jobs',
          title: 'Manage jobs',
          subtitle:
              'Drafts, open jobs, assignments, proof, and completion use tracked workflow states.',
        ),
        const MortActionRow(
          actions: [
            MortAction(
              label: 'Create job',
              icon: Icons.add,
              route: '/adult/post-job',
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        FutureBuilder<List<Job>>(
          future: ref.watch(jobsRepositoryProvider).listMyJobs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MortSkeletonCard();
            }
            if (snapshot.hasError) {
              return MortErrorState(
                title: 'Jobs unavailable',
                message: userFacingError(snapshot.error),
              );
            }
            final jobs = snapshot.data ?? const [];
            if (jobs.isEmpty) {
              return const MortEmptyState(
                title: 'No jobs yet',
                message:
                    'Create a draft, preview it, then publish when it is ready.',
              );
            }
            return Column(
              children: [
                for (final job in jobs) ...[
                  MortCard(
                    onTap: () => context.go('/adult/jobs/${job.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text('${job.payDisplay} · ${job.scheduleDisplay}'),
                        const SizedBox(height: MortSpacing.sm),
                        MortJobStatusBadge(status: job.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdultJobManagementScreen extends ConsumerStatefulWidget {
  const AdultJobManagementScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<AdultJobManagementScreen> createState() =>
      _AdultJobManagementScreenState();
}

class _AdultJobManagementScreenState
    extends ConsumerState<AdultJobManagementScreen> {
  bool _busy = false;

  Future<void> _action(String action) async {
    if (_busy) return;
    if (action == 'cancel' || action == 'delete_draft') {
      final confirmed = await MortConfirmSheet.show(
        context,
        title: action == 'cancel' ? 'Cancel this job?' : 'Delete this draft?',
        message: action == 'cancel'
            ? 'Applications will close and the job will remain in your history.'
            : 'This draft has no applicants and will be permanently deleted.',
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(jobsRepositoryProvider)
          .manageJob(widget.jobId, action);
      if (!mounted) return;
      if (action == 'delete_draft') {
        context.go('/adult/jobs');
      } else if (action == 'duplicate' && result != null) {
        context.go('/adult/jobs/${result.id}/edit');
      } else {
        MortToast.show(context, 'Job updated.');
        setState(() {});
      }
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Job?>(
      future: ref.watch(jobsRepositoryProvider).getJob(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MortLoading();
        }
        if (snapshot.hasError || snapshot.data == null) {
          return MortScreen(
            children: [
              MortErrorState(
                title: 'Job unavailable',
                message: userFacingError(snapshot.error),
              ),
            ],
          );
        }
        final job = snapshot.data!;
        return MortScreen(
          children: [
            MortHeader(
              eyebrow: job.category,
              title: job.title,
              subtitle: '${job.payDisplay} · ${job.scheduleDisplay}',
            ),
            MortJobStatusBadge(status: job.status),
            const SizedBox(height: MortSpacing.md),
            MortActionRow(
              actions: [
                if (job.status == 'draft' ||
                    job.status == 'open' ||
                    job.status == 'paused')
                  MortAction(
                    label: 'Edit',
                    icon: Icons.edit,
                    route: '/adult/jobs/${job.id}/edit',
                  ),
                if (job.status == 'open')
                  MortAction(
                    label: 'Pause',
                    icon: Icons.pause,
                    busy: _busy,
                    onPressed: () => _action('pause'),
                  ),
                if (job.status == 'paused')
                  MortAction(
                    label: 'Resume',
                    icon: Icons.play_arrow,
                    busy: _busy,
                    onPressed: () => _action('resume'),
                  ),
                if (job.status == 'open')
                  MortAction(
                    label: 'Close applications',
                    icon: Icons.lock,
                    busy: _busy,
                    onPressed: () => _action('close_applications'),
                  ),
                MortAction(
                  label: 'Duplicate',
                  icon: Icons.copy,
                  busy: _busy,
                  onPressed: () => _action('duplicate'),
                ),
                if (job.status == 'draft')
                  MortAction(
                    label: 'Delete draft',
                    icon: Icons.delete,
                    busy: _busy,
                    onPressed: () => _action('delete_draft'),
                    style: MortButtonStyle.danger,
                  ),
                if ([
                  'open',
                  'paused',
                  'assigned',
                  'in_progress',
                ].contains(job.status))
                  MortAction(
                    label: 'Cancel job',
                    icon: Icons.cancel,
                    busy: _busy,
                    onPressed: () => _action('cancel'),
                    style: MortButtonStyle.danger,
                  ),
                const MortAction(
                  label: 'Applicants',
                  icon: Icons.groups,
                  route: '/adult/applicants',
                ),
              ],
            ),
            const SizedBox(height: MortSpacing.md),
            MortCard(child: Text(job.description)),
            const SizedBox(height: MortSpacing.md),
            const MortPaymentDisclaimer(),
          ],
        );
      },
    );
  }
}

class _JobChecklist extends StatelessWidget {
  const _JobChecklist({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MortSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SavedJobsScreen extends ConsumerWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Saved jobs',
          title: 'Jobs to revisit',
          subtitle:
              'Saved jobs stay with your account and show their current availability.',
        ),
        FutureBuilder<List<Job>>(
          future: ref.watch(jobsRepositoryProvider).listSavedJobs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const MortSkeletonCard();
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Saved jobs unavailable',
                message: userFacingError(snapshot.error),
              );
            final jobs = snapshot.data ?? const [];
            if (jobs.isEmpty)
              return const MortEmptyState(
                title: 'No saved jobs',
                message: 'Save a job from its detail screen to find it here.',
              );
            return Column(
              children: [
                for (final job in jobs) ...[
                  MortCard(
                    onTap: () => context.go('/teen/jobs/${job.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('${job.payDisplay} · ${job.scheduleDisplay}'),
                        const SizedBox(height: MortSpacing.sm),
                        MortJobStatusBadge(status: job.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
