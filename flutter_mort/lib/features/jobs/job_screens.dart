import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import '../../core/errors/user_facing_error.dart';
import '../../core/money/mort_service_fee.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/job.dart';
import '../../data/repositories/providers.dart';
import '../../data/services/supabase_service.dart';
import '../../services/precise_location_service.dart';
import '../location/precise_location_gate.dart';
import 'job_creation_flow.dart';

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

class _JobCreationScreenState extends ConsumerState<JobCreationScreen>
    with WidgetsBindingObserver {
  JobDraft _draft = JobDraft(clientRequestId: const Uuid().v4());
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
  final _transportationNotes = TextEditingController();
  final _pay = TextEditingController();
  final _safetyNotes = TextEditingController();
  final _fieldErrors = <String, String>{};
  final _focusNodes = <String, FocusNode>{
    for (final field in [
      'title',
      'summary',
      'description',
      'estimated_duration_minutes',
      'workers_needed',
      'special_instructions',
      'location_text',
      'city',
      'state',
      'zip_code',
      'travel_radius_miles',
      'transportation_considerations',
      'adult_job_amount_cents',
      'safety_notes',
    ])
      field: FocusNode(),
  };
  int _step = 0;
  bool _busy = false;
  bool _loaded = false;
  bool _draftPersistenceEnabled = false;
  bool _restoringDraft = false;
  bool _recoveredLocalDraft = false;
  bool _prohibitedConfirmed = false;
  Timer? _draftTimer;
  Object? _loadError;
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
  final Set<String> _transportationMethods = {
    'walking',
    'bicycle',
    'car',
    'public_transit',
    'rideshare',
    'other',
  };
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _deadlineAt;
  double? _jobSiteLatitude;
  double? _jobSiteLongitude;
  double? _jobSiteAccuracyMeters;
  bool _capturingJobSite = false;
  PreciseLocationStatus? _jobSiteCaptureStatus;
  final _preciseLocationService = const PreciseLocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final controller in _controllers) {
      controller.addListener(_onDraftFieldChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.jobId != null) {
        unawaited(_loadJob());
      } else {
        unawaited(_restoreLocalDraft());
      }
    });
  }

  List<TextEditingController> get _controllers => [
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
    _transportationNotes,
    _pay,
    _safetyNotes,
  ];

  Future<void> _loadJob() async {
    try {
      final job = await ref.read(jobsRepositoryProvider).getJob(widget.jobId!);
      if (!mounted) return;
      if (job == null) {
        throw StateError('The requested job draft was not found.');
      }
      _restoringDraft = true;
      _applyJob(job);
      _restoringDraft = false;
      _draftPersistenceEnabled = true;
      setState(() => _loaded = true);
    } catch (error) {
      if (!mounted) return;
      _restoringDraft = false;
      setState(() {
        _loadError = error;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _draftTimer?.cancel();
      unawaited(_persistLocalDraft());
    }
  }

  void _onDraftFieldChanged() {
    if (_restoringDraft) return;
    _fieldErrors.clear();
    _scheduleDraftPersist();
  }

  void _scheduleDraftPersist() {
    if (!_draftPersistenceEnabled || _restoringDraft) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _persistLocalDraft);
  }

  void _change(VoidCallback update) {
    setState(update);
    _scheduleDraftPersist();
  }

  Future<void> _persistLocalDraft() async {
    if (!_draftPersistenceEnabled || !SupabaseService.isInitialized) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    _syncDraft();
    try {
      await ref
          .read(secureDraftStorageProvider)
          .writeJobDraft(userId, _draft.toLocalMap(activeStep: _step));
    } catch (_) {
      // Local recovery is best-effort; server save remains authoritative.
    }
  }

  Future<void> _restoreLocalDraft() async {
    if (!SupabaseService.isInitialized) {
      _draftPersistenceEnabled = true;
      return;
    }
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      _draftPersistenceEnabled = true;
      return;
    }
    try {
      final stored = await ref
          .read(secureDraftStorageProvider)
          .readJobDraft(userId);
      if (!mounted) return;
      if (stored != null) {
        final recovered = JobDraft.fromLocalMap(stored);
        _restoringDraft = true;
        _draft = recovered;
        _applyDraft(recovered);
        _step = _localStep(stored).clamp(0, jobCreationSteps.length - 1);
        _recoveredLocalDraft = true;
        _restoringDraft = false;
      }
      _draftPersistenceEnabled = true;
      setState(() {});
    } catch (_) {
      _restoringDraft = false;
      await ref.read(secureDraftStorageProvider).clearJobDraft(userId);
      if (mounted) {
        _draftPersistenceEnabled = true;
        setState(() {});
      }
    }
  }

  static int _localStep(Map<String, dynamic> stored) =>
      int.tryParse(stored['active_step']?.toString() ?? '') ?? 0;

  Future<void> _clearLocalDraft() async {
    if (!SupabaseService.isInitialized) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    _draftTimer?.cancel();
    await ref.read(secureDraftStorageProvider).clearJobDraft(userId);
  }

  void _applyJob(Job job) {
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
    _transportationMethods
      ..clear()
      ..addAll(job.acceptableTransportationMethods);
    _transportationNotes.text = job.transportationConsiderations ?? '';
    _environment = job.workEnvironment;
    _locationType = job.locationType;
    _pay.text = job.adultJobAmountCents == null
        ? ''
        : (job.adultJobAmountCents! / 100).toStringAsFixed(2);
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
  }

  void _applyDraft(JobDraft draft) {
    _title.text = draft.title;
    _summary.text = draft.summary;
    _description.text = draft.description;
    _category = safeJobCategories.contains(draft.category)
        ? draft.category
        : safeJobCategories.last;
    _duration.text = draft.estimatedDurationMinutes?.toString() ?? '';
    _workers.text = draft.workersNeeded.toString();
    _experience = draft.experienceLevel;
    _skills.text = draft.skillsNeeded.join(', ');
    _equipmentProvided.text = draft.equipmentProvided;
    _equipmentBrings.text = draft.equipmentWorkerBrings;
    _instructions.text = draft.specialInstructions;
    _proofExpected = draft.proofExpected;
    _scheduleType = draft.scheduleType;
    _startsAt = draft.startsAt;
    _endsAt = draft.endsAt;
    _deadlineAt = draft.deadlineAt;
    _recurring = draft.recurring;
    _recurrenceRule.text = draft.recurrenceRule;
    _urgency = draft.urgency;
    _timezone = draft.timezone;
    _area.text = draft.locationText;
    _city.text = draft.city;
    _state.text = draft.state;
    _neighborhood.text = draft.neighborhood;
    _zip.text = draft.zipCode;
    _radius.text = draft.travelRadiusMiles?.toString() ?? '';
    _transportationMethods
      ..clear()
      ..addAll(draft.acceptableTransportationMethods);
    _transportationNotes.text = draft.transportationConsiderations;
    _environment = draft.workEnvironment;
    _locationType = draft.locationType;
    _pay.text = draft.adultJobAmountCents == null
        ? ''
        : (draft.adultJobAmountCents! / 100).toStringAsFixed(2);
    _paymentType = draft.paymentType;
    _paymentMethod = draft.paymentMethod;
    _paymentTiming = draft.paymentTiming;
    _tipAllowed = draft.tipAllowed;
    _adultSupervision = draft.adultSupervisionPresent;
    _verification = draft.verificationRequirement;
    _guardianApproval = draft.requiresGuardianApproval;
    _teenMinAge = draft.teenMinAge;
    _physicalRequirements
      ..clear()
      ..addAll(draft.physicalRequirements);
    _safetyNotes.text = draft.safetyNotes;
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
      ..acceptableTransportationMethods = _transportationMethods.toList()
      ..transportationConsiderations = _transportationNotes.text.trim()
      ..workEnvironment = _environment
      ..locationType = _locationType
      ..adultJobAmountCents = MortServiceFee.tryParseAdultAmount(_pay.text)
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

  String _validationFailure(String field, String message) {
    _fieldErrors[field] = message;
    return message;
  }

  void _focusFirstFieldError() {
    for (final field in _focusNodes.keys) {
      if (_fieldErrors.containsKey(field)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNodes[field]?.requestFocus();
        });
        return;
      }
    }
  }

  int _stepForField(String field) => switch (field) {
    'title' ||
    'summary' ||
    'description' ||
    'category' => JobCreationStep.basics.index,
    'estimated_duration_minutes' ||
    'workers_needed' ||
    'physical_requirements' ||
    'special_instructions' => JobCreationStep.workDetails.index,
    'starts_at' ||
    'ends_at' ||
    'deadline_at' ||
    'recurrence_rule' => JobCreationStep.schedule.index,
    'location_text' ||
    'city' ||
    'state' ||
    'zip_code' ||
    'travel_radius_miles' ||
    'acceptable_transportation_methods' ||
    'transportation_considerations' ||
    'work_environment' ||
    'location_type' => JobCreationStep.location.index,
    'adult_job_amount_cents' => JobCreationStep.payment.index,
    'teen_min_age' ||
    'teen_max_age' ||
    'verification_requirement' ||
    'safety_notes' => JobCreationStep.safety.index,
    _ => _step,
  };

  String? _validateStep() {
    if (_step == 0) {
      if (_title.text.trim().length < 5 || _title.text.trim().length > 80) {
        return _validationFailure(
          'title',
          'Use a clear title between 5 and 80 characters.',
        );
      }
      if (_summary.text.trim().length < 10 ||
          _summary.text.trim().length > 240) {
        return _validationFailure(
          'summary',
          'Add a short summary between 10 and 240 characters.',
        );
      }
      if (_description.text.trim().length < 20) {
        return _validationFailure(
          'description',
          'Add at least 20 characters of job detail.',
        );
      }
      final safetyError = MortValidators.teenSafeJobText(
        '${_title.text}\n${_summary.text}\n${_description.text}',
      );
      return safetyError == null
          ? null
          : _validationFailure('description', safetyError);
    }
    if (_step == 1) {
      final duration = int.tryParse(_duration.text);
      if (duration == null || duration < 15 || duration > 1440) {
        return _validationFailure(
          'estimated_duration_minutes',
          'Estimated duration must be between 15 and 1,440 minutes.',
        );
      }
      final workers = int.tryParse(_workers.text);
      if (workers == null || workers < 1 || workers > 10) {
        return _validationFailure(
          'workers_needed',
          'Workers needed must be between 1 and 10.',
        );
      }
      if (_proofExpected && _instructions.text.trim().length < 10) {
        return _validationFailure(
          'special_instructions',
          'Explain in at least 10 characters what the completion photo should show.',
        );
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
      if (_area.text.trim().isEmpty) {
        return _validationFailure(
          'location_text',
          'Add a general area without a street address.',
        );
      }
      if (_city.text.trim().isEmpty) {
        return _validationFailure('city', 'Add the city for this job.');
      }
      if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(_state.text.trim())) {
        return _validationFailure('state', 'Use a two-letter state code.');
      }
      if (_zip.text.trim().isNotEmpty &&
          !RegExp(r'^\d{5}(-\d{4})?$').hasMatch(_zip.text.trim())) {
        return _validationFailure(
          'zip_code',
          'Enter a five-digit ZIP code or leave it blank.',
        );
      }
      final radius = int.tryParse(_radius.text);
      if (_radius.text.trim().isNotEmpty &&
          (radius == null || radius < 1 || radius > 100)) {
        return _validationFailure(
          'travel_radius_miles',
          'Travel radius must be between 1 and 100 miles.',
        );
      }
      if (_transportationMethods.isEmpty) {
        return _validationFailure(
          'acceptable_transportation_methods',
          'Choose at least one transportation method that can work for this job.',
        );
      }
      if (_transportationNotes.text.trim().length > 500) {
        return _validationFailure(
          'transportation_considerations',
          'Keep transportation considerations under 500 characters.',
        );
      }
    }
    if (_step == 4) {
      final error = MortServiceFee.validateAdultAmount(_pay.text);
      return error == null
          ? null
          : _validationFailure('adult_job_amount_cents', error);
    }
    if (_step == 5 && !_prohibitedConfirmed) {
      return 'Confirm that the job does not include prohibited work or upfront fees.';
    }
    return null;
  }

  Future<void> _captureJobSite() async {
    setState(() {
      _capturingJobSite = true;
      _jobSiteCaptureStatus = null;
    });
    final result = await _preciseLocationService.requestFreshPreciseLocation();
    if (!mounted) return;
    setState(() {
      _capturingJobSite = false;
      _jobSiteCaptureStatus = result.status;
      if (result.isUsable) {
        _jobSiteLatitude = result.position!.latitude;
        _jobSiteLongitude = result.position!.longitude;
        _jobSiteAccuracyMeters = result.position!.accuracy;
      }
    });
  }

  Future<void> _saveJobSiteLocation(String jobId) async {
    if (_jobSiteLatitude == null || _jobSiteLongitude == null) return;
    try {
      await ref
          .read(trustSafetyRepositoryProvider)
          .savePrivateJobLocation(
            jobId: jobId,
            latitude: _jobSiteLatitude,
            longitude: _jobSiteLongitude,
            locationAccuracyMeters: _jobSiteAccuracyMeters,
          );
    } catch (error) {
      if (mounted) {
        MortToast.show(
          context,
          'Job saved, but the precise job site could not be recorded: '
          '${userFacingError(error)}',
        );
      }
    }
  }

  Future<void> _save({required bool publish}) async {
    if (_busy) return;
    _fieldErrors.clear();
    if (publish) {
      final original = _step;
      for (
        var step = JobCreationStep.basics.index;
        step <= JobCreationStep.safety.index;
        step++
      ) {
        _step = step;
        final error = _validateStep();
        if (error != null) {
          _step = step;
          setState(() {});
          _focusFirstFieldError();
          MortToast.show(context, error);
          return;
        }
      }
      _step = original;
    }
    _syncDraft();
    unawaited(_persistLocalDraft());
    setState(() => _busy = true);
    try {
      final result = publish
          ? await ref.read(jobsRepositoryProvider).publishWithState(_draft)
          : await ref.read(jobsRepositoryProvider).saveDraftWithState(_draft);
      if (!mounted) return;
      await _saveJobSiteLocation(result.job.id);
      if (!mounted) return;
      final message = switch (result.publicationState) {
        'open' => 'Job opened for applications.',
        'pending_review' =>
          'Saved for review. Applications remain unavailable.',
        'draft' => 'Draft saved to MORT.',
        _ =>
          publish
              ? 'Job saved, but applications are not open.'
              : 'Draft saved to MORT.',
      };
      MortToast.show(context, message);
      if (publish) {
        _draftPersistenceEnabled = false;
        await _clearLocalDraft();
        if (mounted) context.go('/adult/jobs/${result.job.id}');
      } else {
        await _persistLocalDraft();
        if (!mounted) return;
        setState(() {});
      }
    } on MortFieldCodedError catch (error) {
      if (!mounted) return;
      final message = userFacingError(error);
      _fieldErrors[error.field] = message;
      setState(() => _step = _stepForField(error.field));
      _focusFirstFieldError();
      MortToast.show(context, message);
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    _fieldErrors.clear();
    final error = _validateStep();
    if (error != null) {
      setState(() {});
      _focusFirstFieldError();
      MortToast.show(context, error);
      return;
    }
    _syncDraft();
    setState(() => _step = (_step + 1).clamp(0, jobCreationSteps.length - 1));
    _scheduleDraftPersist();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobId != null && !_loaded && _draft.id == null) {
      return const MortLoading(label: 'Loading job draft');
    }
    if (_loadError != null) {
      return MortScreen(
        children: [
          MortErrorState(
            title: 'Job draft unavailable',
            message: userFacingError(_loadError),
            action: MortButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: () {
                setState(() {
                  _loaded = false;
                  _loadError = null;
                });
                unawaited(_loadJob());
              },
            ),
          ),
        ],
      );
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
                    onPressed: () {
                      setState(() => _step--);
                      _scheduleDraftPersist();
                    },
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
          eyebrow: 'Step ${_step + 1} of ${jobCreationSteps.length}',
          title: jobCreationStepAt(_step).title,
          subtitle: 'Create a job listing. Exact addresses and private contact details do not belong in public fields.',
        ),
        MortStepper(current: _step, total: jobCreationSteps.length),
        if (_recoveredLocalDraft) ...[
          const SizedBox(height: MortSpacing.sm),
          const MortSafetyBanner(
            message: 'Recovered your encrypted draft from this account on this device. Review it before saving or publishing.',
          ),
        ],
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

  Widget _buildStep() => switch (jobCreationStepAt(_step)) {
    JobCreationStep.basics => _basics(),
    JobCreationStep.workDetails => _workDetails(),
    JobCreationStep.schedule => _schedule(),
    JobCreationStep.location => _location(),
    JobCreationStep.payment => _payment(),
    JobCreationStep.safety => _safety(),
    JobCreationStep.preview => _preview(),
    JobCreationStep.publish => _publish(),
  };

  Widget _basics() => Column(
    children: [
      MortTextField(
        label: 'Title',
        controller: _title,
        maxLength: 80,
        focusNode: _focusNodes['title'],
        errorText: _fieldErrors['title'],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortSearchableDropdown<String>(
        label: 'Category',
        value: _category,
        items: {for (final value in safeJobCategories) value: value},
        searchHint: 'Search safe job categories',
        errorText: _fieldErrors['category'],
        onChanged: (value) {
          _change(() => _category = value);
        },
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Short summary',
        controller: _summary,
        maxLines: 2,
        maxLength: 240,
        focusNode: _focusNodes['summary'],
        errorText: _fieldErrors['summary'],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Detailed description',
        controller: _description,
        maxLength: 4000,
        hint: 'Explain the work, expected result, and safe boundaries.',
        focusNode: _focusNodes['description'],
        errorText: _fieldErrors['description'],
      ),
    ],
  );

  Widget _workDetails() => Column(
    children: [
      MortTextField(
        label: 'Estimated duration (minutes)',
        controller: _duration,
        keyboardType: TextInputType.number,
        focusNode: _focusNodes['estimated_duration_minutes'],
        errorText: _fieldErrors['estimated_duration_minutes'],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Workers needed',
        controller: _workers,
        keyboardType: TextInputType.number,
        focusNode: _focusNodes['workers_needed'],
        errorText: _fieldErrors['workers_needed'],
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
        onChanged: (value) => _change(() => _experience = value ?? 'any'),
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
              onSelected: (selected) => _change(() {
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
        onChanged: (value) => _change(() => _proofExpected = value),
      ),
      MortTextArea(
        label: 'Special instructions',
        controller: _instructions,
        maxLength: 1000,
        focusNode: _focusNodes['special_instructions'],
        errorText: _fieldErrors['special_instructions'],
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
            _change(() => _scheduleType = value ?? 'flexible'),
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
        onChanged: (value) => _change(() => _recurring = value),
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
        onChanged: (value) => _change(() => _urgency = value ?? 'normal'),
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
            _change(() => _timezone = value ?? 'America/Indianapolis'),
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

  Widget _jobSiteCapture() {
    final captured = _jobSiteLatitude != null && _jobSiteLongitude != null;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job site', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'MORT records the exact job site privately from your device\'s '
            'precise location. It is never shown publicly -- workers see '
            'only distance and general area until an accepted worker '
            'confirms the safety agreement.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: MortSpacing.sm),
          if (_capturingJobSite)
            const MortLoading(label: 'Finding your location', fullScreen: false)
          else if (captured)
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: MortColors.success,
                ),
                const SizedBox(width: MortSpacing.xs),
                Expanded(
                  child: Text(
                    'Job site set from your precise location'
                    '${_jobSiteAccuracyMeters != null ? ' (±${_jobSiteAccuracyMeters!.round()}m)' : ''}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                MortSecondaryButton(
                  label: 'Update',
                  onPressed: _captureJobSite,
                ),
              ],
            )
          else if (_jobSiteCaptureStatus != null &&
              _jobSiteCaptureStatus != PreciseLocationStatus.granted)
            PreciseLocationRequiredCard(
              status: _jobSiteCaptureStatus!,
              onRetry: _captureJobSite,
              onOpenSettings: () => _preciseLocationService.openSettings(),
              onOpenLocationSettings: () =>
                  _preciseLocationService.openLocationSettings(),
            )
          else
            MortPrimaryButton(
              label: 'Use current precise location',
              icon: Icons.my_location_rounded,
              onPressed: _captureJobSite,
            ),
        ],
      ),
    );
  }

  Widget _location() => Column(
    children: [
      _jobSiteCapture(),
      const SizedBox(height: MortSpacing.md),
      MortTextField(
        label: 'Approximate area',
        controller: _area,
        hint: 'North side, downtown, or nearby landmark area',
        focusNode: _focusNodes['location_text'],
        errorText: _fieldErrors['location_text'],
      ),
      const SizedBox(height: MortSpacing.sm),
      Row(
        children: [
          Expanded(
            child: MortTextField(
              label: 'City',
              controller: _city,
              focusNode: _focusNodes['city'],
              errorText: _fieldErrors['city'],
            ),
          ),
          const SizedBox(width: MortSpacing.sm),
          SizedBox(
            width: 100,
            child: MortTextField(
              label: 'State',
              controller: _state,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              focusNode: _focusNodes['state'],
              errorText: _fieldErrors['state'],
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
        focusNode: _focusNodes['zip_code'],
        errorText: _fieldErrors['zip_code'],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextField(
        label: 'Travel radius miles (optional)',
        controller: _radius,
        keyboardType: TextInputType.number,
        focusNode: _focusNodes['travel_radius_miles'],
        errorText: _fieldErrors['travel_radius_miles'],
      ),
      const SizedBox(height: MortSpacing.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Transportation that can work',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: MortSpacing.xs),
      Wrap(
        spacing: MortSpacing.xs,
        runSpacing: MortSpacing.xs,
        children: [
          for (final option in const {
            'walking': 'Walking',
            'bicycle': 'Bicycle',
            'car': 'Car',
            'public_transit': 'Public transit',
            'rideshare': 'Rideshare',
            'other': 'Other',
          }.entries)
            MortFilterChip(
              label: option.value,
              selected: _transportationMethods.contains(option.key),
              onSelected: (selected) => _change(() {
                if (selected) {
                  _transportationMethods.add(option.key);
                } else {
                  _transportationMethods.remove(option.key);
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: MortSpacing.sm),
      MortTextArea(
        label: 'Transportation considerations (optional)',
        controller: _transportationNotes,
        maxLength: 500,
        hint: 'General access guidance only, such as near a bus stop. Do not enter a street address.',
        focusNode: _focusNodes['transportation_considerations'],
        errorText: _fieldErrors['transportation_considerations'],
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
            _change(() => _environment = value ?? 'unspecified'),
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
            _change(() => _locationType = value ?? 'unspecified'),
      ),
      const SizedBox(height: MortSpacing.sm),
      const MortSafetyBanner(
        message: 'Only the approximate area appears publicly. Do not put a street address, access code, or teen location in these fields.',
      ),
    ],
  );

  Widget _payment() => Column(
    children: [
      MortTextField(
        label: 'Offered job amount',
        controller: _pay,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        validator: MortServiceFee.validateAdultAmount,
        focusNode: _focusNodes['adult_job_amount_cents'],
        errorText: _fieldErrors['adult_job_amount_cents'],
      ),
      const SizedBox(height: MortSpacing.sm),
      if (MortServiceFee.breakdown(_pay.text) case final breakdown?) ...[
        MortGlassCard(
          child: Column(
            children: [
              MortPriceDisplay(
                label: 'Offered amount',
                formattedAmount: formatCents(breakdown.teenPayoutCents),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
      ],
      MortDropdown<String>(
        label: 'Payment type',
        value: _paymentType,
        items: const {'fixed': 'Fixed amount', 'hourly': 'Hourly'},
        onChanged: (value) => _change(() => _paymentType = value ?? 'fixed'),
      ),
      const SizedBox(height: MortSpacing.sm),
      const MortCard(
        child: Text(
          'The amount is an offer recorded with the job. MORT does not collect it, deduct a fee, choose a payment method, guarantee payment, or mark it paid.',
        ),
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
        onChanged: (value) => _change(() => _teenMinAge = value ?? 13),
      ),
      const SizedBox(height: MortSpacing.sm),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _adultSupervision,
        title: const Text('Adult supervision present'),
        onChanged: (value) => _change(() => _adultSupervision = value),
      ),
      MortDropdown<String>(
        label: 'Applicant verification',
        value: _verification,
        items: const {
          'none': 'No additional requirement',
          'preferred': 'Verified applicants preferred',
          'required': 'Verified applicants required',
        },
        onChanged: (value) => _change(() => _verification = value ?? 'none'),
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _guardianApproval,
        title: const Text('Request guardian approval for this job'),
        subtitle: const Text(
          'Optional. Turning this on may reduce the number of eligible applicants.',
        ),
        onChanged: (value) => _change(() => _guardianApproval = value),
      ),
      MortTextArea(
        label: 'Safety notes',
        controller: _safetyNotes,
        maxLength: 1000,
        focusNode: _focusNodes['safety_notes'],
        errorText: _fieldErrors['safety_notes'],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _prohibitedConfirmed,
        onChanged: (value) =>
            _change(() => _prohibitedConfirmed = value ?? false),
        title: const Text(
          'I confirm this job has no dangerous heights, weapons, hazardous chemicals, illegal activity, alcohol/drug handling, overnight isolation, upfront fee, gift card, or cryptocurrency demand.',
        ),
      ),
    ],
  );

  Widget _preview() {
    _syncDraft();
    final breakdown = MortServiceFee.breakdown(_pay.text);
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
                '${formatCents(breakdown?.teenPayoutCents)} offered amount | ${_draft.locationText}',
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
        if (breakdown != null) ...[
          MortGlassCard(
            child: Column(
              children: [
                MortPriceDisplay(
                  label: 'Offered amount',
                  formattedAmount: formatCents(breakdown.teenPayoutCents),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
        ],
        const MortPaymentDisclaimer(),
      ],
    );
  }

  Widget _publish() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const MortSafetyBanner(
        message: 'MORT will validate every section, run the server safety rules, enforce the posting limit, and publish one idempotent job record.',
      ),
      const SizedBox(height: MortSpacing.md),
      _JobChecklist(
        items: [
          'Title: ${_title.text.trim()}',
          'Category: $_category',
          'Schedule: ${_scheduleType == 'flexible' ? 'Flexible schedule' : formatDateTime(_startsAt)}',
          'Approximate location: ${_area.text.trim()}, ${_city.text.trim()}, ${_state.text.trim().toUpperCase()}',
          'Guardian approval: ${_guardianApproval ? 'Requested for this job' : 'Not required'}',
          'Offered amount: ${formatCents(MortServiceFee.tryParseAdultAmount(_pay.text))}',
          'MORT payment processing: Disabled',
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
    _change(() {
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
    if (date != null) _change(() => _deadlineAt = date);
  }
}

class AdultJobsScreen extends ConsumerWidget {
  const AdultJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Adult jobs',
          title: 'Manage jobs',
          subtitle: 'Drafts, open jobs, assignments, proof, and completion use tracked workflow states.',
          trailing: MortIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh jobs',
            onPressed: () => ref.invalidate(myJobsProvider),
          ),
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
        jobs.when(
          loading: () => const MortSkeletonCard(),
          error: (error, _) => MortErrorState(
            title: 'Jobs unavailable',
            message: userFacingError(error),
            action: MortButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(myJobsProvider),
            ),
          ),
          data: (jobs) {
            if (jobs.isEmpty) {
              return const MortEmptyState(
                title: 'No jobs yet',
                message: 'Create a draft, preview it, then publish when it is ready.',
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
                        Text('${job.payDisplay} | ${job.scheduleDisplay}'),
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
  late Future<Job?> _jobFuture;

  @override
  void initState() {
    super.initState();
    _jobFuture = ref.read(jobsRepositoryProvider).getJob(widget.jobId);
  }

  void _reload() {
    setState(() {
      _jobFuture = ref.read(jobsRepositoryProvider).getJob(widget.jobId);
    });
  }

  Future<void> _action(String action, Job job) async {
    if (_busy) return;
    String? reason;
    if (action == 'cancel') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _JobCancellationReasonDialog(),
      );
      if (reason == null) return;
    } else if (action == 'delete_draft') {
      final confirmed = await MortConfirmSheet.show(
        context,
        title: 'Delete this draft?',
        message:
            'This draft has no applicants and will be permanently deleted.',
      );
      if (!confirmed) return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(jobsRepositoryProvider)
          .manageJob(
            widget.jobId,
            action,
            reason: reason,
            expectedUpdatedAt: job.updatedAt,
          );
      if (!mounted) return;
      if (action == 'delete_draft') {
        context.go('/adult/jobs');
      } else if (action == 'duplicate' && result != null) {
        context.go('/adult/jobs/${result.id}/edit');
      } else {
        MortToast.show(context, 'Job updated.');
        _reload();
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
      future: _jobFuture,
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
              subtitle: '${job.payDisplay} | ${job.scheduleDisplay}',
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
                    onPressed: () => _action('pause', job),
                  ),
                if (job.status == 'paused')
                  MortAction(
                    label: 'Resume',
                    icon: Icons.play_arrow,
                    busy: _busy,
                    onPressed: () => _action('resume', job),
                  ),
                if (job.status == 'open')
                  MortAction(
                    label: 'Close applications',
                    icon: Icons.lock,
                    busy: _busy,
                    onPressed: () => _action('close_applications', job),
                  ),
                if (job.status == 'open' && !job.applicationsOpen)
                  MortAction(
                    label: 'Reopen applications',
                    icon: Icons.lock_open,
                    busy: _busy,
                    onPressed: () => _action('reopen_applications', job),
                  ),
                MortAction(
                  label: 'Duplicate',
                  icon: Icons.copy,
                  busy: _busy,
                  onPressed: () => _action('duplicate', job),
                ),
                if (job.status == 'draft')
                  MortAction(
                    label: 'Delete draft',
                    icon: Icons.delete,
                    busy: _busy,
                    onPressed: () => _action('delete_draft', job),
                    style: MortButtonStyle.danger,
                  ),
                if (['open', 'paused', 'assigned'].contains(job.status))
                  MortAction(
                    label: 'Cancel job',
                    icon: Icons.cancel,
                    busy: _busy,
                    onPressed: () => _action('cancel', job),
                    style: MortButtonStyle.danger,
                  ),
                if (job.status == 'in_progress')
                  const MortAction(
                    label: 'Get cancellation or dispute help',
                    icon: Icons.support_agent,
                    route: '/support/new',
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

class _JobCancellationReasonDialog extends StatefulWidget {
  const _JobCancellationReasonDialog();

  @override
  State<_JobCancellationReasonDialog> createState() =>
      _JobCancellationReasonDialogState();
}

class _JobCancellationReasonDialogState
    extends State<_JobCancellationReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _reason.text.trim();
    if (value.length < 10) {
      setState(() => _error = 'Add at least 10 characters.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel this job?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Applications will close. The reason is saved in job history and shared with assigned participants.',
            ),
            const SizedBox(height: MortSpacing.md),
            MortTextArea(
              label: 'Cancellation reason',
              controller: _reason,
              maxLines: 4,
              maxLength: 500,
            ),
            if (_error != null) ...[
              const SizedBox(height: MortSpacing.xs),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep job'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Cancel job')),
      ],
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

class SavedJobsScreen extends ConsumerStatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  ConsumerState<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends ConsumerState<SavedJobsScreen> {
  Future<List<Job>>? _jobsFuture;
  String? _busyJobId;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _loadSavedJobs();
  }

  Future<List<Job>> _loadSavedJobs() async {
    return ref.read(jobsRepositoryProvider).listSavedJobs();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _jobsFuture = _loadSavedJobs());
    await _jobsFuture;
  }

  Future<void> _removeSavedJob(String jobId) async {
    if (_busyJobId != null) return;
    setState(() => _busyJobId = jobId);
    try {
      await ref.read(jobsRepositoryProvider).unsaveJob(jobId);
      if (!mounted) return;
      MortToast.show(context, 'Job removed from saved jobs.');
      setState(() => _jobsFuture = _loadSavedJobs());
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busyJobId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Saved jobs',
          title: 'Jobs to revisit',
          subtitle: 'Saved jobs stay with your account and show their current availability.',
        ),
        FutureBuilder<List<Job>>(
          future: _jobsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Column(
                children: [
                  MortSkeletonCard(),
                  SizedBox(height: MortSpacing.sm),
                  MortSkeletonCard(),
                ],
              );
            if (snapshot.hasError)
              return MortErrorState(
                title: 'Saved jobs unavailable',
                message: userFacingError(snapshot.error),
                action: MortButton(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: _refresh,
                ),
              );
            final jobs = snapshot.data ?? const [];
            if (jobs.isEmpty)
              return MortEmptyState(
                title: 'No saved jobs',
                message: 'Save a job from its detail screen to find it here. You can return when a poster updates availability.',
                action: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MortButton(
                      label: 'Browse teen jobs',
                      icon: Icons.search,
                      onPressed: () => context.go('/teen/jobs'),
                    ),
                    const SizedBox(height: MortSpacing.xs),
                    MortButton(
                      label: 'Refresh',
                      icon: Icons.refresh_rounded,
                      style: MortButtonStyle.secondary,
                      onPressed: _refresh,
                    ),
                  ],
                ),
              );
            return Column(
              children: [
                for (final job in jobs) ...[
                  MortCard(
                    onTap: () => context.push('/teen/jobs/${job.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          '${job.payDisplay} | ${job.scheduleDisplay}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: MortSpacing.xs),
                        Text(
                          job.locationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: MortSpacing.sm),
                        Row(
                          children: [
                            MortJobStatusBadge(status: job.status),
                            const SizedBox(width: MortSpacing.xs),
                            if (!job.isOpen)
                              const MortBadge(
                                label: 'No longer open',
                                color: MortColors.danger,
                              ),
                          ],
                        ),
                        const SizedBox(height: MortSpacing.sm),
                        MortActionRow(
                          actions: [
                            MortAction(
                              label: 'View job',
                              icon: Icons.open_in_new,
                              onPressed: () =>
                                  context.push('/teen/jobs/${job.id}'),
                            ),
                            MortAction(
                              label: 'Remove',
                              icon: Icons.delete_outline,
                              style: MortButtonStyle.secondary,
                              busy: _busyJobId == job.id,
                              enabled: _busyJobId == null,
                              onPressed: () => _removeSavedJob(job.id),
                            ),
                          ],
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
      ],
    );
  }
}
