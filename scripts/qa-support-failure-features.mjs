import fs from 'node:fs';

const manifestPath = 'C:/temp/mort_support_failure_manifest.json';
const outPath = 'C:/temp/mort_support_failure_features.json';

const data = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

const features = data.map((item) => {
  const key = String(item.caseKey ?? '');
  const group = String(item.group ?? '');
  const normalized = key.toLowerCase();
  return {
    caseKey: key,
    group,
    hasNegation: /negat|not asking|not a request|do not|don't|never|won't|would not/i.test(normalized),
    hasQuestionForm: /how do i|what should i do|can i|could i|where do i|why|when|is that suspicious|what is/i.test(normalized),
    hasQuotedContext: /quoted|quote|reported|example|message|comment|conversation/i.test(normalized),
    hasReportingContext: /report|block|unsafe|safety|harass|abuse|threat|scam/i.test(normalized),
    hasEducationalContext: /benign|education|learn|explain|what is|how do i|how can i|support/i.test(normalized),
    hasAccountContext: /account|login|password|verify|verification|guardian|profile|identity|email/i.test(normalized),
    hasJobContext: /job|application|listing|search|pin|distance/i.test(normalized),
    hasGuardianContext: /guardian/i.test(normalized),
    hasSafetyContext: /safety|report|block|unsafe|threat|harass|abuse/i.test(normalized),
    hasRetrievalIntent: /show|give|reveal|dump|print|share|read back|send|copy|display|return/i.test(normalized),
    hasInternalTarget: /prompt|developer|system prompt|service role|secret|token|key|instructions|rules/i.test(normalized),
    hasSecretTarget: /secret|password|verification|pin|cvv|api key|service role|token|ssn|passport|card/i.test(normalized),
    hasCrossUserTarget: /another user|other user|someone else|different user|cross user|other person's/i.test(normalized),
    hasSensitiveDisclosure: /sensitive|private|profile|address|transcript|messages|data|disclosure/i.test(normalized),
    hasImmediateDangerContext: /urgent|immediate|danger|threat|gun|knife|weapon|assault|rape|kidnap|self harm/i.test(normalized),
  };
});

fs.writeFileSync(outPath, JSON.stringify(features, null, 2));
console.log(`feature_count=${features.length}`);
