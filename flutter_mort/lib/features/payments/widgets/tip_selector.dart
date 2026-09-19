import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import '../models/tipping.dart';

class MortTipSelector extends StatefulWidget {
  const MortTipSelector({
    super.key,
    required this.basePayCents,
    this.onChanged,
    this.tipPolicy,
  });

  final int basePayCents;
  final ValueChanged<MortTipSelection>? onChanged;
  final MortTipPolicy? tipPolicy;

  @override
  State<MortTipSelector> createState() => _MortTipSelectorState();
}

class _MortTipSelectorState extends State<MortTipSelector> {
  MortTipPreset _preset = MortTipPreset.none;
  final _customController = TextEditingController();

  int get _amount {
    switch (_preset) {
      case MortTipPreset.none:
        return 0;
      case MortTipPreset.two:
        return 200;
      case MortTipPreset.five:
        return 500;
      case MortTipPreset.ten:
        return 1000;
      case MortTipPreset.tenPercent:
      case MortTipPreset.fifteenPercent:
      case MortTipPreset.twentyPercent:
        return MortTipSelection.percentage(
          _preset,
          widget.basePayCents,
        ).amountCents;
      case MortTipPreset.custom:
      case MortTipPreset.lateTip:
        return parseMortCurrencyToCents(_customController.text) ?? 0;
    }
  }

  MortTipValidation get _customValidation =>
      validateMortCustomTip(_customController.text, widget.tipPolicy);

  void _select(MortTipPreset value) {
    setState(() => _preset = value);
    widget.onChanged?.call(
      MortTipSelection(preset: value, amountCents: _amount),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = <MortTipPreset, String>{
      MortTipPreset.none: 'No tip',
      MortTipPreset.two: r'$2',
      MortTipPreset.five: r'$5',
      MortTipPreset.ten: r'$10',
      MortTipPreset.tenPercent: '10%',
      MortTipPreset.fifteenPercent: '15%',
      MortTipPreset.twentyPercent: '20%',
      MortTipPreset.custom: 'Custom',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tip 100% to the teen'),
        const SizedBox(height: MortSpacing.xs),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: _preset == option.key,
                onSelected: (_) => _select(option.key),
              ),
          ],
        ),
        if (_preset == MortTipPreset.custom) ...[
          const SizedBox(height: MortSpacing.sm),
          TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,$]')),
            ],
            onChanged: (_) => _select(MortTipPreset.custom),
            decoration: const InputDecoration(
              labelText: 'Custom tip',
              hintText: r'$7.50',
            ),
          ),
          Text(_customFeedback(_customValidation)),
        ],
        const SizedBox(height: MortSpacing.xs),
        const Text(
          'Tips are excluded from the MORT service fee and Fair Pay calculation.',
        ),
      ],
    );
  }

  String _customFeedback(MortTipValidation validation) =>
      switch (validation.state) {
        MortTipValidationState.empty => 'Enter a custom tip amount.',
        MortTipValidationState.typing => '',
        MortTipValidationState.invalid =>
          'Use a valid currency amount with no more than 2 decimals.',
        MortTipValidationState.tooLow =>
          'This tip is below the configured minimum.',
        MortTipValidationState.tooHigh =>
          'This tip is above the configured maximum.',
        MortTipValidationState.valid when !validation.policyAvailable =>
          'Tip limits are unavailable. Confirmation is disabled.',
        MortTipValidationState.valid => 'Tip amount is ready to confirm.',
      };
}
