import 'package:flutter/material.dart';

import '../../services/ad_service.dart';
import '../../theme/mort_theme.dart';
import '../../widgets/safe_sponsored_card.dart';

class SafeAdsPreviewScreen extends StatelessWidget {
  const SafeAdsPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final campaigns = AdService.instance.mockCampaigns;
    return Scaffold(
      backgroundColor: MortTheme.background,
      appBar: AppBar(
        title: const Text('Safe ads preview'),
        backgroundColor: MortTheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Mock-only, labeled, non-personalized sponsored cards',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ads stay visible, safe, and limited to approved placements. They do not appear in safety, emergency, verification, or reporting flows.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ...campaigns.map(
            (campaign) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SafeSponsoredCard(campaign: campaign),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: MortTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Safety guardrails',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• No personalized ads for teens',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '• No unsafe categories',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '• No ads in safety-critical flows',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '• Live ad network activation remains disabled',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
