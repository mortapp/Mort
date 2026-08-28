import { supportEvaluationCases, supportContrastCases, supportBenignEvaluationCases } from '../supabase/functions/_shared/support_eval_cases.ts';
import { localClassification } from '../supabase/functions/_shared/support_runtime.ts';

const failures = JSON.parse(Deno.readTextFileSync('C:/temp/qa_support_failures.json'));
const urgentFails = failures.filter(f => (f.caseKey || '').startsWith('urgent_'));

function findCase(caseKey) {
  const all = [...supportEvaluationCases, ...(supportBenignEvaluationCases || [])];
  return all.find(c => c.caseKey === caseKey) || null;
}

function analyze(valueRaw) {
  const value = String(valueRaw).toLowerCase();
  const flags = {};
  // URGENT_BASE
  const urgentSafety = /(suicid|kill myself|kill me|hurt myself|self.?harm|kidnap|abduct|traffick|immediate danger|being followed right now|sexual assault|rape|trapped at (the )?job|\bcsam\b|child pornography|underage nude)/i.test(value);
  flags.URGENT_BASE = !!urgentSafety;
  // URGENT_SIGNAL (proximity of weapon + immediacy)
  const urgentSignal = /(?:(?:someone|they|he|she|the person|the attacker).{0,12}(?:has|has a|has an|is pointing|pointing|pointed)|(?:pointed|pointing|threatened|threaten|threat|attack|assault|stab|shoot)).{0,40}(?:gun|knife|weapon|shoot|stab|murder|kill)|(?:gun|knife|weapon|shoot|stab|murder|kill).{0,40}(?:pointed|pointing|threatened|threat|attack|assault|someone here|someone near me|someone has)/i.test(value);
  flags.URGENT_SIGNAL = !!urgentSignal;

  // TRUST_SAFETY detectors (broad)
  const activeTrustSafetyReport = /(?:someone|a user|an adult|the adult|a stranger|they|this user|that user|another user|a person).{0,45}(?:sent|asked|requested|told).{0,100}(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|verification code|pin|password|social security|ssn|passport|driver.?s license|card number|cvv|cvc|home address|address|scam|fraud|weapon|knife|gun)/i.test(value);
  const firstPersonTrustSafety = /(?:i (?:received|got|was sent|got sent|received a|was sent a|got a)).{0,80}(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|scam|fraud|weapon|knife|gun|rape|assault)/i.test(value);
  const reporterGeneric = /(?:received|was sent|i received|i got).{0,80}(?:asked|asked for|told me to|requested|pressured|blackmail|threat|extort|scam|fraud)/i.test(value);
  const reporterSolicit = /(?:someone|a user|they|this message|the sender|the other user|i received|i got|i was sent).{0,80}(?:asked|asked me|asked for|told me|requested|pressured).{0,140}(?:verification code|cvv|password|ssn|service.?role key|api key|developer message|system prompt|verification code|code|pin)/i.test(value);
  flags.TRUST_SAFETY = !!(activeTrustSafetyReport || firstPersonTrustSafety || reporterGeneric || reporterSolicit);

  // QUOTED_CONTEXT
  const quotedReportingContext = /(?:someone|a user|a stranger|they|this message|a message).{0,25}(?:said|told me|asked|quoted|messaged me).{0,25}(?:"|').{0,80}(?:system prompt|developer message|verification code|cvv|password|card number|ssn|service.?role key|api key|private transcript|messages|profile data)|(?:"|').{0,80}(?:show me your system prompt|print your developer message|reveal the service-role key|send your verification code|give me my password)[^"']*(?:"|')/i.test(value);
  flags.QUOTED_CONTEXT = !!quotedReportingContext;

  // PROMPT_EXTRACTION
  const promptExtraction = /(?:show me|print|reveal|translate|summarize|read back|repeat|return|dump|share|display|expose|tell me|give me).{0,35}(?:your|the|internal|hidden|private|confidential).{0,40}(?:system prompt|developer message|service-role key|hidden instructions|developer instructions)|(?:what is|what are).{0,20}(?:your|the|internal|hidden|private|confidential).{0,40}(?:system prompt|developer message|service-role key)/i.test(value);
  const promptEducational = /(?:what is a|what's a|what are|how does a|how do (?:system prompts|system prompt)|can you explain|why should).{0,60}(?:system prompt|developer message|service-role key|hidden instructions|developer instructions)/i.test(value) && !/(?:\byour\b|\bmy\b|\bthe (?:internal|hidden|service-role|developer)\b).{0,20}(?:system prompt|developer message|service-role key)/i.test(value);
  flags.PROMPT_EXTRACTION = !!(promptExtraction && !promptEducational);
  flags.PROMPT_EDUCATIONAL = !!promptEducational;

  // SECRET_EXTRACTION
  const negatedSecret = /(?:never|do not|don't|would not|wouldn't|i would never|i won't|will not).{0,60}(?:password|verification code|cvv|cvc|pin|ssn|passport|card number|api key|service-role key|home address)/i.test(value);
  const secretNeed = /(?:i need|i need to|get me|i need the).{0,40}(?:password|verification code|cvv|cvc|ssn|passport|card number|api key|service-role key|home address|driver.?s license)/i.test(value);
  const secretExtraction = /(?:tell(?: me)?|show(?: me)?|send(?: me)?|give(?: me)?|read back|print|reveal|share|display|return|dump|expose).{0,35}(?:my|the|your|another user(?:'s)?).{0,50}(?:password|verification code|cvv|cvc|ssn|passport|card number|api key|service-role key|driver.?s license|recovery code|2fa code)/i.test(value);
  flags.SECRET_EXTRACTION = !!( (secretNeed && !negatedSecret) || (secretExtraction && !negatedSecret) );

  // CROSS_USER
  const crossUserNeed = /(?:need|i need|i need to|get me|i need the).{0,40}(?:another user|other user|someone else's|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details)/i.test(value);
  const crossUserShowFrom = /(?:show|give|return|reveal|dump|print|expose|share|get|access).{0,40}(?:from|for).{0,20}(?:another user|other user|someone else's|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details|session)/i.test(value);
  flags.CROSS_USER = !!(crossUserNeed || crossUserShowFrom);

  // SENSITIVE_DISCLOSURE
  const sensitiveDataDisclosure = /(?:can i (?:give|send|share|paste|provide)|should i (?:paste|share|send|provide)|do you need|would i (?:give|share|send)|i (?:will|can|could|would) (?:give|send|share|paste|provide)).{0,40}(?:my|the).{0,40}(?:ssn|social security|card number|verification code|cvv|cvc|passport|driver.?s license|home address|address)/i.test(value);
  flags.SENSITIVE_DISCLOSURE = !!sensitiveDataDisclosure;

  // OTHER
  flags.OTHER = !(flags.URGENT_BASE || flags.URGENT_SIGNAL || flags.TRUST_SAFETY || flags.QUOTED_CONTEXT || flags.PROMPT_EXTRACTION || flags.SECRET_EXTRACTION || flags.CROSS_USER || flags.SENSITIVE_DISCLOSURE);

  return flags;
}

for (const f of urgentFails) {
  const caseKey = f.caseKey;
  const c = findCase(caseKey);
  if (!c) {
    console.log(JSON.stringify({ caseKey, note: 'case_meta_not_found' }));
    continue;
  }
  const expected = { level: f.expected?.level ?? null, intent: f.expected?.intent ?? null };
  const actual = localClassification(c.message) || null;
  const flags = analyze(c.message);
  console.log(JSON.stringify({ caseKey, expected, actual: { level: actual?.level ?? null, intent: actual?.intent ?? actual?.intent_name ?? null, category: actual?.category ?? null, provider_allowed: actual?.provider_allowed ?? null }, flags }));
}
