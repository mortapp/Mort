import 'package:flutter/material.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import '../models/receipt_document.dart';
import '../widgets/receipt_document_view.dart';

class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, this.receiptNumber, this.document});

  final String? receiptNumber;
  final MortReceiptDocument? document;

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Immutable record',
          title: 'Receipt detail',
          subtitle:
              'This document renders backend-supplied financial truth and cannot be edited.',
        ),
        if (document == null)
          MortErrorState(
            title: 'Receipt backend unavailable',
            message:
                'MORT cannot resolve receipt ${receiptNumber ?? ''} from an authorized receipt backend.',
          )
        else
          MortReceiptDocumentView(document: document!),
      ],
    );
  }
}
