import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../config/app_config.dart';

const playReviewerIdentifier = 'play-review@mortapp.test';
const reviewerStartPin = '123456';
const reviewerCompletionPin = '654321';

enum ReviewerRole { teen, adult, guardian, support, admin }

extension ReviewerRoleDetails on ReviewerRole {
  String get label => switch (this) {
    ReviewerRole.teen => 'Teen',
    ReviewerRole.adult => 'Adult',
    ReviewerRole.guardian => 'Guardian',
    ReviewerRole.support => 'Support',
    ReviewerRole.admin => 'Admin',
  };

  String get route => '/review/$name';
}

String normalizeReviewerIdentifier(String value) {
  return value
      .replaceFirst(RegExp(r'^[\x09-\x0D\x20]+'), '')
      .replaceFirst(RegExp(r'[\x09-\x0D\x20]+$'), '');
}

bool isExactPlayReviewerIdentifier(String value, {bool? reviewerModeEnabled}) {
  if (!(reviewerModeEnabled ?? AppConfig.playReviewModeEnabled)) return false;
  final normalized = normalizeReviewerIdentifier(value);
  if (normalized.runes.any((rune) => rune > 0x7f)) return false;
  return normalized == playReviewerIdentifier;
}

String? rejectReservedPlayReviewerIdentifier(
  String? value, {
  bool? reviewerModeEnabled,
}) {
  if (value != null &&
      isExactPlayReviewerIdentifier(
        value,
        reviewerModeEnabled: reviewerModeEnabled,
      )) {
    return 'This identifier is reserved for Google Play review.';
  }
  return null;
}

final reviewerModeEnabledProvider = Provider<bool>(
  (ref) => AppConfig.playReviewModeEnabled,
);

final reviewerSessionProvider = ChangeNotifierProvider<ReviewerSession>((ref) {
  return ReviewerSession(
    reviewerModeEnabled: ref.watch(reviewerModeEnabledProvider),
  );
});

class ReviewerSession extends ChangeNotifier {
  ReviewerSession({required bool reviewerModeEnabled})
    : _reviewerModeEnabled = reviewerModeEnabled;

  final bool _reviewerModeEnabled;
  bool _active = false;
  ReviewerRole _selectedRole = ReviewerRole.teen;
  final Set<String> _completedActions = <String>{};
  bool _startPinAccepted = false;
  bool _completionPinAccepted = false;
  bool _syntheticProofAttached = false;
  int _paymentStateIndex = 0;

  static const paymentStates = <String>[
    'Payment method ready',
    'Authorization pending',
    'Authorized',
    'Capture pending',
    'Paid',
    'Partial compensation',
    'Refund pending',
    'Payout pending',
    'Payout complete',
    'Authentication required',
    'Payment failed',
  ];

  bool get isActive => _active;
  ReviewerRole get selectedRole => _selectedRole;
  Set<String> get completedActions => Set.unmodifiable(_completedActions);
  bool get startPinAccepted => _startPinAccepted;
  bool get completionPinAccepted => _completionPinAccepted;
  bool get syntheticProofAttached => _syntheticProofAttached;
  String get paymentState => paymentStates[_paymentStateIndex];

  bool start({
    required String identifier,
    required bool productionSessionPresent,
  }) {
    if (productionSessionPresent ||
        !isExactPlayReviewerIdentifier(
          identifier,
          reviewerModeEnabled: _reviewerModeEnabled,
        )) {
      return false;
    }
    _active = true;
    _selectedRole = ReviewerRole.teen;
    _completedActions.clear();
    _startPinAccepted = false;
    _completionPinAccepted = false;
    _syntheticProofAttached = false;
    _paymentStateIndex = 0;
    notifyListeners();
    return true;
  }

  void selectRole(ReviewerRole role) {
    if (!_active || _selectedRole == role) return;
    _selectedRole = role;
    notifyListeners();
  }

  void toggleAction(String actionId) {
    if (!_active) return;
    if (!_completedActions.add(actionId)) {
      _completedActions.remove(actionId);
    }
    notifyListeners();
  }

  bool confirmStartPin(String value) {
    if (!_active) return false;
    _startPinAccepted = value == reviewerStartPin;
    notifyListeners();
    return _startPinAccepted;
  }

  bool confirmCompletionPin(String value) {
    if (!_active) return false;
    _completionPinAccepted = value == reviewerCompletionPin;
    notifyListeners();
    return _completionPinAccepted;
  }

  void attachSyntheticProof() {
    if (!_active) return;
    _syntheticProofAttached = true;
    _completedActions.add('teen-proof-upload');
    notifyListeners();
  }

  void advanceSyntheticPayment() {
    if (!_active) return;
    _paymentStateIndex = (_paymentStateIndex + 1) % paymentStates.length;
    notifyListeners();
  }

  void exit() {
    _active = false;
    _selectedRole = ReviewerRole.teen;
    _completedActions.clear();
    _startPinAccepted = false;
    _completionPinAccepted = false;
    _syntheticProofAttached = false;
    _paymentStateIndex = 0;
    notifyListeners();
  }
}
