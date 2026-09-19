import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/legal/contract_payment_screens.dart';
import 'package:flutter_mort/features/payments/models/payment_state.dart';

void main() {
  test('manual worker acknowledgement cannot manufacture provider success', () {
    final state = mortPaymentStateForObligations(const [
      {'status': 'worker_confirmed_received'},
    ], providerEnabled: true);

    expect(state, isNot(MortPaymentState.succeeded));
    expect(state, MortPaymentState.pending);
  });
}
