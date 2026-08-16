import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/utils/date_of_birth.dart';
import '../../core/widgets/date_of_birth_field.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/onboarding_progress.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';
import '../../services/native_permissions_service.dart';
import '../profile/profile_avatar_widgets.dart';

class CompactOnboardingScreen extends ConsumerStatefulWidget {
  const CompactOnboardingScreen({super.key});

  @override
  ConsumerState<CompactOnboardingScreen> createState() =>
      _CompactOnboardingScreenState();
}

class _CompactOnboardingScreenState
    extends ConsumerState<CompactOnboardingScreen> {
  static const _totalSteps = 5;
  static const _stepTitles = <String>[
    'Start with your age',
    'Make it yours',
    'Set your area',
    'Interests and safety',
    'Review and finish',
  ];
  static const _stepDescriptions = <String>[
    'Your age sets the right MORT experience. Your birthday is never shown publicly.',
    'Choose the name and username people will see in MORT.',
    'Give MORT enough detail to find relevant local work without exposing a private address.',
    'Choose work you are interested in and review the rules that help keep MORT safer.',
    'Check the essentials before MORT saves your completed setup.',
  ];
  static const _suggestedCategories = <String>[
    'Yard work',
    'Pet care',
    'Tutoring',
    'Cleaning',
    'Tech help',
    'Errands',
  ];

  int _step = 0;
  final _scrollController = ScrollController();
  final _dob = TextEditingController();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _interestController = TextEditingController();
  final _categories = <String>{};
  final _transportMethods = <String>{};
  UserRole? _role;
  bool _adultWantsGuardianRole = false;
  bool _safetyAcknowledged = false;
  bool _busy = false;
  bool _restoring = true;
  bool _legalAcceptanceRequired = false;
  final _dirtySteps = <int>{};
  String? _locationHint;
  String? _stepError;

  @override
  void initState() {
    super.initState();
    _dob.addListener(_handleDobChanged);
    for (final controller in _trackedTextControllers) {
      controller.addListener(_handleTextChanged);
    }
    _restoreProgress();
  }

  List<TextEditingController> get _trackedTextControllers => [
    _displayName,
    _username,
    _city,
    _state,
    _zip,
    _interestController,
  ];

  void _markStepDirty() {
    if (_restoring || !mounted) return;
    setState(() {
      _dirtySteps.add(_step);
      _stepError = null;
    });
  }

  void _handleTextChanged() => _markStepDirty();

  // A minor must never be able to select Guardian and have it silently
  // ignored — _next() already ignores it for under-18 regardless, but
  // the UI itself shouldn't offer the choice to someone it doesn't apply
  // to in the first place, and any stale true value gets cleared the
  // instant DOB no longer supports it, not left sitting around.
  bool get _dobIndicatesAdultEligible {
    final dob = DateOfBirthParser.tryParse(_dob.text);
    if (dob == null) return false;
    return DateOfBirthParser.ageOn(dob, DateTime.now()) >= 18;
  }

  void _handleDobChanged() {
    if (!mounted || _restoring) return;
    setState(() {
      _dirtySteps.add(_step);
      _stepError = null;
      if (!_dobIndicatesAdultEligible) {
        _adultWantsGuardianRole = false;
      }
    });
  }

  Future<void> _restoreProgress() async {
    try {
      final progress = await ref
          .read(profileRepositoryProvider)
          .getOnboardingProgress();
      // .future, not .value — .value would silently be null if
      // currentProfileProvider's own fetch hadn't resolved yet by this
      // point (a real race, independent of the onboarding-progress
      // fetch above), which would have made role/hydration randomly
      // incomplete depending on timing rather than reliably correct.
      final profile = await ref.read(currentProfileProvider.future);
      _applyProgress(progress, profile);
    } catch (_) {
      // continue with blank state if progress cannot be loaded.
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  // Single source of truth for step resolution. Previously this was two
  // separate mappings (a currentStep->step map, then a resumePath
  // substring check that could overwrite it) that had to be kept in sync
  // by hand and had already drifted apart — 'review' mapped to step 3 in
  // one and was grouped into step 2 in the other. resumePath is the more
  // specific signal (it's the literal old URL), so it's authoritative;
  // currentStep is only a fallback for when resumePath doesn't match any
  // known pattern.
  static int _stepForProgress(OnboardingProgress progress) {
    final path = progress.resumePath;
    if (path.contains('/onboarding/age') || path.contains('/onboarding/role')) {
      return 0;
    }
    if (path.contains('/onboarding/profile')) {
      return 1;
    }
    if (path.contains('/onboarding/skills') ||
        path.contains('/onboarding/availability') ||
        path.contains('/onboarding/transportation')) {
      return 2;
    }
    if (path.contains('/onboarding/guardian') ||
        path.contains('/onboarding/preferences') ||
        path.contains('/onboarding/safety') ||
        path.contains('/onboarding/payment')) {
      return 3;
    }
    if (path.contains('/onboarding/review')) {
      return 4;
    }
    const currentStepFallback = {
      'age': 0,
      'role': 0,
      'profile': 1,
      'profile_basics': 1,
      'skills': 2,
      'availability': 2,
      'transportation': 2,
      'payment': 3,
      'guardian': 3,
      'preferences': 3,
      'safety': 3,
      'interests_safety': 3,
      'review': 4,
      'complete': 4,
    };
    return currentStepFallback[progress.currentStep] ?? 0;
  }

  void _applyProgress(OnboardingProgress progress, Profile? profile) {
    if (!mounted) return;
    setState(() {
      _step = _stepForProgress(progress);
      _role = profile?.role;
      _adultWantsGuardianRole = profile?.role == UserRole.guardian;
      if (profile != null) _hydrateControllersFrom(profile);
    });
  }

  // Fixes the real bug: a returning user landed on the correct step
  // number, but every controller/set was still blank — DOB, name,
  // username, city/state/area, transport methods, interests — because
  // only the step index was ever restored, never the actual field
  // values already sitting in the database. Reads from the same
  // Profile the rest of the app already uses; no second persistence
  // mechanism.
  void _hydrateControllersFrom(Profile profile) {
    if (profile.dob != null) {
      _dob.text = DateOfBirthParser.display(profile.dob!);
    }
    if ((profile.displayName ?? '').isNotEmpty) {
      _displayName.text = profile.displayName!;
    }
    if ((profile.username ?? '').isNotEmpty) {
      _username.text = profile.username!;
    }
    if ((profile.city ?? '').isNotEmpty) {
      _city.text = profile.city!;
    }
    if ((profile.state ?? '').isNotEmpty) {
      _state.text = profile.state!;
    }
    if ((profile.approximateArea ?? '').isNotEmpty) {
      _zip.text = profile.approximateArea!;
    }
    _transportMethods
      ..clear()
      ..addAll(profile.transportationMethods);
    _categories
      ..clear()
      ..addAll(profile.preferredJobCategories);
    if (profile.preferredJobCategories.isNotEmpty) {
      _interestController.text = profile.preferredJobCategories.join(', ');
    }
  }

  @override
  void dispose() {
    _dob.removeListener(_handleDobChanged);
    for (final controller in _trackedTextControllers) {
      controller.removeListener(_handleTextChanged);
    }
    _scrollController.dispose();
    _dob.dispose();
    _displayName.dispose();
    _username.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _requestApproximateLocation() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final area = await const NativePermissionsService()
          .resolveCurrentGeneralArea();
      if (!mounted) return;
      _zip.text = '${area.city}, ${area.state}';
      setState(() {
        _locationHint = 'General area saved. Raw coordinates are not stored.';
        _dirtySteps.add(_step);
        _stepError = null;
      });
      MortToast.show(
        context,
        'General area saved without sharing your exact location.',
      );
    } catch (error) {
      if (!mounted) return;
      MortToast.show(
        context,
        error is StateError
            ? error.message.toString()
            : 'Unable to resolve a general area. Use ZIP/city instead.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validationMessage(DateTime now) {
    switch (_step) {
      case 0:
        final dob = DateOfBirthParser.tryParse(_dob.text, today: now);
        if (dob == null) return 'Enter a valid date of birth.';
        if (DateOfBirthParser.ageOn(dob, now) < 13) {
          return 'MORT is only available to people ages 13 and older.';
        }
        break;
      case 1:
        if (_displayName.text.trim().isEmpty) {
          return 'Enter a display name to continue.';
        }
        if (_username.text.trim().isEmpty) {
          return 'Enter a username to continue.';
        }
        break;
      case 2:
        final role =
            _role ??
            ref.read(currentProfileProvider).value?.role ??
            UserRole.teen;
        if (role == UserRole.teen) {
          if (_zip.text.trim().isEmpty && _transportMethods.isEmpty) {
            return 'Enter a ZIP or city, or choose how you usually get around.';
          }
        } else if (_city.text.trim().isEmpty ||
            _state.text.trim().length != 2) {
          return 'Enter a city and two-letter state.';
        }
        break;
      case 3:
        if (_categories.isEmpty) return 'Choose at least one interest.';
        if (!_safetyAcknowledged) {
          return 'Confirm that you reviewed the safety guidance.';
        }
        break;
      case 4:
        break;
    }
    return null;
  }

  String _saveFailureMessage(Object error) {
    final safeText = error.toString().toLowerCase();
    if (safeText.contains('username') &&
        (safeText.contains('taken') ||
            safeText.contains('unique') ||
            safeText.contains('available'))) {
      return 'That username is unavailable. Try another one.';
    }
    return 'We could not save this step. Check your connection and try again.';
  }

  void _showStepError(String message) {
    if (!mounted) return;
    setState(() => _stepError = message);
  }

  void _scrollToStepStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _next() async {
    if (_busy || _restoring) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final validationMessage = _validationMessage(now);
    if (validationMessage != null) {
      _showStepError(validationMessage);
      return;
    }
    setState(() {
      _busy = true;
      _legalAcceptanceRequired = false;
      _stepError = null;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      switch (_step) {
        case 0:
          final dob = DateOfBirthParser.tryParse(_dob.text, today: now);
          if (dob == null) return;
          final age = DateOfBirthParser.ageOn(dob, now);
          // Age determines teen vs. adult-eligible. Guardian is a real,
          // explicit choice for adult-eligible users (RoleSelectionScreen,
          // the old live /onboarding/role screen, offered Teen/Adult/
          // Guardian as three distinct options — a plain age check alone
          // would have silently dropped the Guardian path entirely).
          _role = age < 18
              ? UserRole.teen
              : (_adultWantsGuardianRole ? UserRole.guardian : UserRole.adult);
          await repo.saveOnboardingAge(dob);
          await repo.saveOnboardingRole(_role!);
          ref.invalidate(currentProfileProvider);
          break;
        case 1:
          final displayName = _displayName.text.trim();
          final username = _username.text.trim().toLowerCase();
          await repo.updateMyProfile({
            'display_name': displayName,
            'username': username,
          });
          await repo.saveOnboardingProgress(completedStep: 'profile_basics');
          ref.invalidate(currentProfileProvider);
          break;
        case 2:
          final role =
              _role ??
              ref.read(currentProfileProvider).value?.role ??
              UserRole.teen;
          if (role == UserRole.teen) {
            final approximateArea = _zip.text.trim();
            await repo.updateMyProfile({
              'location_setup_mode': 'location_deferred',
              'approximate_area': approximateArea.isEmpty
                  ? 'near current location'
                  : approximateArea,
              'transportation_methods': _transportMethods.toList(
                growable: false,
              ),
            });
            await repo.saveOnboardingProgress(completedStep: 'transportation');
          } else {
            final city = _city.text.trim();
            final state = _state.text.trim().toUpperCase();
            final dob = DateOfBirthParser.tryParse(_dob.text, today: now);
            if (dob == null) return;
            await repo.saveProfileSetup(
              role: role,
              displayName: _displayName.text.trim(),
              username: _username.text.trim().toLowerCase(),
              dob: dob,
              city: city,
              state: state,
              locationSetupMode: 'city_state',
              bio: '',
              availability: '',
              preferredJobCategories: _categories.toList(growable: false),
              approximateArea: _zip.text.trim(),
              goals: '',
              adultAccountType: 'individual',
              businessName: '',
              editExisting: false,
              clientRequestId: const Uuid().v4(),
            );
            await repo.saveOnboardingProgress(completedStep: 'transportation');
          }
          ref.invalidate(currentProfileProvider);
          break;
        case 3:
          await repo.updateMyProfile({
            'preferred_job_categories': _categories.toList(growable: false),
          });
          await repo.saveOnboardingProgress(completedStep: 'interests_safety');
          ref.invalidate(currentProfileProvider);
          break;
        case 4:
          await repo.completeOnboarding();
          ref.invalidate(currentProfileProvider);
          ref.invalidate(onboardingProgressProvider);
          break;
      }
      if (!mounted) return;
      _dirtySteps.remove(_step);
      if (_step < 4) {
        setState(() => _step++);
        _scrollToStepStart();
      } else {
        context.go('/account-status');
      }
    } catch (error) {
      final message = error is Exception ? error.toString() : error.toString();
      if (mounted) {
        if (message.contains('published_legal_acceptance_required') ||
            message.contains('onboarding_acknowledgement_required')) {
          setState(() {
            _legalAcceptanceRequired = true;
          });
          MortToast.show(
            context,
            'Accept the current published legal documents before finishing onboarding.',
          );
        } else {
          _showStepError(_saveFailureMessage(error));
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = step.clamp(0, _totalSteps - 1);
      _stepError = null;
      _legalAcceptanceRequired = false;
    });
    _scrollToStepStart();
  }

  void _back() {
    if (_step == 0) return;
    _goToStep(_step - 1);
  }

  Future<bool> _handleSystemBack(BuildContext context) async {
    if (_step > 0) {
      _back();
      return false;
    }
    if (_dirtySteps.isEmpty) return true;
    return MortConfirmSheet.show(
      context,
      title: 'Leave setup?',
      message:
          'Changes on this step have not been saved. Stay here to keep working, or leave and enter them again later.',
      confirmLabel: 'Leave setup',
    );
  }

  void _setAdultGuardianChoice(bool guardian) {
    setState(() {
      _adultWantsGuardianRole = guardian;
      _dirtySteps.add(_step);
      _stepError = null;
    });
  }

  void _syncTypedCategories(String value) {
    setState(() {
      _categories
        ..clear()
        ..addAll(
          value
              .split(',')
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty),
        );
      _dirtySteps.add(_step);
      _stepError = null;
    });
  }

  void _toggleCategory(String category, bool selected) {
    setState(() {
      if (selected) {
        _categories.add(category);
      } else {
        _categories.remove(category);
      }
      _dirtySteps.add(_step);
      _stepError = null;
    });
    final text = _categories.join(', ');
    _interestController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Widget _buildTravelMethodChip(String key, String label, IconData icon) {
    final selected = _transportMethods.contains(key);
    return FilterChip(
      label: Text(label),
      selected: selected,
      avatar: Icon(icon, size: 18),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _transportMethods.add(key);
          } else {
            _transportMethods.remove(key);
          }
          _dirtySteps.add(_step);
          _stepError = null;
        });
      },
    );
  }

  int? get _enteredAge {
    final dob = DateOfBirthParser.tryParse(_dob.text);
    if (dob == null) return null;
    return DateOfBirthParser.ageOn(dob, DateTime.now());
  }

  String get _roleLabel => switch (_role) {
    UserRole.teen => 'Teen account',
    UserRole.adult => 'Adult account',
    UserRole.guardian => 'Guardian account',
    _ => 'Account type pending',
  };

  String get _reviewArea {
    if (_role == UserRole.teen) {
      if (_zip.text.trim().isNotEmpty) return _zip.text.trim();
      return _transportMethods.isEmpty
          ? 'Area not provided'
          : 'Travel preferences saved';
    }
    final parts = [
      _city.text.trim(),
      _state.text.trim().toUpperCase(),
    ].where((part) => part.isNotEmpty).toList(growable: false);
    return parts.isEmpty ? 'Area not provided' : parts.join(', ');
  }

  Widget _buildAgeStep() {
    final age = _enteredAge;
    return Column(
      key: const ValueKey('onboarding-age'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnboardingNotice(
          icon: Icons.lock_outline_rounded,
          color: MortColors.lightBlue,
          title: 'Private by design',
          message:
              'MORT uses your birthday for the 13+ age gate and account rules. Other marketplace users never see it.',
        ),
        const SizedBox(height: MortSpacing.lg),
        Form(
          child: DateOfBirthField(
            controller: _dob,
            enabled: !_busy && !_restoring,
            onSubmitted: (_) => _next(),
          ),
        ),
        if (age != null && age < 13) ...[
          const SizedBox(height: MortSpacing.md),
          const _OnboardingNotice(
            icon: Icons.block_rounded,
            color: MortColors.danger,
            title: 'MORT is for ages 13 and older',
            message: 'An account cannot be created for someone under 13.',
          ),
        ] else if (age != null && age < 18) ...[
          const SizedBox(height: MortSpacing.md),
          const _OnboardingNotice(
            icon: Icons.verified_user_outlined,
            color: MortColors.success,
            title: 'Teen account',
            message:
                'You will see age-appropriate jobs and MORT safety tools. Guardian Mode stays optional.',
          ),
        ] else if (age != null) ...[
          const SizedBox(height: MortSpacing.lg),
          Text(
            'What will you use MORT for?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'You can post local work as an adult or supervise a teen as a guardian.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.sm,
            runSpacing: MortSpacing.sm,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.work_outline_rounded, size: 18),
                label: const Text('Post or hire'),
                selected: !_adultWantsGuardianRole,
                onSelected: (_) => _setAdultGuardianChoice(false),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.supervisor_account_outlined, size: 18),
                label: const Text('Supervise as guardian'),
                selected: _adultWantsGuardianRole,
                onSelected: (_) => _setAdultGuardianChoice(true),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProfileStep(Profile? liveProfile) {
    return Column(
      key: const ValueKey('onboarding-profile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnboardingNotice(
          icon: Icons.visibility_outlined,
          color: MortColors.lightBlue,
          title: 'This is what people see',
          message:
              'Use a display name you are comfortable sharing. Your username must be unique.',
        ),
        const SizedBox(height: MortSpacing.lg),
        MortTextField(
          label: 'Display name',
          hint: 'How your name appears in MORT',
          controller: _displayName,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortTextField(
          label: 'Username',
          hint: 'Choose a unique username',
          controller: _username,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.username],
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 30,
          onFieldSubmitted: (_) => _next(),
        ),
        if (liveProfile != null) ...[
          const SizedBox(height: MortSpacing.lg),
          Text(
            'Profile photo (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.sm),
          ProfileAvatarEditor(profile: liveProfile),
        ],
      ],
    );
  }

  Widget _buildAreaStep() {
    final isTeen = _role == UserRole.teen;
    return Column(
      key: const ValueKey('onboarding-area'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OnboardingNotice(
          icon: Icons.location_on_outlined,
          color: MortColors.lightBlue,
          title: isTeen ? 'Exact location stays private' : 'General area only',
          message: isTeen
              ? 'MORT stores a general area for matching. Your home address and raw coordinates are not put on your marketplace profile.'
              : 'City and state help MORT show relevant local activity without asking for a street address.',
        ),
        const SizedBox(height: MortSpacing.lg),
        if (isTeen) ...[
          MortButton(
            label: 'Use my current general area',
            icon: Icons.my_location_rounded,
            style: MortButtonStyle.secondary,
            busy: _busy,
            busyLabel: 'Finding general area',
            onPressed: _requestApproximateLocation,
          ),
          if (_locationHint != null) ...[
            const SizedBox(height: MortSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _locationHint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: MortColors.lightBlueSoft,
                ),
              ),
            ),
          ],
          const SizedBox(height: MortSpacing.md),
          const _OnboardingDivider(label: 'or enter it yourself'),
          const SizedBox(height: MortSpacing.md),
          MortTextField(
            label: 'ZIP or city',
            hint: 'For example, 46204 or Indianapolis',
            controller: _zip,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: MortSpacing.lg),
          Text(
            'How do you usually get around?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            'Choose any that apply. This helps keep job suggestions realistic.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: MortSpacing.sm,
            runSpacing: MortSpacing.sm,
            children: [
              _buildTravelMethodChip(
                'walking',
                'Walking',
                Icons.directions_walk,
              ),
              _buildTravelMethodChip('bicycle', 'Bicycle', Icons.pedal_bike),
              _buildTravelMethodChip('car', 'Car', Icons.directions_car),
              _buildTravelMethodChip(
                'public_transit',
                'Transit',
                Icons.directions_bus,
              ),
              _buildTravelMethodChip(
                'rideshare',
                'Rideshare',
                Icons.local_taxi,
              ),
            ],
          ),
        ] else ...[
          MortTextField(
            label: 'City',
            controller: _city,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.addressCity],
          ),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(
            label: 'State',
            hint: 'Two-letter abbreviation',
            controller: _state,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            maxLength: 2,
            autofillHints: const [AutofillHints.addressState],
            onFieldSubmitted: (_) => _next(),
          ),
        ],
      ],
    );
  }

  Widget _buildInterestsStep() {
    return Column(
      key: const ValueKey('onboarding-interests'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What kind of work interests you?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MortSpacing.sm),
        Wrap(
          spacing: MortSpacing.sm,
          runSpacing: MortSpacing.sm,
          children: _suggestedCategories
              .map((category) {
                return FilterChip(
                  label: Text(category),
                  selected: _categories.contains(category),
                  onSelected: (selected) => _toggleCategory(category, selected),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: MortSpacing.md),
        MortTextField(
          label: 'Other interests',
          hint: 'Separate multiple interests with commas',
          controller: _interestController,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _syncTypedCategories,
        ),
        const SizedBox(height: MortSpacing.lg),
        MortGlassCard(
          infoAccent: true,
          semanticLabel: 'MORT safety guidance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: MortColors.lightBlueSoft,
                  ),
                  const SizedBox(width: MortSpacing.sm),
                  Expanded(
                    child: Text(
                      'Safety comes first',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.md),
              const _SafetyRule(text: 'Keep job conversations inside MORT.'),
              const _SafetyRule(
                text: 'Never share passwords, login codes, or payment codes.',
              ),
              const _SafetyRule(
                text:
                    'Use check-ins and Safety Ping when something does not feel right.',
              ),
              const Divider(height: MortSpacing.lg),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: MortColors.success,
                title: const Text('I reviewed this safety guidance'),
                subtitle: const Text(
                  'Report and block tools remain free for every account.',
                ),
                value: _safetyAcknowledged,
                onChanged: _busy
                    ? null
                    : (checked) {
                        if (checked == null) return;
                        setState(() {
                          _safetyAcknowledged = checked;
                          _dirtySteps.add(_step);
                          _stepError = null;
                        });
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(Profile? liveProfile) {
    final interests = _categories.isEmpty
        ? 'None selected'
        : _categories.join(', ');
    return Column(
      key: const ValueKey('onboarding-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: liveProfile == null
              ? const CircleAvatar(
                  radius: 44,
                  backgroundColor: MortColors.roseGoldDeep,
                  child: Icon(
                    Icons.check_rounded,
                    color: MortColors.roseGoldLight,
                    size: 42,
                  ),
                )
              : ProfileAvatarView(
                  profileId: liveProfile.id,
                  avatarPath: liveProfile.avatarPath,
                  avatarUpdatedAt: liveProfile.avatarUpdatedAt,
                  fallbackLabel: _displayName.text.isEmpty
                      ? 'MORT'
                      : _displayName.text,
                  radius: 44,
                ),
        ),
        const SizedBox(height: MortSpacing.md),
        Text(
          _displayName.text.isEmpty
              ? 'Your setup is ready to review'
              : 'Looking good, ${_displayName.text.trim()}',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: MortSpacing.lg),
        MortCard(
          child: Column(
            children: [
              _ReviewRow(label: 'Account', value: _roleLabel),
              _ReviewRow(
                label: 'Username',
                value: _username.text.trim().isEmpty
                    ? 'Not provided'
                    : '@${_username.text.trim().toLowerCase()}',
              ),
              _ReviewRow(label: 'General area', value: _reviewArea),
              _ReviewRow(label: 'Interests', value: interests),
              const _ReviewRow(label: 'Safety guidance', value: 'Reviewed'),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Edit profile',
              icon: Icons.edit_outlined,
              onPressed: () => _goToStep(1),
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: 'Edit area',
              icon: Icons.location_on_outlined,
              onPressed: () => _goToStep(2),
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: 'Edit interests',
              icon: Icons.interests_outlined,
              onPressed: () => _goToStep(3),
              style: MortButtonStyle.ghost,
            ),
          ],
        ),
        const SizedBox(height: MortSpacing.md),
        MortGlassCard(
          infoAccent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'MORT verifies your current legal acknowledgements before setup can finish.',
              ),
              const SizedBox(height: MortSpacing.sm),
              MortActionRow(
                actions: [
                  MortAction(
                    label: 'Terms',
                    icon: Icons.description_outlined,
                    onPressed: () => context.push('/legal/terms'),
                    style: MortButtonStyle.secondary,
                  ),
                  MortAction(
                    label: 'Privacy',
                    icon: Icons.privacy_tip_outlined,
                    onPressed: () => context.push('/legal/privacy'),
                    style: MortButtonStyle.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(Profile? liveProfile) => switch (_step) {
    0 => _buildAgeStep(),
    1 => _buildProfileStep(liveProfile),
    2 => _buildAreaStep(),
    3 => _buildInterestsStep(),
    _ => _buildReviewStep(liveProfile),
  };

  Widget _buildBottomActions() {
    const primaryLabels = [
      'Choose account',
      'Save profile',
      'Save area',
      'Review setup',
      'Finish setup',
    ];
    final busyLabel = _restoring
        ? 'Restoring setup'
        : _step == _totalSteps - 1
        ? 'Finishing setup'
        : 'Saving step';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MortColors.bgSecondary.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: MortColors.lineStrong)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: MortSpacing.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MortSpacing.md,
                MortSpacing.sm,
                MortSpacing.md,
                MortSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 21;
                  final stackActions = constraints.maxWidth < 340 || largeText;
                  final primary = MortButton(
                    label: primaryLabels[_step],
                    icon: _step == _totalSteps - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    busy: _busy || _restoring,
                    busyLabel: busyLabel,
                    onPressed: _restoring ? null : _next,
                  );
                  if (_step == 0) return primary;

                  final back = MortButton(
                    label: 'Back',
                    icon: Icons.arrow_back_rounded,
                    style: MortButtonStyle.ghost,
                    onPressed: _busy ? null : _back,
                  );
                  if (stackActions) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        back,
                        const SizedBox(height: MortSpacing.xs),
                        primary,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: back),
                      const SizedBox(width: MortSpacing.sm),
                      Expanded(flex: 2, child: primary),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProfile = ref.watch(currentProfileProvider).value;
    return MortScreen(
      scrollController: _scrollController,
      onWillPop: _handleSystemBack,
      bottom: _buildBottomActions(),
      children: [
        MortHeader(
          eyebrow: 'Step ${_step + 1} of $_totalSteps',
          title: _stepTitles[_step],
          subtitle: _stepDescriptions[_step],
          showBackButton: false,
        ),
        Semantics(
          label: 'Onboarding progress: step ${_step + 1} of $_totalSteps',
          value: '${((_step + 1) / _totalSteps * 100).round()} percent',
          child: MortStepper(current: _step, total: _totalSteps),
        ),
        const SizedBox(height: MortSpacing.lg),
        if (_restoring) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: MortSpacing.sm),
          Text(
            'Restoring your saved setup...',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MortSpacing.lg),
        ],
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: _buildStepContent(liveProfile),
        ),
        if (_stepError != null) ...[
          const SizedBox(height: MortSpacing.md),
          _OnboardingNotice(
            key: ValueKey(_stepError),
            icon: Icons.error_outline_rounded,
            color: MortColors.danger,
            title: 'Check this step',
            message: _stepError!,
            liveRegion: true,
          ),
        ],
        if (_legalAcceptanceRequired) ...[
          const SizedBox(height: MortSpacing.md),
          const _OnboardingNotice(
            icon: Icons.gavel_outlined,
            color: MortColors.warning,
            title: 'Legal acknowledgement required',
            message:
                'Open Terms and Privacy above, accept the current published versions, then try Finish setup again.',
            liveRegion: true,
          ),
        ],
        const SizedBox(height: MortSpacing.xl),
      ],
    );
  }
}

class _OnboardingNotice extends StatelessWidget {
  const _OnboardingNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.liveRegion = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: MortCard(
        color: color.withValues(alpha: 0.12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: MortSpacing.xxs),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingDivider extends StatelessWidget {
  const _OnboardingDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MortSpacing.sm),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SafetyRule extends StatelessWidget {
  const _SafetyRule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: MortColors.success,
            size: 20,
          ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
