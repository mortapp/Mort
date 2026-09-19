import '../payments/models/fair_pay.dart';

enum JobCreationStep {
  basics('Job basics'),
  workDetails('Work details'),
  schedule('Schedule'),
  location('Location and travel'),
  payment('Payment'),
  safety('Safety and requirements'),
  preview('Preview'),
  publish('Publish');

  const JobCreationStep(this.title);

  final String title;
}

class MortJobCreationFairPayGate {
  const MortJobCreationFairPayGate._();

  static bool canContinue(MortFairPayAssessment? assessment) =>
      assessment != null &&
      assessment.backendAuthoritative &&
      !assessment.blocksContinue &&
      (assessment.status != MortFairPayStatus.yellow ||
          assessment.yellowMayContinue);

  static bool canPublish(MortFairPayAssessment? assessment) =>
      canContinue(assessment);
}

const jobCreationSteps = JobCreationStep.values;

JobCreationStep jobCreationStepAt(int index) {
  final safeIndex = index.clamp(0, jobCreationSteps.length - 1);
  return jobCreationSteps[safeIndex];
}
