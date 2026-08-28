/// Shared, single-source copy for MORT's mandatory rules/safety
/// acknowledgement content. The production `CompactOnboardingScreen` and
/// legacy reference screens share these constants so legal-adjacent wording
/// cannot drift while old deployed clients remain supported server-side.
class MortRulesCopy {
  const MortRulesCopy._();

  static const pilotTermsTitle = 'Marketplace participation notice';
  static const pilotTermsBody =
      'I understand marketplace access depends on account, role, job, and '
      'safety requirements and may be restricted when those requirements are not met.';

  static const privacyTitle = 'Privacy notice';
  static const privacyBody =
      'I will not share exact addresses, payment credentials, government '
      'IDs, or private contact details in profiles, chat, proof, or '
      'support.';

  static const communityTitle = 'Community rules';
  static const communityBody =
      'I will communicate respectfully and use report, block, and Safety '
      'Ping when something is unsafe.';

  static const prohibitedTitle = 'Prohibited work';
  static const prohibitedBody =
      'I understand unsafe tools, sexual services, controlled substances, '
      'weapons, overnight teen work, and unlawful work are prohibited.';

  static const safetyRulesTitle = 'Core safety rules';
  static const safetyRulesBody =
      'I will stop work, leave, and seek emergency help when necessary '
      'instead of relying on MORT as an emergency service.';

  static const antiGroomingTitle =
      'Zero tolerance for grooming and exploitation';
  static const antiGroomingBody =
      'MORT has zero tolerance for adults who target, groom, '
      'or attempt sexual contact with a minor through this '
      'app. MORT does not support and will never protect '
      'predators, groomers, or anyone seeking sexual contact '
      'with a minor.\n\n'
      'If an adult account is found doing this, MORT will '
      'preserve account, device, and IP evidence and refer it '
      'to law enforcement. The adult may be permanently '
      'banned and, if the minor\'s family pursues civil or '
      'criminal action, may be held financially responsible '
      'for resulting legal costs. MORT is not liable for the '
      'actions of individual users but will cooperate fully '
      'with any resulting investigation.\n\n'
      'Report anything that feels wrong immediately using '
      'Report or Safety Ping -- reporting never requires '
      'proof and is never held against you.';
  static const antiGroomingAcceptLabel = 'I have read and agree to this rule';
  static const antiGroomingAcceptSubtitle = 'Required to continue using MORT.';
}
