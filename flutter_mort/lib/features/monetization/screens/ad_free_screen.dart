import 'paywall_screen.dart';

class AdFreeScreen extends RevenueCatPaywallScreen {
  const AdFreeScreen({super.key})
    : super(
        placement: 'ad-free',
        title: 'Go ad-free.',
        subtitle:
            'Hide eligible ads while keeping safety, reports, messages, and basic jobs free.',
      );
}
