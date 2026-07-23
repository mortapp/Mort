import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test(
    'MORT Guide uses authenticated server calls and deterministic FAQ mode',
    () {
      final repository = _read(
        'lib/data/repositories/mort_guide_repository.dart',
      );
      final edge = _read('../supabase/functions/ai-support/index.ts');
      final migration = _read(
        '../supabase/migrations/20260722042500_mort_guide_foundation.sql',
      );

      expect(
        repository,
        contains("client.functions.invoke(\n      'ai-support'"),
      );
      expect(edge, contains('auth.getUser(token)'));
      expect(edge, contains('store: false'));
      expect(edge, contains('omni-moderation-latest'));
      expect(edge, contains('ask_mort_guide_faq'));
      expect(migration, contains("default 'faq_only'"));
      expect(migration, contains('force row level security'));
      expect(edge, isNot(contains('userId: body')));
      expect(edge, isNot(matches(RegExp(r'sk-[A-Za-z0-9]'))));
    },
  );

  test(
    'MORT Guide UI has safety, privacy, history, and human support paths',
    () {
      final screen = _read('lib/features/guide/mort_guide_screens.dart');
      final router = _read('lib/core/routing/app_router.dart');

      for (final widget in [
        'MortGuideEntryButton',
        'MortGuideView',
        'MortGuideMessageBubble',
        'MortGuideSuggestedQuestions',
        'MortGuideSourceCard',
        'MortGuideSafetyEscalation',
        'MortGuideFeedbackSheet',
        'MortGuidePrivacySheet',
        'MortGuideHistoryView',
        'MortGuideDeleteHistoryView',
      ]) {
        expect(screen, contains('class $widget'));
      }
      expect(screen, contains('AI may make mistakes'));
      expect(screen, contains("route: '/support'"));
      expect(router, contains("'/guide/history'"));
    },
  );
}
