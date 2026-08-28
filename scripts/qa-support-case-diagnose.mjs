import {
  supportBenignEvaluationCases,
  supportContrastCases,
  supportEvaluationCases,
} from "../supabase/functions/_shared/support_eval_cases.ts";
import { localClassification } from "../supabase/functions/_shared/support_runtime.ts";

if (!Deno.args || Deno.args.length === 0) {
  console.error(
    "Usage: deno run --allow-read scripts/qa-support-case-diagnose.mjs CASE_ID [CASE_ID...]",
  );
  Deno.exit(2);
}
const caseIds = Deno.args;

// Read failures JSON to get expected if available
let failures = [];
try {
  const raw = Deno.readTextFileSync("C:/temp/qa_support_failures.json");
  failures = JSON.parse(raw);
} catch (e) {
  // ignore if missing
}
const allCases = [
  ...(supportEvaluationCases || []),
  ...(supportContrastCases || []),
  ...(supportBenignEvaluationCases || []),
];
// Feature detectors (boolean flags)
function flagsForMessage(msg) {
  const value = String(msg).toLowerCase();
  const flags = {};
  flags.HAS_WEAPON_SIGNAL = /\b(?:gun|knife|weapon)\b/i.test(value);
  flags.HAS_VIOLENCE_SIGNAL =
    /\b(?:kill|murder|stab|shoot|attack|assault|threaten|threat)\b/i.test(
      value,
    );
  flags.HAS_PRESENT_TIME_SIGNAL =
    /\b(?:here|right now|now|immediate|currently|at the moment|in immediate danger)\b/i
      .test(value);
  flags.HAS_LOCATION_SIGNAL =
    /\b(?:here|near me|at the job|at work|in the car|in this area|at the location)\b/i
      .test(value);
  flags.HAS_NEGATION =
    /\b(?:not|never|don't|do not|wouldn't|would not|no longer)\b/i.test(value);
  flags.HAS_QUOTED_CONTEXT = /["'].*["']/.test(msg);
  flags.HAS_REPORTER_CONTEXT =
    /(?:i received|i was sent|was sent|received a message|got a message|they told me|asked me)/i
      .test(value);
  flags.HAS_HYPOTHETICAL_CONTEXT = /\b(?:what if|if i|hypothetical|imagine)\b/i
    .test(value);
  flags.HAS_EDUCATIONAL_CONTEXT =
    /\b(?:how do i|what is|can you explain|why should)\b/i.test(value);

  // URGENT_BASE: direct self-harm or explicit immediate harm phrases
  flags.URGENT_BASE_MATCH =
    /(?:suicid|kill myself|hurt myself|self.?harm|immediate danger|being followed right now|trapped at (the )?job|\bcsam\b|child pornography|underage nude)/i
      .test(value);
  // URGENT_SIGNAL: weapon/violence proximity + present/location
  flags.URGENT_SIGNAL_MATCH =
    (/(?:\b(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack|assault)\b).{0,40}(?:here|right now|now|immediate|trapped|at the job|at work|near me|in this area)/i
      .test(value)) ||
    (/((?:here|right now|now|immediate|trapped|at the job|at work|near me|in this area).{0,40}(?:\b(?:gun|knife|weapon|shoot|stab|murder|kill|threaten|attack|assault)\b))/i
      .test(value));
  // TRUST_SAFETY broad detectors
  flags.TRUST_SAFETY_MATCH =
    /(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|verification code|pin|password|social security|ssn|passport|card number|cvv|cvc|home address|address|scam|fraud|weapon|knife|gun)/i
      .test(value);
  flags.ACTIVE_TRUST_SAFETY =
    /(someone|a user|an adult|the adult|a stranger|they|this user|that user|the poster|the other user|another user|a person).{0,45}(?:sent|sends|sent me|keeps|keep|continued to|continue to|is trying to|are trying to|is attempting to|are attempting to|asked me|asked for|asked me for|requested|requested my|wanted me to|want me to|want to|wants me to|wants|told me|told me to|told me not to|told a teen|told the teen|said|said to|made me|pressured me|kept|need me to|asked to see|asked to view).{0,100}(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|verification code|pin|password|social security|ssn|passport|driver.?s license|card number|cvv|cvc|home address|address|cashapp|gift card|move.*off-platform|off-platform|private data|messages|transcript|profile data|keep this a secret|secret|scam|fraud|weapon|knife|gun|alcohol|circular saw|no supervision|unsafe|alone|rape|assault)/i
      .test(value);
  flags.FIRST_PERSON_TRUST_SAFETY =
    /(?:i (?:received|got|was sent|got sent|received a|was sent a|got a)).{0,80}(?:threat|stalk|harass|blackmail|extort|nude|sexual|sexual message|private photo|scam|fraud|weapon|knife|gun|rape|assault|pressured|asked for|requested|asked me to|asked for my|requested my)/i
      .test(value);
  flags.UNSAFE_JOB =
    /(?:feel unsafe|unsafe at).{0,40}(?:job|work|at the job|at work)/i.test(
      value,
    );
  flags.REPORTER_GENERIC =
    /(?:received|got a message|i received|i got|was sent|dmed|dm|received a|got a message).{0,80}(?:asked|asked for|asked me to|told me to|told me|requested|requested my|pressured|pressured me|blackmail|threat|extort|scam|fraud|asked that)/i
      .test(value);
  flags.SCAM_INDICATOR =
    /(looks like a scam|this looks like a scam|scam or fraud|this is a scam|possible scam|suspected fraud)/i
      .test(value);
  flags.DATABASE_DUMP =
    /(?:dump|dump the|dump the profiles|return all database|dump.*table|dump profiles|return all rows|dump the table|export.*database|different conversation|other conversation|different transcript|other transcript)/i
      .test(value);
  flags.START_FINISH_SOLICIT =
    /(?:send me|give me|send|please send).{0,40}(?:finish code|start code|finish pin|start pin|finish code before|send the finish code)/i
      .test(value);
  flags.REPORTER_SOLICIT =
    /(?:someone|a user|they|this message|a message|the sender|the other user|i received|i got|i was sent|received a message|got a message|dm|dmed).{0,80}(?:asked|asked me|asked for|asked that i|told me to|told me|requested|requested my|wanted me to|want me to|pressured me|tried to make me).{0,140}(?:verification code|cvv|cvc|password|card number|ssn|social security|service.?role key|api key|private transcript|messages|profile data|developer message|system prompt|code|pin|finish pin|start pin)/i
      .test(value);
  flags.SECURITY_OVERRIDE =
    /((ignore|disregard|forget|override|bypass|replace|reset|discard|remove|skip|break).{0,60}(?:previous|earlier|all|your|the).{0,60}(?:instructions|guidelines|rules|developer instructions)|for this reply only|developer mode|ignore everything above|forget everything above|no restrictions|new system message)/i
      .test(value);
  flags.AUTHORITY_IMPERSONATION =
    /(as the system administrator|as an admin|mort staff|mort developer|developer mode|authorized override|this is an authorized override|i am (mort )?(staff|developer|admin|administrator))/i
      .test(value);
  flags.HAS_RETRIEVAL_VERB =
    /\b(?:tell(?: me)?|show(?: me)?|send(?: me)?|give(?: me)?|read(?: back)?|print|reveal|share|display|return|dump|expose|provide|what(?:'s| is| are)|can you|could you|would you)\b/i
      .test(value);
  flags.HAS_SECRET_NOUN =
    /\b(?:password|verification code|otp|one[- ]time code|one time code|one[- ]time passcode|passcode|pass code|pass-code|cvv|cvc|pin|ssn|passport|card number|api key|api token|secret key|service[- ]role key|service role key|recovery code|2fa code)\b/i
      .test(value);
  flags.CROSS_USER_NEED =
    /(?:need|i need|i need to|get me|i need the).{0,40}(?:another user|other user|someone else's|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details)/i
      .test(value);
  flags.SECRET_NEED =
    /(?:i need|i need to|get me|i need the|i need my).{0,40}(?:password|verification code|otp|one[- ]time code|one time code|one[- ]time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service[- ]role key|service role key|home address|driver(?:'?s)? license|recovery code|2fa code)/i
      .test(value);
  flags.SECRET_EXTRACTION =
    /(?:tell(?: me)?|show(?: me)?|send(?: me)?|give(?: me)?|read(?: back)?|print|reveal|share|display|return|dump|expose|provide).{0,35}(?:my|the|your|another user(?:'s)?|someone else(?:'s)?).{0,50}(?:password|verification code|otp|one[- ]time code|one time code|one[- ]time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service[- ]role key|service role key|home address|driver.?s license|recovery code|2fa code)|(?:what(?:'s| is| are)|can you|could you|would you).{0,25}(?:the|my|your).{0,20}(?:password|verification code|otp|one[- ]time code|one time code|one[- ]time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service[- ]role key|service role key|home address|driver.?s license|recovery code|2fa code)|(?:password|verification code|otp|one[- ]time code|one time code|one[- ]time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service[- ]role key|service role key|home address|driver.?s license|recovery code|2fa code).{0,35}(?:for me|to me|right now|please|now|you use|on file|that is on file|here)/i
      .test(value);
  flags.CROSS_USER_DATA =
    /(?:show|give|return|reveal|dump|print|expose|share|get|access).{0,20}(?:me|us).{0,20}(?:another user|other user|someone else|a different user|every user).{0,60}(?:messages|transcript|profile|account|records|data|details)|(?:show|return|reveal|dump|print|expose|share|get|access).{0,40}(?:another user|other user|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details)|(?:another user|other user|someone else).{0,60}(?:private|profile|account|messages|transcript|records|data|details).{0,50}(?:show|give|return|reveal|dump|print|expose|access|share|get)/i
      .test(value);
  flags.HAS_INTERNAL_TARGET =
    /\b(?:your|the|internal|hidden|private|confidential)\b.{0,30}\b(?:prompt|system prompt|system message|system instruction|developer message|developer instruction|service[- ]role key|hidden instruction|private instruction|confidential instruction|rules|operating rules)s?\b/i
      .test(value) ||
    /\b(?:prompt|system prompt|system message|system instruction|developer message|service[- ]role key|developer instruction|rules)s?\b.{0,35}\b(?:show|print|reveal|read back|repeat|return|dump|display|expose)\b/i
      .test(value);
  flags.DIRECT_PROMPT_TARGET =
    /(?:your (?:system )?prompt|your hidden instructions|your internal instructions|the developer message|the system prompt|the service[- ]role key|the (?:hidden|internal|confidential) instructions)/i
      .test(value);
  flags.PROMPT_EDUCATIONAL =
    /(?:what is a|what's a|how does a|how do (?:system prompts|system prompt)|can you explain what a|why (?:are|should)|what does (?:prompt extraction|prompt injection)|in general terms|normal purpose|difference between).{0,100}(?:system prompt|developer message|service[- ]role key|hidden instructions|developer instructions|prompt extraction|prompt injection|internal instructions|private rules)/i
      .test(value) ||
    /(?:without|not).{0,25}(?:revealing|exposing|showing|sharing).{0,40}(?:(?:your|the) )?(?:internal )?(?:prompt|instructions|rules|message|key)/i
      .test(value);
  flags.QUOTED_EXAMPLE =
    /(?:i saw|someone|a user|a stranger|they|friend|review|comment|post|message|chat|conversation).{0,35}(?:said|quoted|wrote|shared|pasted|sent|posted|messaged|commented).{0,35}["']|(?:quote|quoted|example|for example).{0,40}(?:system prompt|developer message|verification code|password|cvv|cvc|api key|service[- ]role key|transcript|messages|profile data|database|instructions|rules|account details|account)/i
      .test(value);
  flags.BENIGN_REPORTING =
    /(?:how should i report|what should i do|is that suspicious).{0,40}(?:prompt[- ]injection|prompt extraction|attack)|(?:i saw|someone|a user|a stranger|they|friend).{0,35}(?:ask(?:ed)? for|asked|told me|requested|sent|said).{0,40}(?:system prompt|developer message|service-role key|verification code|password|cvv|api key|private transcript|cvc|ssn).{0,40}(?:should i report|what should i do|is that suspicious|scam)/i
      .test(value);
  flags.BENIGN_PROMPT_EDUCATION =
    /(?:how do i|why should(?: i)?|where do i|what is a|what's a|what does|what are|can you explain|why are|how does|how can i|what should i do|can i|should i|is that suspicious|ask a question about).{0,60}(?:system prompt|developer message|developer instructions|prompt extraction|internal instructions|hidden instructions)/i
      .test(value);
  flags.BENIGN_CONTEXT_BOUNDARY =
    /(?:not asking|not a request|not asking for|not (?:for|trying to perform) (?:a )?(?:jailbreak|bypass|prompt extraction)|don.?t want to (?:see|access|get)|not to (?:send|make)|public (?:job )?safety guide|in training.{0,40}(?:understand|what))/i
      .test(value);
  flags.HUMAN_SUPPORT =
    /(?:\bhuman\b|real person|support agent|talk to (?:a )?person|contact support|support hours|schedule a call|phone number|screenshot for help|support topic|follow up on|existing ticket|payment question from support|explain a problem to support|support message|support.*escalated|email support|support resources|support usually take)/i
      .test(value);
  flags.SAFETY_CENTER_SUPPORT =
    /(?:safety center|safety.*(?:center|settings|policy|guidelines)|report.*(?:user|message)|block.*(?:profile|user)|where is the report button|how do i report|how do i block|how do i review my safety settings|how do i contact support about a safety issue|what is the difference between reporting and blocking|safety settings|safety policy|safety guidelines|feel uncomfortable|uncomfortable.*(?:job|work)|job seems unsafe|unsafe.*(?:job|work)|help.*(?:unsafe|safety)|safety issue|safety concern|support.*safety|report.*or.*block|block.*someone)/i
      .test(value);
  flags.SAFETY_FALLBACK =
    /(?:how do i report|where is the report button|i want to block|report a user|block this profile|report a message|block someone|blocked users|report someone|report inappropriate conduct|safety center|feel unsafe|unsafe.*job|job seems unsafe|hide exact addresses|safety settings|safety guidelines|safety issue|uncomfortable at a job|safety policy|submit a report|undo a report|safer job practices|unsafe work environment)/i
      .test(value);
  flags.HAS_REPORT = /(?:^|[^a-z0-9_])report(?:ed|ing|s)?(?:$|[^a-z0-9_])/i
    .test(value);
  flags.HAS_BLOCK = /(?:^|[^a-z0-9_])block(?:ed|ing|s)?(?:$|[^a-z0-9_])/i.test(
    value,
  );
  flags.HAS_SUPPORT = /(?:^|[^a-z0-9_])support(?:$|[^a-z0-9_])/i.test(value);
  flags.HAS_USER_TARGET = /(?:user|profile|someone|person|account)/i.test(
    value,
  );
  flags.HAS_MESSAGE_TARGET = /(?:message|chat|conversation|comment|content)/i
    .test(value);
  flags.HAS_TICKET_CONTEXT = /(?:ticket|follow up|existing|status)/i.test(
    value,
  );
  flags.SAFETY_FALLBACK_SIGNALS = [
    [
      "report_flow",
      /(?:how do i report|where is the report button|report a user|report a message|report someone|report inappropriate conduct|submit a report|undo a report)/i,
    ],
    [
      "block_flow",
      /(?:i want to block|block this profile|block someone|blocked users)/i,
    ],
    [
      "safety_area",
      /(?:safety center|safety settings|safety guidelines|safety issue|safety policy)/i,
    ],
    [
      "unsafe_flow",
      /(?:feel unsafe|unsafe.*job|job seems unsafe|uncomfortable at a job|unsafe work environment)/i,
    ],
    ["privacy_safety", /(?:hide exact addresses|safer job practices)/i],
  ].filter(([, pattern]) => pattern.test(value)).map(([name]) => name);
  flags.UNSAFE_FLOW_SIGNALS = [
    ["feel_unsafe", /feel unsafe/i],
    ["unsafe_job", /unsafe.*job/i],
    ["job_seems_unsafe", /job seems unsafe/i],
    ["uncomfortable_job", /uncomfortable at a job/i],
    ["unsafe_environment", /unsafe work environment/i],
  ].filter(([, pattern]) => pattern.test(value)).map(([name]) => name);

  return flags;
}

const output = caseIds.map((caseId) => {
  const failureMeta = failures.find((failure) => failure.caseKey === caseId) ||
    null;
  const caseMeta = allCases.find((candidate) => candidate.caseKey === caseId) ||
    null;
  if (!caseMeta) {
    return {
      caseKey: caseId,
      error: "case_not_found_locally",
      foundInFailures: !!failureMeta,
    };
  }

  const actualRaw = localClassification(caseMeta.message) || null;
  return {
    caseKey: caseId,
    expected: {
      level: caseMeta.expectedLevel ?? caseMeta.level ??
        caseMeta.expected?.level ?? null,
      intent: caseMeta.expectedIntent ?? caseMeta.intent ??
        caseMeta.expected?.intent ?? null,
    },
    actual: {
      level: actualRaw?.level ?? null,
      intent: actualRaw?.intent ?? actualRaw?.intent_name ?? null,
      category: actualRaw?.category ?? null,
      provider_allowed: actualRaw?.provider_allowed ?? null,
    },
    featureFlags: flagsForMessage(caseMeta.message),
  };
});

console.log(JSON.stringify(output.length === 1 ? output[0] : output, null, 2));
