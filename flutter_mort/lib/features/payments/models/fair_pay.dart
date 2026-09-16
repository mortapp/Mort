import 'package:flutter/material.dart';

enum MortFairPayStatus { green, yellow, red }

class MortFairPayAssessment {
  const MortFairPayAssessment({
    required this.recommendedRangeCents,
    required this.hardMinimumCents,
    required this.actualCents,
    this.backendAuthoritative = true,
    this.yellowMayContinue = false,
  });

  final RangeValues recommendedRangeCents;
  final int hardMinimumCents;
  final int actualCents;
  final bool backendAuthoritative;
  final bool yellowMayContinue;

  MortFairPayStatus get status {
    if (actualCents < hardMinimumCents) {
      return MortFairPayStatus.red;
    }
    if (actualCents >= recommendedRangeCents.start &&
        actualCents <= recommendedRangeCents.end) {
      return MortFairPayStatus.green;
    }
    return MortFairPayStatus.yellow;
  }

  bool get blocksContinue => status == MortFairPayStatus.red;

  bool get isRecommended => status == MortFairPayStatus.green;

  int get recommendedFloorCents => recommendedRangeCents.start.round();

  int get recommendedCeilingCents => recommendedRangeCents.end.round();
}
