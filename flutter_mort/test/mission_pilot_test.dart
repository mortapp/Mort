import 'package:flutter_mort/data/models/mission_pilot.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mission pilot contracts', () {
    test('parses hosted closed-pilot truth without broadening claims', () {
      final dashboard = MissionPilotDashboard.fromMap({
        'mission': 'Help teenagers gain safe pathways toward adulthood.',
        'pilot_eligibility': {
          'allowed': false,
          'code': 'closed_pilot_requirements_missing',
          'missing_requirements': ['approved_partner_enrollment'],
          'reason_codes': ['pilot_enrollment_missing'],
          'guardian_mode_optional': true,
          'permanent_address_required': false,
          'real_document_collection_enabled': false,
        },
        'discreet_mode': {'enabled': true},
        'support_circle': {
          'enabled': false,
          'optional': true,
          'affects_eligibility': false,
        },
        'active_goal_count': 2,
        'reviewed_resource_count': 4,
        'document_review': {
          'ready': false,
          'real_document_collection_enabled': false,
          'client_can_enable': false,
          'required_gate_count': 18,
          'passed_gate_count': 0,
          'remaining_gate_keys': ['legal_privacy_review'],
          'truth_statement':
              'Visual review does not by itself prove legal identity.',
        },
      });

      expect(dashboard.eligibility.allowed, isFalse);
      expect(dashboard.eligibility.guardianModeOptional, isTrue);
      expect(dashboard.eligibility.permanentAddressRequired, isFalse);
      expect(dashboard.documentReadiness.clientCanEnable, isFalse);
      expect(
        dashboard.documentReadiness.realDocumentCollectionEnabled,
        isFalse,
      );
      expect(dashboard.activeGoalCount, 2);
    });

    test('partner attestation keeps an explicit non-established fact', () {
      final attestation = PartnerAttestation.fromMap({
        'id': '00000000-0000-4000-8000-000000000001',
        'fact_type': 'school_affiliation',
        'version': 2,
        'status': 'active',
        'statement': 'School affiliation confirmed.',
        'what_was_not_established': 'Government identity was not established.',
      });

      expect(attestation.statement, 'School affiliation confirmed.');
      expect(
        attestation.whatWasNotEstablished,
        contains('Government identity'),
      );
    });
  });

  group('no-address profile behavior', () {
    Profile profile(String mode) => Profile.fromMap({
      'id': '00000000-0000-4000-8000-000000000002',
      'role': 'teen',
      'display_name': 'Pilot teen',
      'username': 'pilot-teen',
      'dob': '2010-06-01',
      'city': null,
      'state': null,
      'location_setup_mode': mode,
      'onboarding_completed': true,
      'account_status': 'active',
      'verification_status': 'not_started',
      'payment_preference': 'none',
      'guardian_setup_status': 'skipped',
    });

    test('partner-supported setup does not need city and state', () {
      final supported = profile('partner_supported');
      final cityRequired = profile('city_state');

      expect(supported.city, isNull);
      expect(supported.state, isNull);
      expect(supported.locationSetupMode, 'partner_supported');
      expect(
        supported.completionRatio,
        greaterThan(cityRequired.completionRatio),
      );
    });

    test('location mode does not add a housing-status model field', () {
      final deferred = profile('location_deferred');

      expect(deferred.locationSetupMode, 'location_deferred');
      expect(deferred.isTeen, isTrue);
    });
  });
}
