class ProfileSafetyService {
  ProfileSafetyService._();
  static final ProfileSafetyService instance = ProfileSafetyService._();

  static const _reservedUsernames = {
    'admin',
    'support',
    'mort',
    'moderator',
    'staff',
    'help',
    'safety',
    'official',
    'null',
    'undefined',
    'deleted',
    'unknown',
  };

  bool isUsernameValid(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length < 3 || trimmed.length > 20) return false;
    final valid = RegExp(r'^[A-Za-z0-9_]+$');
    if (!valid.hasMatch(trimmed)) return false;
    return !_reservedUsernames.contains(trimmed.toLowerCase());
  }

  String? usernameValidationMessage(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return 'Enter a username to continue.';
    }
    if (trimmed.length < 3 || trimmed.length > 20) {
      return 'Usernames must be 3–20 characters.';
    }
    final valid = RegExp(r'^[A-Za-z0-9_]+$');
    if (!valid.hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscore are allowed.';
    }
    if (_reservedUsernames.contains(trimmed.toLowerCase())) {
      return 'That username is reserved. Please choose another one.';
    }
    return null;
  }

  bool isBioValid(String bio) {
    if (bio.trim().length > 160) return false;
    final lower = bio.toLowerCase();
    if (RegExp(r'\b\d{3}[-\.\s]?\d{3}[-\.\s]?\d{4}\b').hasMatch(lower)) {
      return false;
    }
    if (RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b').hasMatch(lower)) return false;
    if (RegExp(r'\b(?:cash app|cashapp|venmo|zelle|paypal)\b').hasMatch(lower)) {
      return false;
    }
    if (RegExp(r'[@#][A-Za-z0-9_]{2,}').hasMatch(lower)) return false;
    if (RegExp(
      r'\b\d{1,5} [A-Za-z0-9]+ (?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Boulevard|Blvd|Court|Ct|Drive|Dr)\b',
    ).hasMatch(lower)) {
      return false;
    }
    return true;
  }

  String? bioValidationMessage(String bio) {
    if (bio.trim().length > 160) {
      return 'Bio must be 160 characters or less.';
    }
    final lower = bio.toLowerCase();
    if (RegExp(r'\b\d{3}[-\.\s]?\d{3}[-\.\s]?\d{4}\b').hasMatch(lower)) {
      return 'Please do not share phone numbers in your bio.';
    }
    if (RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.-]+\b').hasMatch(lower)) {
      return 'Please do not share email addresses in your bio.';
    }
    if (RegExp(
      r'\b(?:cash app|cashapp|venmo|zelle|paypal)\b',
    ).hasMatch(lower)) {
      return 'Please keep payment handles out of your bio.';
    }
    if (RegExp(r'[@#][A-Za-z0-9_]{2,}').hasMatch(lower)) {
      return 'Please keep social handles and contact info out of your bio.';
    }
    if (RegExp(
      r'\b\d{1,5} [A-Za-z0-9]+ (?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Boulevard|Blvd|Court|Ct|Drive|Dr)\b',
    ).hasMatch(lower)) {
      return 'Please do not share exact addresses in your bio.';
    }
    return null;
  }
}
