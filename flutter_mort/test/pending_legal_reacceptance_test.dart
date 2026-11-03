import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLegalContractRepository extends LegalContractRepository {
  _FakeLegalContractRepository(this._response);

  final Map<String, dynamic> Function() _response;

  @override
  Future<Map<String, dynamic>> legalRequirements({
    String? expectedUserId,
  }) async => _response();
}

ProviderContainer _containerWith(Map<String, dynamic> Function() response) {
  final container = ProviderContainer(
    overrides: [
      legalContractRepositoryProvider.overrideWithValue(
        _FakeLegalContractRepository(response),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('reports pending when a required document has no acceptance', () async {
    final container = _containerWith(
      () => {
        'requirements': [
          {'document_key': 'terms', 'required': true, 'acceptance_id': null},
        ],
      },
    );

    final pending = await container.read(
      pendingRequiredLegalReacceptanceProvider('user-1').future,
    );

    expect(pending, isTrue);
  });

  test('does not flag an already-accepted required document', () async {
    final container = _containerWith(
      () => {
        'requirements': [
          {
            'document_key': 'terms',
            'required': true,
            'acceptance_id': 'accepted-id',
          },
        ],
      },
    );

    final pending = await container.read(
      pendingRequiredLegalReacceptanceProvider('user-1').future,
    );

    expect(pending, isFalse);
  });

  test('does not flag an outstanding optional document', () async {
    final container = _containerWith(
      () => {
        'requirements': [
          {
            'document_key': 'optional-survey',
            'required': false,
            'acceptance_id': null,
          },
        ],
      },
    );

    final pending = await container.read(
      pendingRequiredLegalReacceptanceProvider('user-1').future,
    );

    expect(pending, isFalse);
  });

  test('preserves lookup errors so the app can require a retry', () async {
    final container = _containerWith(() => throw Exception('offline'));

    await expectLater(
      container.read(pendingRequiredLegalReacceptanceProvider('user-1').future),
      throwsA(isA<Exception>()),
    );
  });
}
