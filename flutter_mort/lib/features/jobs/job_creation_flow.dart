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

const jobCreationSteps = JobCreationStep.values;

JobCreationStep jobCreationStepAt(int index) {
  final safeIndex = index.clamp(0, jobCreationSteps.length - 1);
  return jobCreationSteps[safeIndex];
}
