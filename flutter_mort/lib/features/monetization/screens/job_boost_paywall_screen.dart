import 'paywall_screen.dart';

class JobBoostPaywallScreen extends RevenueCatPaywallScreen {
  const JobBoostPaywallScreen({super.key})
    : super(
        placement: 'job-boost',
        title: 'Boost a job safely.',
        subtitle:
            'Boosts are optional adult/business perks. They never bypass moderation, safety rules, or verification.',
      );
}
