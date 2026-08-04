import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mort_spacing.dart';
import '../../core/utils/date_of_birth.dart';
import '../../core/widgets/date_of_birth_field.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/onboarding_progress.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

class CompactOnboardingScreen extends ConsumerStatefulWidget {
  const CompactOnboardingScreen({super.key});

  @override
  ConsumerState<CompactOnboardingScreen> createState() =>
      _CompactOnboardingScreenState();
}

class _CompactOnboardingScreenState
    extends ConsumerState<CompactOnboardingScreen> {
  int _step = 0;
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
  bool _safetyAcknowledged = false;
  bool _busy = false;
  bool _legalAcceptanceRequired = false;
  String? _locationHint;

  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    try {
      final progress = await ref
          .read(profileRepositoryProvider)
          .getOnboardingProgress();
      _applyProgress(progress);
    } catch (_) {
      // continue with blank state if progress cannot be loaded.
    }
  }

  void _applyProgress(OnboardingProgress progress) {
    if (!mounted) return;
    final stepMap = {
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
    setState(() {
      _step = stepMap[progress.currentStep] ?? 0;
      if (progress.resumePath.contains('/onboarding/age')) {
        _step = 0;
      } else if (progress.resumePath.contains('/onboarding/role') ||
          progress.resumePath.contains('/onboarding/profile')) {
        _step = 1;
      } else if (progress.resumePath.contains('/onboarding/transportation')) {
        _step = 2;
      } else if (progress.resumePath.contains('/onboarding/safety') ||
          progress.resumePath.contains('/onboarding/review')) {
        _step = 3;
      }
      _role = ref.read(currentProfileProvider).value?.role;
    });
  }

  @override
  void dispose() {
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
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        MortToast.show(
          context,
          'Allow location permission or enter an approximate ZIP/city.',
        );
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        MortToast.show(context, 'Enable location services to use this option.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _zip.text =
          'near ${position.latitude.toStringAsFixed(2)}, '
          '${position.longitude.toStringAsFixed(2)}';
      _locationHint =
          'Approximate location saved without sharing exact address.';
      MortToast.show(
        context,
        'Approximate location saved without sharing your exact address.',
      );
    } catch (_) {
      if (!mounted) return;
      MortToast.show(
        context,
        'Unable to access location. Use ZIP/city instead.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    _legalAcceptanceRequired = false;
    try {
      final repo = ref.read(profileRepositoryProvider);
      final now = DateTime.now();
      switch (_step) {
        case 0:
          final dob = DateOfBirthParser.tryParse(_dob.text, today: now);
          if (dob == null) throw Exception('Enter a valid date of birth.');
          final age = DateOfBirthParser.ageOn(dob, now);
          if (age < 13) {
            MortToast.show(context, 'MORT is blocked for users under 13.');
            return;
          }
          _role = age < 18 ? UserRole.teen : UserRole.adult;
          await repo.saveOnboardingAge(dob);
          await repo.saveOnboardingRole(_role!);
          break;
        case 1:
          final displayName = _displayName.text.trim();
          final username = _username.text.trim().toLowerCase();
          if (displayName.isEmpty) {
            throw Exception('Enter a display name to continue.');
          }
          if (username.isEmpty) {
            throw Exception('Enter a username to continue.');
          }
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
            if (approximateArea.isEmpty && _transportMethods.isEmpty) {
              throw Exception(
                'Enter a ZIP/city or choose how you usually get around.',
              );
            }
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
            if (city.isEmpty || state.length != 2) {
              throw Exception(
                'Enter a city and two-letter state for your adult account.',
              );
            }
            final dob = DateOfBirthParser.tryParse(_dob.text, today: now);
            if (dob == null) throw Exception('Enter a valid date of birth.');
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
          if (_categories.isEmpty) {
            throw Exception('Choose at least one interest.');
          }
          if (!_safetyAcknowledged) {
            throw Exception('Acknowledge the safety guidance to continue.');
          }
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
      if (_step < 4) {
        setState(() => _step++);
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
          MortToast.show(context, message);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Widget _buildTravelMethodChip(String key, String label, IconData icon) {
    final selected = _transportMethods.contains(key);
    return ChoiceChip(
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
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const total = 5;
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Onboarding',
          title: 'Setup — ${_step + 1} of $total',
          subtitle: 'A short, private setup to get you started.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_step == 0) ...[
          const MortCard(
            child: Text('Enter your date of birth to determine eligibility.'),
          ),
          const SizedBox(height: MortSpacing.md),
          Form(child: DateOfBirthField(controller: _dob)),
        ] else if (_step == 1) ...[
          const MortCard(child: Text('Pick a display name and username.')),
          const SizedBox(height: MortSpacing.md),
          MortTextField(label: 'Display name', controller: _displayName),
          const SizedBox(height: MortSpacing.sm),
          MortTextField(label: 'Username', controller: _username),
        ] else if (_step == 2) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _role == UserRole.teen
                      ? 'Share an approximate area and how you usually get around. Exact address is never collected.'
                      : 'Enter the city and state where you will manage jobs and communicate with MORT.',
                ),
                if (_role == UserRole.teen) ...[
                  const SizedBox(height: MortSpacing.sm),
                  const Text(
                    'For teen accounts, MORT keeps your exact address private and matches work by area.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          if (_role == UserRole.teen) ...[
            MortButton(
              label: 'Use my approximate location',
              icon: Icons.my_location,
              busy: _busy,
              onPressed: _requestApproximateLocation,
            ),
            if (_locationHint != null) ...[
              const SizedBox(height: MortSpacing.sm),
              Text(
                _locationHint!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: MortSpacing.sm),
            MortTextField(
              label: 'ZIP or city (manual fallback)',
              controller: _zip,
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
            MortTextField(label: 'City', controller: _city),
            const SizedBox(height: MortSpacing.sm),
            MortTextField(label: 'State (2-letter)', controller: _state),
          ],
        ] else if (_step == 3) ...[
          const MortCard(
            child: Text('Choose your interests and confirm safety guidance.'),
          ),
          const SizedBox(height: MortSpacing.md),
          MortTextField(
            label: 'Interests (e.g. tutoring, yard work)',
            controller: _interestController,
            onChanged: (value) {
              _categories
                ..clear()
                ..addAll(
                  value
                      .split(',')
                      .map((entry) => entry.trim())
                      .where((entry) => entry.isNotEmpty),
                );
            },
          ),
          const SizedBox(height: MortSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I have read the safety guidance.'),
            value: _safetyAcknowledged,
            onChanged: (checked) {
              if (checked == null) return;
              setState(() => _safetyAcknowledged = checked);
            },
          ),
        ] else if (_step == 4) ...[
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary'),
                const SizedBox(height: MortSpacing.sm),
                Text(
                  'Display name: ${_displayName.text.isEmpty ? 'Not provided' : _displayName.text}',
                ),
                Text(
                  'Username: ${_username.text.isEmpty ? 'Not provided' : _username.text}',
                ),
                if (_role == UserRole.teen) ...[
                  Text(
                    'Approximate area: ${_zip.text.isEmpty ? 'Not provided' : _zip.text}',
                  ),
                  Text(
                    'Travel methods: ${_transportMethods.isEmpty ? 'Not provided' : _transportMethods.join(', ')}',
                  ),
                ] else ...[
                  Text(
                    'City: ${_city.text.isEmpty ? 'Not provided' : _city.text}',
                  ),
                  Text(
                    'State: ${_state.text.isEmpty ? 'Not provided' : _state.text.toUpperCase()}',
                  ),
                ],
                Text(
                  'Interests: ${_categories.isEmpty ? 'Not provided' : _categories.join(', ')}',
                ),
                Text(
                  'Safety guidance: ${_safetyAcknowledged ? 'Confirmed' : 'Not confirmed'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.md),
          MortActionRow(
            actions: [
              MortAction(
                label: 'Edit profile',
                icon: Icons.edit,
                onPressed: () => setState(() => _step = 1),
                style: MortButtonStyle.ghost,
              ),
              MortAction(
                label: 'Edit location',
                icon: Icons.location_on,
                onPressed: () => setState(() => _step = 2),
                style: MortButtonStyle.ghost,
              ),
            ],
          ),
        ],
        if (_legalAcceptanceRequired) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'A legal acceptance is required before finishing setup.',
                ),
                const SizedBox(height: MortSpacing.sm),
                MortActionRow(
                  actions: [
                    MortAction(
                      label: 'Terms',
                      route: '/legal/terms',
                      style: MortButtonStyle.secondary,
                    ),
                    MortAction(
                      label: 'Privacy',
                      route: '/legal/privacy',
                      style: MortButtonStyle.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'Back',
              icon: Icons.arrow_back,
              onPressed: _back,
              style: MortButtonStyle.ghost,
            ),
            MortAction(
              label: _step < 4 ? 'Continue' : 'Finish',
              icon: Icons.arrow_forward,
              busy: _busy,
              onPressed: _next,
            ),
          ],
        ),
      ],
    );
  }
}
