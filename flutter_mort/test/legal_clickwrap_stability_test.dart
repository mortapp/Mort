import 'package:flutter/material.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/features/legal/legal_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingLegalRepository extends LegalContractRepository {
  int versionLoads = 0;

  @override
  Future<Map<String, dynamic>> publishedLegalVersion(String versionId) async {
    versionLoads += 1;
    return {
      'id': versionId,
      'version_label': 'draft-qa',
      'content_hash': 'synthetic-hash',
      'content_markdown': 'Synthetic legal content for widget QA.',
    };
  }
}

void main() {
  testWidgets('consent form edits do not refetch the exact legal version', (
    tester,
  ) async {
    final repository = _CountingLegalRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legalContractRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: LegalClickwrapScreen(
            versionId: 'version-qa',
            title: 'QA terms',
            signatureRequired: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.versionLoads, 1);

    await tester.tap(
      find.text('I reviewed the teen plain-language summary first'),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Teen Tester');
    await tester.pump();
    await tester.ensureVisible(
      find.text('I affirmatively agree to this exact version'),
    );
    await tester.tap(find.text('I affirmatively agree to this exact version'));
    await tester.pump();

    expect(repository.versionLoads, 1);
    expect(find.text('Version draft-qa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
