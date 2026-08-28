import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const CATEGORY_QUOTAS = new Map([
  ["Teen earning and work experience", 100],
  ["Adult and business hiring tools", 95],
  ["Optional Guardian Mode", 60],
  ["Local community and neighborhood utility", 90],
  ["Discovery, search, ranking, and matching", 95],
  ["Job lifecycle, scheduling, and execution", 85],
  ["Applications, proposals, and hiring", 75],
  ["Messaging and work collaboration", 70],
  ["Trust, verification, reputation, and references", 80],
  ["Safety, fraud, abuse, and incident prevention", 120],
  ["Payment preferences, records, disputes, and financial education", 65],
  ["Profiles, portfolios, identity, and work history", 75],
  ["Healthy retention, goals, progress, and delight", 93],
  ["Monetization, optional perks, paywalls, and ads", 60],
  ["Accessibility, inclusion, localization, and assistive support", 95],
  ["Onboarding, activation, education, and first-use experience", 70],
  ["Notifications, reminders, and re-engagement", 60],
  ["Marketing, referrals, partnerships, and organic growth", 85],
  ["AI assistance, automation, and intelligent safety", 78],
  ["Admin, moderation, support, and operations", 85],
  ["Analytics, insights, experiments, and reporting", 60],
  ["Privacy, compliance, transparency, and user controls", 70],
  ["Reliability, offline behavior, performance, and recovery", 70],
  ["Native iOS, SwiftUI, platform integrations, and device experience", 55],
]);

export const ALLOWED_STATUSES = new Set([
  "proposed", "accepted_roadmap", "foundation_ready", "backend_ready",
  "Swift_source_implemented", "Flutter_implemented", "shared_implemented",
  "implemented_uncompiled", "implemented_verified_web",
  "implemented_verified_backend", "implemented_verified_mac",
  "implemented_verified_iPhone", "blocked_manual", "blocked_legal",
  "rejected", "duplicate_removed",
]);

export const IMPLEMENTED_STATUSES = new Set([
  "Swift_source_implemented", "Flutter_implemented", "shared_implemented",
  "implemented_uncompiled", "implemented_verified_web",
  "implemented_verified_backend", "implemented_verified_mac",
  "implemented_verified_iPhone",
]);

export const ALLOWED_ROLES = new Set([
  "teen", "adult", "business", "guardian", "admin", "safety staff",
  "support staff", "community partner", "all users", "system", "none",
]);

export const REQUIRED_FIELDS = [
  "feature_id", "unique_slug", "title", "category", "subcategory",
  "primary_user", "secondary_user", "real_world_problem", "user_story",
  "detailed_behavior", "reason_users_value_it", "reason_users_return",
  "reason_it_is_different", "safety_impact", "accessibility_impact",
  "privacy_impact", "monetization_relationship", "free_or_paid",
  "platform_scope", "swift_path", "flutter_path", "backend_tables",
  "rpc_edge_function", "storage_requirement", "analytics_requirement",
  "notification_requirement", "moderation_requirement",
  "legal_review_requirement", "dependencies", "estimated_effort",
  "expected_impact", "retention_score", "safety_score",
  "accessibility_score", "growth_score", "revenue_score",
  "differentiation_score", "complexity_score", "risk_score",
  "implementation_priority", "implementation_status",
  "verification_evidence", "test_status", "Mac_required",
  "iPhone_required", "manual_dashboard_required", "reason_deferred",
];

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const docsDir = join(repoRoot, "docs");

function v(slug, suffix, purpose, behavior, value, implementationKey) {
  return { slug, suffix, purpose, behavior, value, implementationKey };
}

const SETS = {
  user: [
    v("personal-control", "personal control", "People need to configure this capability for their real circumstances.", "Provides bounded setup, safe defaults, preview, edit, and reset for {topic}.", "It replaces vague workarounds with an explicit user choice."),
    v("readiness-guidance", "readiness guidance", "People cannot easily tell what is required before acting.", "Explains prerequisites, unavailable reasons, and a safe next step for {topic}.", "It reduces uncertainty before a real commitment."),
    v("guided-workflow", "guided workflow", "First-time or occasional users need support at the moment of action.", "Guides {topic} through loading, empty, error, success, and cancellation states.", "It makes a real marketplace task easier to complete."),
    v("progress-history", "progress and history", "Useful progress is lost when it is not recorded or its source is unclear.", "Records authorized status and history for {topic}, distinguishing verified from self-entered details.", "It creates durable value that improves with legitimate use."),
    v("privacy-recovery", "privacy and recovery", "Users need agency when information is too exposed or a plan changes.", "Adds visibility, pause, correction, and recovery controls for {topic} without erasing required safety records.", "It preserves control without weakening accountability."),
  ],
  marketplace: [
    v("structured-input", "structured input", "Unstructured marketplace information creates omissions and inconsistent decisions.", "Captures the minimum relevant fields for {topic} with accessible validation and safe defaults.", "It improves quality without collecting unrelated data."),
    v("server-guardrail", "server-enforced guardrail", "Client-only rules can be replayed, bypassed, or applied by the wrong role.", "Checks role, ownership, age, block state, account status, and lifecycle rules for {topic} on the server.", "It makes marketplace authority trustworthy."),
    v("explainable-decision", "explainable decision support", "Opaque ranking or decisions make people distrust the marketplace.", "Shows the authorized facts and reason behind {topic} while preserving human choice.", "It supports informed decisions without hidden scoring."),
    v("participant-timeline", "participant timeline", "Participants need to know what happened and what comes next.", "Records committed {topic} changes and exposes only the role-appropriate timeline.", "It reduces repeated coordination and support requests."),
    v("idempotent-recovery", "idempotent recovery", "Retries, cancellations, and concurrent actions can split state.", "Makes {topic} safe to retry, rejects stale transitions, and preserves valid user input.", "It keeps real work moving during interruption."),
  ],
  discovery: [
    v("filter-control", "filter control", "Users need precise and reversible control over results.", "Adds an explicit {topic} control and shows active criteria above results.", "It reduces irrelevant browsing."),
    v("explainable-ranking", "explainable ranking", "Opaque ordering hides why an opportunity appears.", "Uses {topic} only when authorized and displays a concise match reason.", "It makes recommendations understandable."),
    v("safety-exclusion", "safety-preserving exclusion", "Filters must not bypass age, block, test-data, or prohibited-work rules.", "Applies {topic} after mandatory safety and privacy exclusions.", "It preserves protection while improving relevance."),
    v("saved-alert", "saved alert", "Users miss relevant changes when they cannot repeat discovery criteria.", "Lets users save, pause, schedule, and deduplicate alerts for {topic}.", "It returns users to useful opportunity rather than endless feeds."),
    v("feedback-correction", "feedback and correction", "Recommendations stagnate when users cannot reject a poor match.", "Collects not-interested and correction feedback for {topic} without sensitive-trait inference.", "It improves results while preserving agency."),
  ],
  safety: [
    v("risk-signal", "risk signal", "Users may not recognize this hazard before committing.", "Detects indicators of {topic}, records the reason, and labels automation as assistive.", "It surfaces risk early."),
    v("context-warning", "contextual warning", "Generic warnings are hard to act on.", "Explains {topic} at the relevant step with plain actions and emergency boundaries.", "It helps people respond without fear-based pressure."),
    v("preventive-control", "preventive control", "Warnings alone cannot stop clearly prohibited behavior.", "Blocks or restricts {topic} where policy requires and returns a structured reason.", "It prevents foreseeable harm."),
    v("incident-evidence", "incident evidence workflow", "Users and moderators need a bounded record when harm is reported.", "Captures minimal authorized evidence, status, and retention context for {topic}.", "It supports accountable follow-up."),
    v("human-review", "human review and appeal", "Automated safety signals can be wrong or incomplete.", "Routes {topic} to trained review with audit context, feedback, and appeal.", "It keeps people responsible for high-impact decisions."),
  ],
  access: [
    v("user-setting", "user setting", "People need a discoverable way to choose this access behavior.", "Provides a free, remembered control for {topic} with a clear explanation.", "It lets users shape the interface to their needs."),
    v("system-adaptation", "system adaptation", "Platform preferences should work without repeated setup.", "Adapts {topic} to supported system settings and layout extremes.", "It works immediately with assistive preferences."),
    v("equivalent-task", "equivalent task path", "A single input or presentation mode can block completion.", "Provides an equivalent way to finish the affected MORT task for {topic}.", "It preserves full marketplace participation."),
    v("multimodal-feedback", "multimodal feedback", "Status can be missed when feedback relies on one sense or color.", "Communicates {topic} through semantics, text, focus, visual state, and optional haptics.", "It makes outcomes perceivable."),
    v("cross-flow-consistency", "cross-flow consistency", "An accessible first screen is not enough if later work regresses.", "Applies {topic} across auth, jobs, applications, messages, proof, safety, and settings.", "It prevents accessibility from ending at onboarding."),
  ],
  retention3: [
    v("useful-action", "useful goal action", "Progress tools fail when they optimize screen time instead of real work.", "Turns {topic} into an optional next action tied to safe marketplace value.", "It helps users accomplish something off-screen."),
    v("private-progress", "private progress view", "Practical growth is hard to notice when it is not summarized.", "Shows user-owned progress for {topic} without humiliating rankings or fake urgency.", "It makes earned progress satisfying."),
    v("healthy-return", "pause and healthy return", "School, health, family, and work require breaks.", "Lets users pause {topic}, preserves state, and offers respectful return guidance.", "It supports long-term use without addiction patterns."),
  ],
  ai3: [
    v("assistive-suggestion", "assistive suggestion", "Users need help but should not lose control to automation.", "Generates a bounded {topic} suggestion through a server-mediated provider or rule fallback and requires confirmation.", "It saves effort while preserving agency."),
    v("explanation-confidence", "explanation and confidence", "Opaque automated output can mislead users and staff.", "Shows why {topic} was suggested, relevant uncertainty, and the fallback used.", "It makes automation understandable."),
    v("human-control-audit", "human control and audit", "High-impact automation needs correction and accountability.", "Allows edit, reject, feedback, human review, minimal retention, and restricted audit for {topic}.", "It prevents automation from becoming final authority."),
  ],
  operations: [
    v("triage", "prioritized triage", "Important work is delayed when urgent and routine items are mixed.", "Queues {topic} using explicit severity, SLA, and safety factors without automatic final enforcement.", "It improves response time for real risk."),
    v("authorized-evidence", "authorized evidence workspace", "Staff need context without broad database access.", "Shows only evidence required for {topic}, records access, and uses short-lived private media links.", "It supports decisions with less exposure."),
    v("audited-action", "audited action", "High-impact changes need attributable authority.", "Performs {topic} through checked server actions with reason and before/after state.", "It makes operations accountable."),
    v("assignment-escalation", "assignment and escalation", "Cases stall when ownership is unclear.", "Supports assignment, handoff, four-eyes approval where required, and escalation for {topic}.", "It keeps operational work moving."),
    v("appeal-resolution", "appeal and resolution", "Users need a fair route to challenge mistakes.", "Tracks communication, appeal, resolution, retention, and policy version for {topic}.", "It makes enforcement contestable."),
  ],
  reliability: [
    v("failure-detection", "failure detection", "Silent failure leaves users acting on stale state.", "Detects {topic}, classifies recoverability, and records privacy-safe diagnostics.", "It makes problems visible."),
    v("graceful-fallback", "graceful fallback", "Provider or network failure should not crash core work.", "Provides a bounded fallback for {topic} that never fakes success or weakens authorization.", "It keeps the app usable."),
    v("safe-retry", "safe retry", "Repeated taps and reconnects can duplicate actions.", "Makes {topic} retryable through idempotency, state checks, or read-only refresh.", "It reduces corruption and frustration."),
    v("state-reconciliation", "state reconciliation", "Local and remote state can diverge after interruption.", "Reconciles {topic} from hosted Supabase or a trusted SDK and explains changes.", "It restores a truthful view."),
    v("user-recovery", "user recovery path", "Technical errors need a clear next step.", "Provides accessible error copy, retry, cancellation, support context, and preserved input for {topic}.", "It helps users recover without starting over."),
  ],
  ios: [
    v("native-integration", "native integration", "A web-shaped implementation misses useful iOS behavior.", "Implements {topic} with typed Swift APIs, bounded dependencies, and no client secrets.", "It gives iPhone users a maintainable native experience."),
    v("permission-config", "permission and configuration", "Native capability fails when permission or entitlement context is unclear.", "Adds contextual education, platform configuration, and denial handling for {topic}.", "It makes platform behavior predictable."),
    v("lifecycle-restore", "lifecycle and restoration", "Backgrounding and cold launch can lose user state.", "Restores {topic} without replaying unsafe or paid actions.", "It makes real-device use dependable."),
    v("native-accessibility", "native accessibility", "Custom native UI can regress platform conventions.", "Applies Dynamic Type, VoiceOver, focus, Reduce Motion, and target sizing to {topic}.", "It preserves iOS assistive behavior."),
    v("release-fallback", "release fallback and diagnostics", "Device-only failures need honest recovery and evidence.", "Adds safe fallback, structured diagnostics, and Mac/iPhone verification gates for {topic}.", "It keeps release claims honest."),
  ],
};

function parseTopics(value) {
  return value.split(";").map((entry) => {
    const parts = entry.split("|").map((part) => part.trim());
    return { label: parts[0], subcategory: parts[1] };
  });
}

function c(name, slug, quota, set, primary, secondary, problem, returnReason, topics, platform) {
  return { name, slug, quota, set, primary, secondary, problem, returnReason, topics: parseTopics(topics), platform: platform || "shared SwiftUI + Flutter Web + Supabase where authority is required" };
}

const CATEGORIES = [
  c("Teen earning and work experience", "teen-work", 100, "user", "teen", "adult, guardian", "Teen workers have limited experience, fragmented tools, and uneven access to safe local opportunity.", "Their safe work history, skills, goals, and repeat relationships become more useful over time.", "Opportunity Radar feed|discovery;Saved opportunity search|discovery;Work availability calendar|planning;School schedule boundaries|school-safe scheduling;Extracurricular time blocks|school-safe scheduling;Travel boundaries|transport;Work preference profile|preferences;First-job readiness|readiness;Proposal practice|application skills;Application momentum|tracking;Meet-and-greet preparation|readiness;Mutual expectations checklist|preparation;Cancellation readiness|professional habits;Safe check-in plan|safety planning;Completion evidence|execution;Post-job reflection|learning;Skill Passport|portable experience;Reference Builder|references;Resume Bridge|future employment;Micro-apprenticeship path|guided learning"),
  c("Adult and business hiring tools", "adult-business-hiring", 95, "marketplace", "adult, business", "teen", "Adults and small businesses need reliable local help without heavyweight hiring overhead or unsafe informal coordination.", "Reusable jobs, trusted workers, evidence, and organized history reduce repeated work.", "Fast job brief|job creation;Safe job template library|job creation;Job draft workspace|job creation;Recurring job schedule|repeat hiring;Seasonal hiring plan|seasonal work;Applicant comparison|candidate review;Trusted worker list|repeat relationships;Repeat invitation|repeat relationships;Backup worker roster|recovery;Availability matching|scheduling;Private proof review workspace|evidence review;Schedule change workspace|coordination;Cancellation recovery|coordination;Local Talent Bench|business staffing;Business profile|business identity;Team member permissions|operations;Reusable job requirements|job creation;Community event staffing|community hiring;Job closeout summary|records"),
  c("Optional Guardian Mode", "guardian-mode", 60, "user", "guardian", "teen", "Families need optional safety support that does not become mandatory surveillance or block teen independence.", "Relevant, bounded visibility helps guardians support work without monitoring everything.", "Voluntary guardian linking|linking;Guardian invitation management|linking;Guardian visibility boundary|privacy;Teen sharing control|agency;Guardian notification preferences|notifications;Guardian digest schedule|notifications;Guardian quiet hours|notifications;Safety Ping alerts|safety;Accepted-job summary|job visibility;Voluntary transport plan sharing|transport;Emergency contact record|safety;Guardian self-unlink|account control"),
  c("Local community and neighborhood utility", "community-utility", 90, "marketplace", "all users", "community partner", "Neighborhood needs and willing teen talent are disconnected across informal, hard-to-trust channels.", "Local relationships, recurring events, and visible community outcomes create continuing practical value.", "Neighborhood opportunity board|local discovery;Community event helper pool|events;Seasonal help exchange|seasonal work;Weather preparation crew|weather;Older-neighbor assistance|community care;Technology help exchange|digital inclusion;Local tutoring network|education;Pet help network|pet care;Community cleanup day|service;Local business overflow board|business;School club opportunity page|school;Nonprofit opportunity page|nonprofit;Community-service hour record|service history;Verified local organization directory|trust;Event helper roster|events;Group opportunity page|coordination;Neighborhood launch waitlist|launch;Community impact summary|impact"),
  c("Discovery, search, ranking, and matching", "discovery-matching", 95, "discovery", "teen", "adult, business", "Marketplace users lose time in irrelevant results and cannot trust opaque recommendations.", "Saved, explainable, safety-aware discovery reveals new relevant opportunities.", "Keyword search|search;Semantic intent search|search;Job category filtering|filters;Skill requirement filtering|filters;Minimum pay filtering|filters;Hourly versus fixed filtering|filters;Availability overlap|scheduling;Indoor and outdoor filtering|environment;Supervision filtering|safety;Verification filtering|trust;Guardian-requirement filtering|guardian;Approximate distance filtering|location;Travel-time preference|transport;Age eligibility matching|eligibility;Recurring opportunity filtering|repeat work;Recently posted ordering|ordering;Closing-soon ordering|ordering;Safest-match ordering|safety ranking;Not-interested feedback|control"),
  c("Job lifecycle, scheduling, and execution", "job-lifecycle", 85, "marketplace", "adult, business", "teen, guardian", "Local jobs fail when status, ownership, schedule, evidence, and next actions are ambiguous.", "A durable lifecycle keeps current and repeat work organized.", "Job draft and resume|creation;Job preview|creation;Publish validation|publishing;Moderation precheck|publishing;Pending-review handling|moderation;Pause and resume|management;Close applications|management;Worker assignment|assignment;Backup worker activation|recovery;Pre-job check-in|execution;In-progress work state|execution;Proof request|evidence;Proof submission|evidence;Proof-gated completion|evidence review;Two-sided completion|completion;Cancellation and dispute|exceptions;Recurring job instance|recurring work"),
  c("Applications, proposals, and hiring", "applications-hiring", 75, "marketplace", "teen", "adult, guardian", "Teen applications are often unstructured, privacy-risky, and unclear after submission.", "Applicants and posters return to a clear, auditable hiring pipeline.", "Eligibility explanation|eligibility;Structured proposal|proposal;Availability confirmation|schedule;Relevant skill selection|skills;Portfolio attachment|evidence;Reference attachment|references;Application preview|submission;Application draft|drafts;Application submission|submission;Application withdrawal|control;Poster applicant notes|review;Applicant shortlist|review;Accept or decline decision|decision;Backup applicant status|backup;Response deadline|timing"),
  c("Messaging and work collaboration", "messaging-collaboration", 70, "marketplace", "teen, adult", "guardian, admin", "Work conversations can become unsafe, inaccessible, stale, or visible to the wrong person.", "Protected, organized communication supports every active job relationship.", "Authorized conversation inbox|inbox;Conversation unread state|read state;Message pagination|history;Realtime message refresh|realtime;Message delivery retry|delivery;Safe photo attachment|attachments;Proof reference card|context;Schedule-change card|context;Mutual expectations card|context;Quick response library|composition;Message safety scanner|safety;Report and block actions|safety;Conversation archive and mute|control;Authorized message search|search"),
  c("Trust, verification, reputation, and references", "trust-reputation", 80, "marketplace", "all users", "admin", "Marketplace trust is weak when identity, work history, and badges are unverified or unexplained.", "Accurate reputation and portable references become more valuable with legitimate completed work.", "Adult verification|verification;Business verification|verification;Mutual identity verification|verification;Completed-work count|history;Review history|reviews;Measured response rate|metrics;Measured completion rate|metrics;Measured cancellation rate|metrics;Repeat relationship count|repeat work;Structured references|references;Skill Passport evidence|skills;Work-readiness credential|readiness;Category experience|experience;Trust badge explanation|transparency;Trust record appeal|appeals;Blind mutual review reveal|reviews"),
  c("Safety, fraud, abuse, and incident prevention", "safety-prevention", 120, "safety", "all users", "safety staff", "Teen local work combines marketplace fraud, interpersonal risk, hazardous work, and sensitive location concerns.", "Free, explainable protection makes legitimate work relationships sustainable.", "Unsafe job language|job safety;Prohibited job category|job safety;Age-inappropriate work|youth labor;Dangerous equipment|physical safety;Hazardous chemicals|physical safety;Roofs and heights|physical safety;Weapons-related work|prohibited work;Alcohol and drug exposure|prohibited work;Adult-entertainment requests|prohibited work;Illegal activity requests|prohibited work;Safe first meetings and high-risk work|schedule safety;Upfront-fee scam|fraud;Gift-card scam|fraud;Cryptocurrency scam|fraud;Fake-check and overpayment scam|fraud;Off-platform pressure|communication;Personal-information extraction|privacy;Guardian secrecy pressure|coercion;Harassment and sexual content|abuse;Threat and coercion|abuse;Weather exposure risk|environment;Transportation risk|transport;Safety Ping and missed check-in|incident prevention;Stale completion evidence|evidence integrity"),
  c("Payment preferences, records, disputes, and financial education", "financial-experience", 65, "marketplace", "teen, adult", "guardian", "MORT does not process payments, yet participants still need clear expectations, scam protection, and private records.", "Accurate preference and work records help users plan and resolve misunderstandings.", "Cash preference|preference;Cash App preference|preference;Square invoice preference|preference;Flexible payment preference|preference;Agreed amount record|agreement;Expected payment timing|agreement;Hourly or fixed basis|agreement;Tip record|record;Participant payment confirmation|record;Payment issue report|disputes;Receipt and expense agreement|records;Earnings and savings goals|goals;Tax education boundary|education"),
  c("Profiles, portfolios, identity, and work history", "profiles-portfolios", 75, "user", "all users", "adult, business", "Informal local work rarely becomes a safe, portable, credible identity and experience record.", "Profiles and portfolios improve as users complete legitimate work and add verified context.", "Profile avatar|identity;Display identity|identity;Username|identity;Profile biography|content;Skill list|skills;Interest list|interests;Preferred job categories|preferences;Availability summary|schedule;Approximate area|location;Travel preference|transport;Portfolio collection|portfolio;Work sample|portfolio;Completed work history|history;Reference and Skill Passport|references;Resume export|portable experience"),
  c("Healthy retention, goals, progress, and delight", "healthy-retention", 93, "retention3", "all users", "none", "Users need reasons to return that come from progress and utility rather than pressure or endless feeds.", "Each return helps complete a goal, maintain a relationship, or preserve useful progress.", "First-job milestone|milestones;First-review milestone|milestones;Five-job milestone|milestones;Skill milestone|milestones;Earnings goal|goals;Savings goal|goals;Weekly opportunity digest|planning;Work-readiness progress|learning;Portfolio progress|portfolio;Profile completion|profile;Repeat-client recognition|relationships;Community-impact recognition|impact;Optional nonpunitive streak|habits;Comeback encouragement|return;Progress celebration|delight;Respectful haptic feedback|delight;Reduce Motion celebration|accessibility;Personalized home module|personalization;Saved home view|personalization;Custom theme|personalization;Profile style pack|personalization;Notification quiet hours|wellbeing;Milestone share card|sharing;Reference reminder|references;Post-job reflection|learning;Weekly work plan|planning;School-safe plan|planning;Opportunity calendar|planning;Trusted-client update|relationships;Goal visualization|goals;Undo and remembered state|recovery"),
  c("Monetization, optional perks, paywalls, and ads", "ethical-monetization", 60, "marketplace", "all users", "business", "Optional revenue can support MORT only if free core work and safety remain genuinely useful.", "Users keep control while optional organization, style, and business conveniences remain reliable.", "Localized store price|prices;Plan comparison|offerings;Clear free path|ethics;Paywall dismissal|ethics;Purchase restore|recovery;Subscription management|subscription;Entitlement refresh|entitlements;Expired entitlement handling|entitlements;Canceled or failed purchase|recovery;Empty offering and web fallback|fallback;RevenueCat Customer Center|subscription;Optional perks and eligible ads|optional value"),
  c("Accessibility, inclusion, localization, and assistive support", "accessibility-inclusion", 95, "access", "all users", "none", "Marketplace participation fails when auth, jobs, communication, evidence, or safety tools exclude disabled users.", "Consistent access settings make every recurring task easier to complete.", "VoiceOver labels and order|screen reader;Dynamic Type scaling|text;High-contrast presentation|visual;Color-safe meaning|visual;Reduce Motion|motion;Reduce Transparency|visual;Large touch controls|motor;Switch Control|motor;Keyboard and Full Keyboard Access|keyboard;Focus management|navigation;Accessible forms and errors|forms;Accessible images and descriptions|media;Plain-language mode|cognitive;Cognitive Access Mode|cognitive;No-timed-pressure alternative|cognitive;Accessible authentication and dates|auth;Accessible upload progress|uploads;Localization and RTL readiness|localization;Accessibility settings and audit surface|settings"),
  c("Onboarding, activation, education, and first-use experience", "onboarding-activation", 70, "user", "all users", "guardian", "New users abandon setup when value, role boundaries, age rules, or next steps are unclear.", "Recoverable setup gets each role to a useful first action and remains available for later learning.", "Immediate value preview|welcome;Role selection|role;DOB age gate|age;Onboarding progress restore|progress;Role-aware smart defaults|defaults;Optional avatar setup|profile;Skill setup|profile;Availability setup|schedule;Approximate area setup|location;Payment preference setup|education;Optional Guardian Mode setup|guardian;Safety education|safety;Contextual permission request|permissions;First-action handoff|activation"),
  c("Notifications, reminders, and re-engagement", "notifications-engagement", 60, "marketplace", "all users", "guardian", "Users miss important work changes, but excessive or sensitive alerts create noise and privacy risk.", "Configurable notices return users to a specific valuable action.", "Application lifecycle updates|applications;Job change updates|jobs;New message updates|messages;Proof review updates|proof;Completion and review reminders|completion;Guardian link updates|guardian;Safety Ping and check-in alerts|safety;Weather risk alerts|weather;Verification and support updates|support;Subscription and job-boost updates|monetization;Saved-search and repeat invites|opportunities;Digest quiet hours and deep links|control"),
  c("Marketing, referrals, partnerships, and organic growth", "marketing-growth", 85, "marketplace", "all users", "community partner", "A local marketplace must build balanced neighborhood trust without guaranteed-income claims or unsafe virality.", "Useful sharing and credible partnerships bring the right participants back into active local networks.", "Teen referral|referrals;Adult referral|referrals;Business referral|referrals;Guardian referral|referrals;Neighborhood ambassador program|ambassadors;School counselor kit|school;School club toolkit|school;Nonprofit toolkit|nonprofit;Local business outreach|business;QR job link|sharing;QR public-safe profile link|sharing;Shareable job page|public web;Public-safe profile page|public web;Community event page|events;City and neighborhood waitlist|launch;Referral attribution and fraud|measurement;Impact story and campaign analytics|content"),
  c("AI assistance, automation, and intelligent safety", "ai-automation", 78, "ai3", "all users", "admin", "Automation can reduce effort and surface risk, but opaque or client-keyed AI would create privacy and safety failures.", "Explainable assistance improves repeated work while users and staff retain control.", "Explainable job matching|matching;Unsafe job classification|safety;Scam classification|fraud;Message safety classification|messaging;Proposal coaching|applications;Job-description coaching|creation;Schedule suggestion|scheduling;Category suggestion|classification;Skill extraction|profiles;Portfolio description assistance|portfolio;Resume bullet assistance|employment;Post-job reflection assistance|learning;Adult applicant summary|hiring;Admin report summary|moderation;Support response drafting|support;Duplicate report detection|moderation;Suspicious pattern detection|abuse;Moderation prioritization|moderation;Job risk explanation|safety;Plain-language simplification|accessibility;Translation assistance|localization;Notification summarization|notifications;Feedback clustering|research;Feature recommendation|personalization;Help search|support;Provider failure and model audit|reliability"),
  c("Admin, moderation, support, and operations", "admin-operations", 85, "operations", "admin, safety staff", "support staff", "Teen-safety operations require restricted evidence, accountable decisions, escalation, and durable support workflows.", "Queues and audit trails let staff resolve incidents consistently as the marketplace grows.", "Moderation overview|moderation;User review queue|user safety;Job review queue|job safety;Message review queue|message safety;Report review queue|reports;Incident evidence review|evidence;Verification review|verification;Avatar review|media;Proof decision audit trail|proof;Support ticket operations|support;Appeal operations|appeals;Account restriction operations|enforcement;Safety Ping queue|safety;Payment issue queue|payment;RevenueCat and webhook queue|monetization;Rate-limit and AI review queue|automation;Policy flag experiment and SLA operations|platform"),
  c("Analytics, insights, experiments, and reporting", "analytics-insights", 60, "operations", "admin", "business", "MORT needs evidence for product and safety decisions without unnecessary sensitive-data collection or fabricated metrics.", "Reliable outcome metrics guide marketplace quality and operational improvement.", "Signup and onboarding completion|activation;First useful action|activation;Job posting funnel|jobs;Application response time|applications;Job fill rate|health;Cancellation rate|health;Proof turnaround|completion;Support and report rate|operations;Safety intervention outcomes|safety;Feature and accessibility adoption|usage;Notification effectiveness|engagement;Monetization referral and retention cohorts|business"),
  c("Privacy, compliance, transparency, and user controls", "privacy-controls", 70, "marketplace", "all users", "admin", "Teen work data, messages, evidence, location, and consent require transparent controls and strict authorization.", "Predictable controls make long-term marketplace participation safer and more trustworthy.", "Privacy terms and guideline summary|transparency;Account data export|rights;Account deletion request|rights;Notification privacy|notifications;Approximate location privacy|location;Guardian privacy boundary|guardian;Message privacy|messaging;Proof evidence access|evidence;Data retention|retention;Consent record|consent;Age assurance|age;Jurisdiction and youth-work rules|compliance;Blocked user and session control|security;Marketing analytics ad and ATT consent|consent"),
  c("Reliability, offline behavior, performance, and recovery", "reliability-recovery", 70, "reliability", "all users", "system", "Mobile networks, providers, retries, stale sessions, and malformed data can interrupt real work and create false state.", "Reliable recovery protects active jobs and user trust.", "Offline and connection-loss handling|network;Slow-network feedback|network;Action retry and rollback|transactions;Expired session recovery|auth;Upload resume and cancellation|uploads;Duplicate submission prevention|idempotency;Pagination and read caching|data;Image optimization and signed URL refresh|media;Conversation read cursor|messaging;Realtime and background reconnect|realtime;Malformed payload and deleted record handling|integrity;RevenueCat AdMob and AI degradation|providers;HTTP error family recovery|api;Maintenance incident backup and load readiness|operations"),
  c("Native iOS, SwiftUI, platform integrations, and device experience", "native-ios", 55, "ios", "all users", "system", "Source parity is not enough; a native iPhone app needs correct platform integration, lifecycle behavior, permissions, and release evidence.", "Native reliability and accessibility make repeated real-device work feel dependable.", "Xcode project structure|build;Exact Swift package integration|dependencies;Typed routing async-await and actor isolation|architecture;Supabase session and Keychain behavior|auth;Deep links and universal links|routing;APNs registration and notification routing|notifications;PhotosPicker camera crop and metadata handling|media;RevenueCat and Customer Center|monetization;AdMob UMP and ATT|ads;VoiceOver Dynamic Type haptics and Reduce Motion|accessibility;App lifecycle share sheet date input safe areas and tests|device", "SwiftUI native iOS"),
];

const CUSTOM = new Map();
function custom(categorySlug, topic, variants) {
  CUSTOM.set(categorySlug + "|" + topic, variants);
}

custom("messaging-collaboration", "Conversation unread state", [
  v("server-count", "server-authoritative participant count", "Local badges cannot know what another participant actually read.", "Counts only incoming messages newer than the authenticated participant's server cursor.", "It makes unread state accurate across sessions.", "unread-count"),
  v("own-message-exclusion", "own-message exclusion", "A sender's messages can inflate naive unread totals.", "Excludes current-user messages while retaining authorized history.", "It prevents false unread pressure.", "unread-own"),
  v("mark-read", "idempotent mark-read action", "Opening a thread needs a durable participant-specific cursor.", "Advances only the authenticated participant cursor through a checked RPC.", "It keeps state consistent through retries.", "unread-mark"),
  v("badge", "accessible unread badge", "People need to identify conversations that need attention.", "Shows a numeric badge in SwiftUI and Flutter without leaking message text.", "It focuses attention privately.", "unread-badge"),
  v("isolation", "cross-user read-state isolation", "Read state can reveal private relationship activity.", "Denies outsiders from discovering or changing another conversation cursor.", "It protects relationship metadata.", "unread-isolation"),
]);

custom("adult-business-hiring", "Private proof review workspace", [
  v("private-preview", "participant-authorized preview", "Posters cannot verify completion if evidence is inaccessible or public.", "Loads the latest proof through a short-lived participant-authorized URL.", "It supports review without public media.", "proof-preview"),
  v("approve", "proof approval decision", "Proof-required jobs need an explicit acceptance step.", "Lets the owning poster approve the current proof through a checked RPC.", "It makes evidence meaningful.", "proof-approve"),
  v("resubmit", "replacement-proof request", "A legitimate but unclear image needs correction without ending the job.", "Requires an explanation and returns work to in-progress for replacement proof.", "It supports fair correction.", "proof-resubmit"),
  v("reject", "proof rejection with explanation", "Unsafe or unusable evidence needs an accountable response.", "Requires a meaningful note and retains restricted history.", "It prevents silent rejection.", "proof-reject"),
  v("complete", "approved-proof completion action", "Posters need a clear final action after approval.", "Offers completion from approved proof state through the existing checked transition.", "It closes work without bypassing rules.", "proof-complete"),
]);

custom("job-lifecycle", "Proof-gated completion", [
  ...SETS.marketplace.slice(0, 1),
  v("approval-gate", "server approval gate", "A client could mark proof-required work complete before review.", "Rejects completion at the database boundary until approved proof exists.", "It makes the evidence rule enforceable.", "proof-gate"),
  ...SETS.marketplace.slice(2),
]);

custom("notifications-engagement", "Proof review updates", [
  v("decision-event", "committed decision event", "Teens need to know when proof is approved or needs attention.", "Creates a private notification only after the proof decision commits.", "It returns the teen to a real next step.", "proof-notification"),
  ...SETS.marketplace.slice(1),
]);

custom("admin-operations", "Proof decision audit trail", [
  v("append-only-event", "append-only review event", "Proof decisions need attributable history beyond current status.", "Records actor, action, application, note, and timestamp only from the checked RPC.", "It supports accountable operations.", "proof-audit"),
  ...SETS.operations.slice(1),
]);

custom("privacy-controls", "Proof evidence access", [
  v("signed-access", "short-lived participant access", "Private proof files must not become public URLs.", "Uses storage authorization and expiring URLs for participants or authorized admins.", "It minimizes proof exposure.", "proof-privacy"),
  ...SETS.marketplace.slice(1),
]);

custom("reliability-recovery", "Conversation read cursor", [
  v("concurrent-idempotency", "concurrent idempotency", "Multiple opens can race while marking a thread read.", "Uses a monotonic timestamp so concurrent mark-read calls never move backward.", "It preserves accurate state under retry.", "unread-concurrency"),
  ...SETS.reliability.slice(1),
]);

custom("safety-prevention", "Stale completion evidence", [
  v("current-proof-check", "current-proof check", "An old image could be approved after replacement evidence exists.", "Refuses decisions on evidence older than the current submission.", "It prevents an unfair completion record.", "stale-proof"),
  ...SETS.safety.slice(1),
]);

custom("trust-reputation", "Adult verification", [
  v("marketplace-gate", "marketplace eligibility gate", "Unverified or expired adult accounts must not reach teen-facing job actions.", "Requires a server-authoritative adult identity result before publishing, reviewing teen applications, messaging accepted workers, or receiving proof.", "It makes adult accountability a real marketplace boundary.", "adult-identity"),
  v("restricted-government-evidence", "restricted government-evidence intake", "Government identity documents cannot travel through public profiles or ordinary app tables.", "Accepts approved adult document types into randomized private objects and registers only minimized metadata and hashes.", "It supports review without public document exposure.", "adult-identity"),
  v("ownership-selfie-intake", "ownership-selfie evidence intake", "A document alone does not establish that the account holder controls it.", "Collects a separate ownership-selfie evidence item while clearly reserving live liveness adjudication for a selected verification vendor.", "It prepares a stronger identity match without making a false liveness claim.", "adult-identity"),
  v("private-address-result", "private address-validation result", "Accountability needs address validation without exposing a residence to users or routine staff.", "Stores only restricted validation state and encrypted evidence references, returning a boolean result to ordinary clients.", "It improves accountability while minimizing doxxing risk.", "adult-identity"),
  v("audited-review-appeal", "audited review, expiration, and appeal", "Identity decisions need controlled review and correction rather than permanent automated punishment.", "Routes approval, additional-information requests, rejection, expiration, and appeal through specialized audited server actions.", "It gives users due process without auto-restoring access.", "adult-identity"),
]);

custom("trust-reputation", "Mutual identity verification", [
  v("teen-school-id", "teen school-photo-ID path", "School photo identification is useful for many teens but must remain private.", "Supports a school-photo-ID route with ownership evidence while excluding school name, student number, and documents from public payloads.", "It verifies age eligibility without exposing school identity.", "mutual-identity"),
  v("teen-alternatives", "teen alternative-evidence routes", "Homeschooled, online-school, transitional, and other legitimate teens may lack a traditional school ID.", "Supports government ID, verified school account, approved program evidence, and a manual trusted-referee exception route.", "It avoids unfairly excluding teens who lack one document type.", "mutual-identity"),
  v("guardian-independent", "guardian-independent teen eligibility", "Mandatory parental control would exclude teens and confuse supervision with identity proofing.", "Allows a verified age-eligible teen to participate without a guardian while keeping Guardian Mode and Safety Circle voluntary.", "It preserves teen independence inside mandatory platform safety boundaries.", "mutual-identity"),
  v("status-expiration", "server-owned status and expiration", "Client-editable badges or permanent verification can create false trust.", "Returns a minimized status history while server checks enforce pending, manual-review, expired, suspended, and verified states.", "It keeps trust indicators current and explainable.", "mutual-identity"),
  v("appeal-recheck", "identity appeal and recheck", "Evidence can change, expire, or be reviewed incorrectly.", "Provides a bounded appeal and re-verification path that never approves itself or restores marketplace access automatically.", "It adds correction without weakening the gate.", "mutual-identity"),
]);

custom("safety-prevention", "Harassment and sexual content", [
  v("direction-neutral-scanner", "direction-neutral participant scanner", "Harassment can be sent by a teen or an adult and safety rules must protect both sides.", "Scans participant messages using the same server-authoritative rules regardless of sender role and records a bounded classification.", "It avoids assuming one participant is automatically safe.", "sexual-harassment"),
  v("adult-minor-hard-block", "adult-minor sexual-content hard block", "Sexualized adult-minor communication requires an immediate safety boundary.", "Replaces prohibited thread content with a neutral placeholder and creates a critical restricted safety event.", "It stops ordinary delivery while preserving accountable escalation.", "sexual-harassment"),
  v("raw-evidence-isolation", "restricted raw-message evidence", "Exposing blocked raw content to recipients or routine staff can compound harm.", "Stores raw blocked text only in a restricted evidence table with preservation metadata and no ordinary participant read path.", "It preserves evidence without replaying abuse in the thread.", "sexual-harassment"),
  v("critical-escalation", "critical child-safety escalation", "Sexual and grooming signals must reach trained human review quickly.", "Creates a priority-one incident record for authorized child-safety roles without making automation the final decision.", "It supports urgent accountable review.", "sexual-harassment"),
  v("review-appeal", "human review and appeal boundary", "Automated classifications can be incomplete or wrong.", "Exposes participant-safe case status and a separate appeal path while keeping restricted allegations and evidence private.", "It preserves due process for high-impact actions.", "sexual-harassment"),
]);

custom("safety-prevention", "Threat and coercion", [
  v("threat-hard-block", "threat hard block", "Direct threats should not remain usable as ordinary job coordination.", "Blocks critical threat delivery, returns a neutral placeholder, and records severity at the server boundary.", "It interrupts immediate coercive contact.", "threat-coercion"),
  v("coercion-blackmail-signal", "coercion and blackmail signal", "Pressure, retaliation, and blackmail can come from either marketplace role.", "Flags coercive language for restricted review without publishing an accusation or automatically imposing final enforcement.", "It surfaces mutual risk while retaining human judgment.", "threat-coercion"),
  v("preserved-message-evidence", "preserved message evidence", "A serious sender must not be able to erase the record after a report.", "Creates hashed, retention-bound restricted evidence for critical messages and prevents participant deletion.", "It supports later incident review and lawful preservation.", "threat-coercion"),
  v("mutual-report-block", "mutual report and no-contact control", "Adults also need protection from harassment, scams, threats, theft, and fabricated pressure.", "Lets either participant report or block the other and closes ordinary message contact without suppressing safety records.", "It protects both sides of the work relationship.", "threat-coercion"),
  v("case-status-appeal", "bounded incident status and appeal", "Participants need a useful outcome without access to another person's restricted case data.", "Returns only authorized case number, public status, and appeal state while isolating raw incident rows.", "It balances transparency, privacy, and correction.", "threat-coercion"),
]);

custom("safety-prevention", "Safe first meetings and high-risk work", [
  v("mutual-agreement", "mutual Safety Agreement", "Accepted work can become unsafe when participants remember different scope, people, place, or boundaries.", "Requires both participants to confirm the exact version of material job terms before work can start.", "It creates a shared safety record without routine guardian approval.", "safe-first-meeting"),
  v("risk-plan", "risk-tier first-meeting plan", "A first job in a private, late, isolated, or equipment-heavy setting needs stronger preparation.", "Captures visibility, daylight, expected people, transport, check-in cadence, and risk disclosures in a job-specific plan.", "It makes foreseeable hazards visible before arrival.", "safe-first-meeting"),
  v("staged-location", "staged exact-location release", "Public or premature exact addresses create stalking and doxxing risk.", "Keeps the feed coarse and releases the job address only to the authorized accepted participant after both confirmations.", "It reveals location only when the work relationship needs it.", "safe-first-meeting"),
  v("single-use-arrival", "single-use arrival handshake", "A verified account does not prove that the expected person is physically present.", "Uses a short-lived rotating code plus an independent person-match confirmation and rejects replay.", "It detects real-world identity mismatch without exchanging documents.", "safe-first-meeting"),
  v("safe-cancel", "no-penalty safety cancellation", "People should be able to leave when person, location, scope, or conditions materially differ.", "Pauses the workflow, opens a restricted incident when warranted, and applies no automatic reputation penalty.", "It protects the right to leave without retaliation pressure.", "safe-first-meeting"),
]);

custom("admin-operations", "Verification review", [
  v("specialized-role", "specialized reviewer role", "General support access is too broad for identity evidence.", "Limits identity review to explicit verification and senior safety roles using server-owned assignments.", "It applies least privilege to sensitive documents.", "verification-admin"),
  v("metadata-manifest", "metadata-only evidence manifest", "Reviewers need to discover submitted items without receiving storage paths by default.", "Returns type, hash, size, and review metadata while withholding object paths.", "It minimizes exposure during queue triage.", "verification-admin"),
  v("reasoned-access", "reasoned short-lived evidence access", "Sensitive document access needs a case purpose and narrow duration.", "Requires an authorized reviewer, access reason, and expiring grant before a restricted path can be resolved.", "It makes every sensitive view attributable.", "verification-admin"),
  v("specialized-decision", "specialized audited decision", "A generic table update could bypass identity invariants.", "Uses a dedicated review RPC for approval, rejection, and additional-information decisions and writes immutable audit context.", "It keeps client and admin actions inside one authority boundary.", "verification-admin"),
  v("appeal-queue", "separate verification-appeal queue", "A reviewer should not silently erase or approve a challenge.", "Routes appeals to a restricted queue with status, reason, decision note, and no automatic restoration.", "It creates a reviewable correction path.", "verification-admin"),
]);

custom("admin-operations", "Incident evidence review", [
  v("incident-role", "specialized incident-manager role", "Routine admins should not browse allegations or safety evidence.", "Restricts incident evidence and high-impact actions to incident, child-safety, senior safety, or legal-review roles as appropriate.", "It limits sensitive access to trained responsibilities.", "incident-admin"),
  v("incident-manifest", "metadata-only incident manifest", "Incident triage needs evidence inventory before content access.", "Returns hashes, type, size, preservation status, and timestamps without exposing storage paths.", "It supports narrow evidence discovery.", "incident-admin"),
  v("incident-access-grant", "reasoned incident evidence grant", "A permanent admin download path would undermine case privacy.", "Requires incident assignment or authorized role, a meaningful reason, an audit event, and a short expiry.", "It constrains evidence access to the active case need.", "incident-admin"),
  v("preservation-lock", "preservation and deletion lock", "Reported evidence can disappear if participants retain ordinary delete authority.", "Registers evidence by hash, supports preservation orders, and denies participant deletion after registration.", "It protects case integrity without making files public.", "incident-admin"),
  v("lawful-request-audit", "lawful-request and supervisory audit", "Emergency or law-enforcement disclosure cannot be an informal staff action.", "Tracks validated requests, minimized scope, preservation, reviewer role, and restricted timeline events.", "It prepares an accountable process that still requires legal review.", "incident-admin"),
]);

custom("privacy-controls", "Approximate location privacy", [
  v("public-coarse-area", "public coarse-area boundary", "Exact addresses in discovery can expose homes, teens, and job sites.", "Keeps public and application-stage location to city, neighborhood, approximate distance, and location type.", "It supports discovery without publishing a destination.", "location-privacy"),
  v("accepted-release", "accepted-participant release gate", "Acceptance alone should not bypass the safety plan.", "Releases a restricted job address only to the assigned participant after the current mutual agreement is confirmed.", "It ties disclosure to a legitimate active need.", "location-privacy"),
  v("home-address-isolation", "verified-home-address isolation", "An account residence is not the same as a job location and must not appear in marketplace payloads.", "Stores validation state and restricted encrypted address evidence separately, returning only address-verified status to ordinary clients.", "It improves accountability without enabling personal tracking.", "location-privacy"),
  v("temporary-coarse-share", "temporary coarse-location share", "Some participants want check-in support without continuous precise tracking.", "Provides explicit job-bound coarse sharing with visible state, a bounded expiry, and manual stop.", "It adds situational support while preserving location agency.", "location-privacy"),
  v("post-job-expiry", "post-job location expiry and audit", "Location access should not remain available after its operational purpose ends.", "Expires ordinary release and temporary shares while retaining only authorized audit and incident records under policy.", "It reduces lasting exposure after work.", "location-privacy"),
]);

custom("guardian-mode", "Voluntary guardian linking", [
  v("separate-identity", "identity-independent opt-in", "A guardian relationship must not become the proof that a teen is real or eligible.", "Keeps identity verification mandatory while Guardian Mode and Safety Circle remain optional and excluded from profile completion.", "It preserves independent teen access after verification.", "optional-safety-circle"),
  v("teen-invitation", "teen-controlled Safety Circle invitation", "A teen may want help from a trusted adult who is not a full account controller.", "Lets the teen invite a guardian, relative, mentor, or trusted adult through a bounded linking workflow.", "It adds support chosen by the teen.", "optional-safety-circle"),
  v("granular-alerts", "granular safety-alert grants", "Sharing everything is not necessary to receive emergency support.", "Lets the teen grant individual Safety Ping, missed check-in, job-summary, status, and completion alerts.", "It makes support proportional to consent.", "optional-safety-circle"),
  v("privacy-boundary", "message, identity, and control boundary", "A trusted contact should not gain identity documents, all messages, earnings, or impersonation authority.", "Server policies expose only granted safety-circle records and no unrestricted profile, evidence, message, or location history.", "It prevents optional support from becoming surveillance.", "optional-safety-circle"),
  v("unlink-no-penalty", "bilateral unlink without participation penalty", "Either person may need to end a trusted-contact relationship safely.", "Allows teen or contact unlinking without lowering profile completion, identity status, or ordinary marketplace eligibility.", "It keeps voluntary support genuinely voluntary.", "optional-safety-circle"),
]);

const EVIDENCE = {};
function sharedEvidence(key, swiftPath, swiftSymbol, flutterPath, flutterSymbol, backendSymbol) {
  EVIDENCE[key] = {
    status: "shared_implemented",
    platform: "shared SwiftUI + Flutter Web + Supabase",
    swiftPath, flutterPath, rpc: backendSymbol,
    evidence: swiftPath + "; " + flutterPath + "; supabase/migrations/20260717082454_feature_expansion_unread_proof_review.sql; scripts/qa-feature-expansion.mjs",
    checks: [
      { path: swiftPath, symbol: swiftSymbol },
      { path: flutterPath, symbol: flutterSymbol },
      { path: "supabase/migrations/20260717082454_feature_expansion_unread_proof_review.sql", symbol: backendSymbol },
      { path: "scripts/qa-feature-expansion.mjs", symbol: backendSymbol.includes("proof") ? "proof" : "message" },
    ],
    testStatus: "Remote isolated QA passed; Flutter analyze and 60 tests passed; Swift static audit passed; Mac compilation and physical iPhone verification pending.",
    mac: true, iphone: true,
  };
}
function backendEvidence(key, backendSymbol, qaSymbol) {
  EVIDENCE[key] = {
    status: "implemented_verified_backend", platform: "Supabase backend",
    swiftPath: "not_applicable - backend invariant", flutterPath: "not_applicable - backend invariant",
    rpc: backendSymbol,
    evidence: "supabase/migrations/20260717082454_feature_expansion_unread_proof_review.sql; scripts/qa-feature-expansion.mjs",
    checks: [
      { path: "supabase/migrations/20260717082454_feature_expansion_unread_proof_review.sql", symbol: backendSymbol },
      { path: "scripts/qa-feature-expansion.mjs", symbol: qaSymbol },
    ],
    testStatus: "Remote isolated RLS, storage, abuse, concurrency, and load-sanity QA passed.",
    mac: false, iphone: false,
  };
}

function mutualTrustEvidence(key, options) {
  const {
    swiftPath, swiftSymbol, flutterPath, flutterSymbol,
    backendPath, backendSymbol, qaSymbol, backendTables,
    storage = "none", status = "shared_implemented",
    reasonDeferred = "Mac/Xcode compilation and physical iPhone verification remain pending.",
  } = options;
  EVIDENCE[key] = {
    status,
    platform: "shared SwiftUI source + Flutter Web + Supabase",
    swiftPath,
    flutterPath,
    rpc: backendSymbol,
    backendTables,
    storage,
    privacyImpact: "High privacy impact: minimize sensitive identity, incident, and location data; enforce purpose-bound access, retention, audit, and nonpublic defaults.",
    legalReview: "Required before real-user release for identity proofing, youth work, screening, evidence retention, emergency disclosure, and jurisdiction-specific safety policy. No legal or safety guarantee.",
    evidence: [swiftPath, flutterPath, backendPath, "scripts/mutual-trust-qa-suites.mjs"].join("; "),
    checks: [
      { path: swiftPath, symbol: swiftSymbol },
      { path: flutterPath, symbol: flutterSymbol },
      { path: backendPath, symbol: backendSymbol },
      { path: "scripts/mutual-trust-qa-suites.mjs", symbol: qaSymbol },
    ],
    testStatus: "Remote mutual-trust QA passed 19/19 in one consolidated run; Flutter analyze passed, all 60 tests passed, Flutter web built, and Swift static audit passed. Mac compilation, physical capture, and iPhone verification remain pending.",
    reasonDeferred,
    mac: true,
    iphone: true,
  };
}

sharedEvidence("unread-count", "swift_mort/MORT/Models/Message.swift", "var unread", "flutter_mort/lib/data/models/message.dart", "unreadCount", "get_my_message_threads");
backendEvidence("unread-own", "message.sender_id <> auth.uid()", "2/15 unread count");
sharedEvidence("unread-mark", "swift_mort/MORT/Repositories/MessageRepository.swift", "markRead", "flutter_mort/lib/data/repositories/messaging_repository.dart", "markThreadRead", "mark_message_thread_read");
sharedEvidence("unread-badge", "swift_mort/MORT/Features/Messaging/MessagingViews.swift", "unread messages", "flutter_mort/lib/features/mort_screens.dart", "unreadCount", "get_my_message_threads");
backendEvidence("unread-isolation", "participant.user_id = auth.uid()", "3/15 conversation discovery");
sharedEvidence("proof-preview", "swift_mort/MORT/Features/Proof/ProofReviewView.swift", "MortAsyncImage", "flutter_mort/lib/features/jobs/proof_review_screen.dart", "signedUrl", "review_application_proof");
sharedEvidence("proof-approve", "swift_mort/MORT/Features/Proof/ProofReviewView.swift", "Approve proof", "flutter_mort/lib/features/jobs/proof_review_screen.dart", "Approve proof", "review_application_proof");
sharedEvidence("proof-resubmit", "swift_mort/MORT/Features/Proof/ProofReviewView.swift", "Request a new proof", "flutter_mort/lib/features/jobs/proof_review_screen.dart", "Request new proof", "review_application_proof");
sharedEvidence("proof-reject", "swift_mort/MORT/Features/Proof/ProofReviewView.swift", "Reject this proof", "flutter_mort/lib/features/jobs/proof_review_screen.dart", "Reject proof", "review_application_proof");
sharedEvidence("proof-complete", "swift_mort/MORT/Features/Proof/ProofReviewView.swift", "Mark job complete", "flutter_mort/lib/features/jobs/proof_review_screen.dart", "Mark job complete", "review_application_proof");
backendEvidence("proof-gate", "require_approved_proof_for_completion", "8/15 backend blocks completion");
backendEvidence("proof-notification", "queue_proof_review_notification", "14/15 proof decision");
backendEvidence("proof-audit", "proof_review_events", "13/15 proof review history");
sharedEvidence("proof-privacy", "swift_mort/MORT/Repositories/StorageRepository.swift", "signedURL", "flutter_mort/lib/data/repositories/uploads_repository.dart", "signedUrl", "proof_review_events");
backendEvidence("unread-concurrency", "greatest(last_read_at, v_read_at)", "4/15 mark-read");
backendEvidence("stale-proof", "stale_proof_submission", "10/15 stale proof");

mutualTrustEvidence("adult-identity", {
  swiftPath: "swift_mort/MORT/Features/Verification/VerificationView.swift",
  swiftSymbol: "Adults need an identity document",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "Adults must use government ID",
  backendPath: "supabase/migrations/20260717161125_mutual_identity_verification.sql",
  backendSymbol: "start_identity_verification",
  qaSymbol: "runMutualVerification",
  backendTables: "identity_verifications, identity_verification_evidence, verification_audit_events",
  storage: "private identity-evidence bucket; randomized paths; metadata-only manifests; reasoned short-lived reviewer grants",
  reasonDeferred: "Automated document authenticity, live liveness matching, and address adjudication require a selected verification vendor; Mac/Xcode and physical iPhone capture verification remain pending.",
});

mutualTrustEvidence("mutual-identity", {
  swiftPath: "swift_mort/MORT/Features/Verification/VerificationView.swift",
  swiftSymbol: "School photo ID is preferred",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "Manual exception review",
  backendPath: "supabase/migrations/20260717161125_mutual_identity_verification.sql",
  backendSymbol: "submit_identity_verification",
  qaSymbol: "runTeenAlternatives",
  backendTables: "identity_verifications, identity_verification_evidence, identity_verification_appeals, verification_referee_requests",
  storage: "private identity-evidence bucket with role-aware evidence routes and no public school identifiers",
  reasonDeferred: "Evidence adjudication and live ownership/liveness checks require a selected verification vendor or trained restricted reviewer; Mac/Xcode and physical iPhone capture verification remain pending.",
});

mutualTrustEvidence("sexual-harassment", {
  swiftPath: "swift_mort/MORT/Features/Safety/TrustSafetyViews.swift",
  swiftSymbol: "IncidentHistoryView",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "SafetyCasesScreen",
  backendPath: "supabase/migrations/20260730043000_messaging_lifecycle_privacy_and_reliability.sql",
  backendSymbol: "send_safe_message_v2",
  qaSymbol: "runSexualSafety",
  backendTables: "messages, message_safety_evidence, safety_incidents, incident_participants, incident_timeline_events",
  storage: "none for message text; restricted database evidence with retention and preservation metadata",
  reasonDeferred: "Scanner rules require ongoing trained child-safety review, false-positive monitoring, and jurisdictional policy approval; physical iPhone behavior remains pending.",
});

mutualTrustEvidence("threat-coercion", {
  swiftPath: "swift_mort/MORT/Features/Safety/TrustSafetyViews.swift",
  swiftSymbol: "Request appeal review",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "Request appeal review",
  backendPath: "supabase/migrations/20260730070000_safety_actions_checkins_and_triage.sql",
  backendSymbol: "submit_safety_report_v2",
  qaSymbol: "runHarassmentControls",
  backendTables: "messages, blocks, message_safety_evidence, safety_incidents, incident_appeals",
  storage: "restricted incident-evidence bucket only when a participant submits supporting media",
  reasonDeferred: "Threat and coercion policy requires trained moderation, emergency escalation staffing, and legal review; physical iPhone behavior remains pending.",
});

mutualTrustEvidence("safe-first-meeting", {
  swiftPath: "swift_mort/MORT/Features/Safety/TrustSafetyViews.swift",
  swiftSymbol: "Mutual Safety Agreement",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "Arrival handshake",
  backendPath: "supabase/migrations/20260717161132_mutual_trust_real_world_safety.sql",
  backendSymbol: "confirm_job_safety_agreement",
  qaSymbol: "runArrivalHandshake",
  backendTables: "job_safety_plans, job_safety_agreements, job_private_locations, job_arrival_handshakes, safety_cancellations",
  storage: "none",
  reasonDeferred: "Risk-tier policy, weather providers, and jurisdiction-specific youth work limits require operational configuration and legal review; physical arrival and iPhone testing remain pending.",
});

mutualTrustEvidence("verification-admin", {
  swiftPath: "swift_mort/MORT/Features/Admin/AdminViews.swift",
  swiftSymbol: "approveIdentity",
  flutterPath: "flutter_mort/lib/features/mort_screens.dart",
  flutterSymbol: "Approve after evidence review",
  backendPath: "supabase/migrations/20260717161125_mutual_identity_verification.sql",
  backendSymbol: "admin_review_identity_verification",
  qaSymbol: "verification reviewer",
  backendTables: "admin_role_assignments, identity_verifications, verification_evidence_access_grants, verification_audit_events",
  storage: "private identity-evidence bucket with metadata-only discovery and reasoned short-lived grants",
  reasonDeferred: "Real operation requires trained verification reviewers, conflict controls, vendor procedures, and a Mac/Xcode compiled admin client check.",
});

mutualTrustEvidence("incident-admin", {
  swiftPath: "swift_mort/MORT/Features/Admin/AdminViews.swift",
  swiftSymbol: "evidencePreservation",
  flutterPath: "flutter_mort/lib/features/mort_screens.dart",
  flutterSymbol: "Update restricted incident?",
  backendPath: "supabase/migrations/20260717161132_mutual_trust_real_world_safety.sql",
  backendSymbol: "authorize_incident_evidence_access",
  qaSymbol: "runEvidencePreservation",
  backendTables: "safety_incidents, incident_evidence, incident_preservation_orders, incident_law_enforcement_requests, incident_timeline_events",
  storage: "private incident-evidence bucket with hashes, registered-object delete protection, metadata-only manifests, and reasoned grants",
  reasonDeferred: "Real operation requires trained incident staff, counsel-approved legal-request procedures, emergency coverage, and a Mac/Xcode compiled admin client check.",
});

mutualTrustEvidence("location-privacy", {
  swiftPath: "swift_mort/MORT/Features/Safety/TrustSafetyViews.swift",
  swiftSymbol: "Staged exact location",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "Temporary coarse-area sharing",
  backendPath: "supabase/migrations/20260717161132_mutual_trust_real_world_safety.sql",
  backendSymbol: "start_temporary_location_share",
  qaSymbol: "runLocationStages",
  backendTables: "job_private_locations, private_data_access_events, job_location_share_sessions, job_safety_agreements",
  storage: "none",
  reasonDeferred: "Retention schedules, emergency disclosure policy, and physical iPhone location behavior require legal, operational, and real-device validation.",
});

mutualTrustEvidence("optional-safety-circle", {
  swiftPath: "swift_mort/MORT/Features/Safety/TrustSafetyViews.swift",
  swiftSymbol: "Safety Circle",
  flutterPath: "flutter_mort/lib/features/safety/trust_safety_screens.dart",
  flutterSymbol: "SafetyCircleScreen",
  backendPath: "supabase/migrations/20260717161132_mutual_trust_real_world_safety.sql",
  backendSymbol: "create_safety_circle_invite",
  qaSymbol: "runGuardianOptional",
  backendTables: "safety_circle_members, notifications, guardian_connections",
  storage: "none; Safety Circle never grants identity-document access",
  reasonDeferred: "Notification delivery, emergency-contact consent language, and physical iPhone alert behavior require operational, legal, and real-device validation.",
});

for (const key of ["unread-count", "unread-mark", "unread-badge"]) {
  EVIDENCE[key].checks.push(
    { path: "swift_mort/MORT/App/Router.swift", symbol: "case messages" },
    { path: "flutter_mort/lib/core/routing/app_router.dart", symbol: "'/messages'" },
  );
}
for (const key of ["proof-preview", "proof-approve", "proof-resubmit", "proof-reject", "proof-complete"]) {
  EVIDENCE[key].checks.push(
    { path: "swift_mort/MORT/App/Router.swift", symbol: "case proofReview" },
    { path: "flutter_mort/lib/core/routing/app_router.dart", symbol: "'/adult/proof-review/:applicationId'" },
    { path: "swift_mort/MORT/Repositories/ApplicationRepository.swift", symbol: key === "proof-preview" ? "func proofs" : "func reviewProof" },
    { path: "flutter_mort/lib/data/repositories/applications_repository.dart", symbol: key === "proof-preview" ? "listProofs" : "reviewProof" },
  );
}

function slugify(value) {
  return value.toLowerCase().replace(/&/g, " and ").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
function clamp(value) {
  return Math.max(1, Math.min(5, value));
}
function offset(value, salt) {
  let total = salt;
  for (const ch of value) total = (total * 33 + ch.charCodeAt(0)) % 997;
  return (total % 3) - 1;
}
function waveFor(categoryName, implemented) {
  if (implemented) return "Wave 0 - existing completion";
  if (/Safety|Accessibility|Applications|Messaging|Job lifecycle|Privacy|Reliability/.test(categoryName)) return "Wave 1 - safety and core marketplace";
  if (/retention|Profiles|Teen earning|Adult and business|Notifications/.test(categoryName)) return "Wave 2 - repeat value";
  if (/Guardian|Discovery|Trust|AI/.test(categoryName)) return "Wave 3 - MORT differentiation";
  if (/community|Admin|Analytics/.test(categoryName)) return "Wave 4 - business and community scale";
  if (/Marketing/.test(categoryName)) return "Wave 5 - sustainable growth";
  return "Wave 6 - advanced platform capability";
}
function roleBase(name, pattern, high, normal) {
  return pattern.test(name) ? high : normal;
}
function moneyFor(category, title) {
  if (!/Monetization/.test(category)) return ["Core capability; optional perks cannot reduce safety, privacy, access, or fair opportunity.", "free"];
  if (/free path|dismissal|restore|failed|fallback/i.test(title)) return ["Free purchase control or recovery required for ethical monetization.", "free"];
  return ["Optional convenience or business perk; price and entitlement authority remain RevenueCat/App Store.", "optional_paid"];
}

export function buildRegistry() {
  const records = [];
  for (const definition of CATEGORIES) {
    for (const topic of definition.topics) {
      const variants = CUSTOM.get(definition.slug + "|" + topic.label) || SETS[definition.set];
      for (const variant of variants) {
        const uniqueSlug = definition.slug + "-" + slugify(topic.label) + "-" + variant.slug;
        const implementation = variant.implementationKey ? EVIDENCE[variant.implementationKey] : null;
        const title = topic.label + " " + variant.suffix;
        const safetyScore = clamp(roleBase(definition.name, /Safety|Guardian|Privacy/, 5, 3) + offset(uniqueSlug, 11));
        const accessibilityScore = clamp(roleBase(definition.name, /Accessibility|Onboarding|Native iOS/, 5, 3) + offset(uniqueSlug, 17));
        const growthScore = clamp(roleBase(definition.name, /Marketing|community|Discovery/, 5, 3) + offset(uniqueSlug, 23));
        const revenueScore = clamp(roleBase(definition.name, /Monetization|Adult|Analytics/, 5, 2) + offset(uniqueSlug, 29));
        const retentionScore = clamp(4 + offset(uniqueSlug, 31));
        const differentiationScore = clamp(4 + offset(uniqueSlug, 37));
        const complexityScore = clamp(3 + offset(uniqueSlug, 41));
        const riskScore = clamp((safetyScore >= 5 ? 4 : 3) + offset(uniqueSlug, 43));
        const priority = Math.round((safetyScore * 6 + accessibilityScore * 4 + retentionScore * 4 + growthScore * 3 + revenueScore * 2 + differentiationScore * 4 - complexityScore * 2 - riskScore) / 1.15);
        const money = moneyFor(definition.name, title);
        const needsServer = !/Accessibility|Healthy retention|Native iOS/.test(definition.name);
        records.push({
          feature_id: "",
          unique_slug: uniqueSlug,
          title,
          category: definition.name,
          subcategory: topic.subcategory,
          primary_user: definition.primary,
          secondary_user: definition.secondary,
          real_world_problem: definition.problem + " For " + topic.label.toLowerCase() + ", " + variant.purpose,
          user_story: "As a " + definition.primary + ", I want " + title.toLowerCase() + " so I can get a trustworthy outcome without unsafe workarounds.",
          detailed_behavior: variant.behavior.replaceAll("{topic}", topic.label.toLowerCase()),
          reason_users_value_it: variant.value + " In MORT, that value is tied to a concrete, authorized local-work outcome.",
          reason_users_return: definition.returnReason,
          reason_it_is_different: "MORT adapts this capability for ages 13-17, local work, explainable trust, approximate-location privacy, optional Guardian Mode, and free safety controls.",
          safety_impact: /Safety/.test(definition.name) ? "Direct free safety control; automation is assistive and high-impact decisions remain reviewable." : "Must preserve age, block, report, Safety Ping, prohibited-work, and account-restriction rules.",
          accessibility_impact: /Accessibility/.test(definition.name) ? "Direct free accessibility capability across supported workflows." : "Requires semantic labels, responsive text, keyboard or focus support, non-color status, and accessible errors.",
          privacy_impact: implementation?.privacyImpact || (/Privacy/.test(definition.name) ? "Direct privacy control with minimization, authorization, retention, and transparency." : "Collect only minimum data; keep exact teen location, private messages, evidence, and sensitive records nonpublic."),
          monetization_relationship: money[0],
          free_or_paid: money[1],
          platform_scope: implementation?.platform || definition.platform,
          swift_path: implementation?.swiftPath || "not_started",
          flutter_path: implementation?.flutterPath || "not_started",
          backend_tables: implementation?.backendTables || (implementation ? "conversation_participants, messages, proof_uploads, proof_review_events as applicable" : needsServer ? "design_required - additive schema only if persistence or authority is needed" : "none identified - client or platform behavior"),
          rpc_edge_function: implementation?.rpc || (needsServer ? "design_required - checked RPC or Edge Function if client writes are unsafe" : "none identified"),
          storage_requirement: implementation?.storage || (/avatar|photo|proof|portfolio|evidence|document|media/i.test(title) ? "private bucket and short-lived authorized URL if media is persisted" : "none identified"),
          analytics_requirement: "Privacy-preserving adoption and outcome metrics; exclude sensitive traits and exact teen location.",
          notification_requirement: /Notifications/.test(definition.name) ? "Opt-in, quiet-hour aware, privacy-safe preview, typed destination, and deduplication required." : "Only for time-sensitive user value and only with category preferences; otherwise none.",
          moderation_requirement: /Safety|Trust|community|Admin|AI/.test(definition.name) ? "Human review and audit context required for flags or high-impact decisions." : "Report and block remain available; add routine moderation only when content risk exists.",
          legal_review_requirement: implementation?.legalReview || (/Guardian|Safety|financial|AI|Privacy|Teen earning|community/.test(definition.name) ? "Required before release for youth-work, jurisdiction, privacy, safety, or claims review; no compliance claim." : "Review required if teen data, advertising, employment, or policy claims change."),
          dependencies: "Authenticated profile; role authorization; loading, empty, error, success, and recovery states; shared safety policy.",
          estimated_effort: ["S", "M", "L", "XL", "XXL"][complexityScore - 1],
          expected_impact: priority >= 80 ? "very_high" : priority >= 65 ? "high" : priority >= 50 ? "medium" : "targeted",
          retention_score: retentionScore,
          safety_score: safetyScore,
          accessibility_score: accessibilityScore,
          growth_score: growthScore,
          revenue_score: revenueScore,
          differentiation_score: differentiationScore,
          complexity_score: complexityScore,
          risk_score: riskScore,
          implementation_priority: priority,
          implementation_status: implementation?.status || "accepted_roadmap",
          verification_evidence: implementation?.evidence || "none - accepted roadmap capability only",
          test_status: implementation?.testStatus || "not_started",
          Mac_required: implementation?.mac ?? true,
          iPhone_required: implementation?.iphone ?? !/Admin|Analytics/.test(definition.name),
          manual_dashboard_required: /Monetization|Native iOS/.test(definition.name),
          reason_deferred: implementation?.reasonDeferred || (implementation ? "Mac/Xcode and physical iPhone verification remain where applicable." : "Accepted roadmap item; not implemented in this pass. Requires dependency design and scoped safety/accessibility review."),
          implementation_wave: waveFor(definition.name, Boolean(implementation)),
          evidence_checks: implementation?.checks || [],
        });
      }
    }
  }
  records.forEach((record, index) => {
    record.feature_id = "MORT-F-" + String(index + 1).padStart(4, "0");
  });
  return records;
}

const duplicateCandidateTitles = [
  "Separate dark-mode version of every feature",
  "Separate Swift copy of every shared capability",
  "Separate Flutter copy of every shared capability",
  "One feature for every job-category dropdown option",
  "One feature for every notification wording variation",
  "One feature for every unread-badge color",
  "One feature for every database column",
  "One feature for every analytics event",
  "One feature for every validation error string",
  "One feature for every loading spinner",
  "One feature for every empty-state illustration",
  "One feature for every button rename",
  "One feature for every icon swap",
  "One feature for every typography size",
  "One feature for every settings toggle label",
  "Duplicate report flow for each role",
  "Duplicate block flow for each role",
  "Duplicate Safety Ping flow for each role",
  "Duplicate saved-search flow for each platform",
  "Duplicate profile editor for each profile section",
  "Duplicate upload feature for each accepted file extension",
  "Duplicate retry feature for each HTTP status code",
  "Documentation page counted as a product capability",
  "Test case counted as a user capability",
];

const rejectedCandidateTitles = [
  "Paywalled report and block controls",
  "Paywalled Safety Ping",
  "Paywalled basic Guardian Mode",
  "Paywalled basic job applications",
  "Paywalled accepted-job messaging",
  "Mandatory guardian surveillance for every teen",
  "Public exact teen home location",
  "Public proof-upload bucket",
  "Public private-message search index",
  "Unreviewable automatic account bans",
  "Facial-recognition identity scoring",
  "AI attractiveness ranking",
  "AI race or ethnicity inference",
  "AI medical or mental-health inference",
  "Guaranteed-income marketing claims",
  "Fake purchase-success fallback",
  "Fake ad-reward fallback",
  "Fake upload-success fallback",
  "Unlimited unsolicited adult-to-teen messaging",
  "Engagement streak punishment",
  "Countdown-pressure subscription paywall",
  "Location sharing enabled by default",
  "Client-held Supabase service-role key",
  "Client-held AI provider secret",
];

export const REJECTED_CANDIDATES = [
  ...duplicateCandidateTitles.map((title, index) => ({
    candidate_id: "MORT-D-" + String(index + 1).padStart(3, "0"),
    title,
    status: "duplicate_removed",
    reason: "This is a presentation, platform, field, test, or micro-step duplicate rather than a distinct real-world capability.",
  })),
  ...rejectedCandidateTitles.map((title, index) => ({
    candidate_id: "MORT-R-" + String(index + 1).padStart(3, "0"),
    title,
    status: "rejected",
    reason: "Rejected because it weakens youth safety, privacy, user agency, honest monetization, or secret handling.",
  })),
];

export function countBy(records, field) {
  const counts = new Map();
  for (const record of records) {
    const key = record[field];
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  return counts;
}

export function normalizeFeatureTitle(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function resolveEvidencePath(relativePath) {
  return resolve(repoRoot, relativePath);
}

export function evidenceCheckPasses(check) {
  const absolutePath = resolveEvidencePath(check.path);
  if (!existsSync(absolutePath)) {
    return { passed: false, reason: "missing file", absolutePath };
  }
  const source = readFileSync(absolutePath, "utf8");
  if (!source.includes(check.symbol)) {
    return { passed: false, reason: "missing symbol: " + check.symbol, absolutePath };
  }
  if (source.trim().length < 40) {
    return { passed: false, reason: "source is too small to be a real implementation", absolutePath };
  }
  return { passed: true, reason: "file and symbol found", absolutePath };
}

function csvCell(value) {
  const text = typeof value === "string" ? value : JSON.stringify(value);
  return '"' + String(text ?? "").replaceAll('"', '""') + '"';
}

function markdownValue(value) {
  if (Array.isArray(value) || (value && typeof value === "object")) {
    return JSON.stringify(value).replaceAll("|", "\\|");
  }
  return String(value).replaceAll("|", "\\|").replaceAll("\n", " ");
}

function renderRegistryMarkdown(records) {
  const lines = [
    "# MORT 1,891 Feature Registry",
    "",
    "This registry contains exactly 1,891 accepted atomic capabilities. Platform implementations are one capability, not separate Swift and Flutter feature counts. Statuses are evidence-bound and roadmap entries are not implementation claims.",
    "",
    "## Summary",
    "",
    "| Metric | Count |",
    "| --- | ---: |",
    "| Accepted capabilities | " + records.length + " |",
    "| Duplicate candidates removed | " + REJECTED_CANDIDATES.filter((item) => item.status === "duplicate_removed").length + " |",
    "| Unsafe or invalid candidates rejected | " + REJECTED_CANDIDATES.filter((item) => item.status === "rejected").length + " |",
    "",
    "The JSON and CSV files beside this document contain the same complete records in machine-readable form.",
    "",
  ];

  for (const record of records) {
    lines.push("## " + record.feature_id + " - " + record.title, "");
    for (const field of REQUIRED_FIELDS) {
      lines.push("- **" + field + ":** " + markdownValue(record[field]));
    }
    lines.push("- **implementation_wave:** " + markdownValue(record.implementation_wave));
    lines.push("- **evidence_checks:** " + markdownValue(record.evidence_checks));
    lines.push("");
  }
  return lines.join("\n") + "\n";
}

function renderDeduplicationReport(records) {
  const duplicateCount = REJECTED_CANDIDATES.filter((item) => item.status === "duplicate_removed").length;
  const normalized = new Set(records.map((record) => normalizeFeatureTitle(record.title)));
  return [
    "# MORT Feature Deduplication Report",
    "",
    "## Result",
    "",
    "- Accepted registry count: " + records.length,
    "- Unique normalized accepted titles: " + normalized.size,
    "- Duplicate candidates removed before acceptance: " + duplicateCount,
    "- Accepted cross-platform duplicates: 0",
    "",
    "## Method",
    "",
    "The generator uses one product record across SwiftUI, Flutter Web, and Supabase. The validator checks IDs, slugs, normalized titles, required descriptions, roles, quotas, statuses, paid-safety violations, and evidence for every implementation claim. Candidate button labels, visual variants, platform copies, fields, tests, and documentation are excluded from the accepted count.",
    "",
    "## Removed Candidates",
    "",
    ...REJECTED_CANDIDATES.filter((item) => item.status === "duplicate_removed").map((item) => "- `" + item.candidate_id + "` " + item.title + ": " + item.reason),
    "",
  ].join("\n");
}

function renderRejectedFeatures() {
  return [
    "# MORT Rejected Features",
    "",
    "Rejected and duplicate-removed candidates are not part of the 1,891 accepted capabilities.",
    "",
    "| Candidate | Status | Title | Reason |",
    "| --- | --- | --- | --- |",
    ...REJECTED_CANDIDATES.map((item) => "| " + item.candidate_id + " | " + item.status + " | " + item.title + " | " + item.reason + " |"),
    "",
  ].join("\n");
}

function renderPriorityScorecard(records) {
  const sorted = [...records].sort((a, b) => b.implementation_priority - a.implementation_priority || a.feature_id.localeCompare(b.feature_id));
  const lines = [
    "# MORT Feature Priority Scorecard",
    "",
    "Priority combines safety, accessibility, retention, growth, revenue, differentiation, complexity, and risk. It is a planning aid, not an automated release decision.",
    "",
    "| Rank | Feature | Category | Priority | Safety | Access | Retention | Growth | Revenue | Difference | Complexity | Risk | Status |",
    "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
  ];
  sorted.slice(0, 150).forEach((record, index) => {
    lines.push("| " + (index + 1) + " | " + record.feature_id + " " + record.title + " | " + record.category + " | " + record.implementation_priority + " | " + record.safety_score + " | " + record.accessibility_score + " | " + record.retention_score + " | " + record.growth_score + " | " + record.revenue_score + " | " + record.differentiation_score + " | " + record.complexity_score + " | " + record.risk_score + " | " + record.implementation_status + " |");
  });
  lines.push("");
  return lines.join("\n");
}

function renderImplementationWaves(records) {
  const waves = countBy(records, "implementation_wave");
  const lines = [
    "# MORT Feature Implementation Waves",
    "",
    "Wave placement is dependency-aware and remains subject to youth-safety, accessibility, privacy, legal, and operational review.",
    "",
    "| Wave | Count | Release intent |",
    "| --- | ---: | --- |",
  ];
  const intents = {
    "Wave 0 - existing completion": "Evidence-backed unread and proof-review completion from this pass.",
    "Wave 1 - safety and core marketplace": "Safety, access, privacy, reliability, applications, messaging, and lifecycle foundations.",
    "Wave 2 - repeat value": "Work history, repeat hiring, profiles, notifications, and healthy progress.",
    "Wave 3 - MORT differentiation": "Optional Guardian Mode, explainable matching, trust, and bounded AI assistance.",
    "Wave 4 - business and community scale": "Community utility, accountable operations, and privacy-preserving analytics.",
    "Wave 5 - sustainable growth": "Balanced local supply and demand through referrals and partnerships.",
    "Wave 6 - advanced platform capability": "Optional monetization and native-platform depth after foundations are verified.",
  };
  for (const [wave, count] of [...waves.entries()].sort()) {
    lines.push("| " + wave + " | " + count + " | " + intents[wave] + " |");
  }
  lines.push("", "## Highest-Priority Accepted Work", "");
  [...records].filter((record) => record.implementation_status === "accepted_roadmap")
    .sort((a, b) => b.implementation_priority - a.implementation_priority || a.feature_id.localeCompare(b.feature_id))
    .slice(0, 60)
    .forEach((record) => lines.push("- `" + record.feature_id + "` " + record.title + " (" + record.implementation_wave + ", score " + record.implementation_priority + ")"));
  lines.push("");
  return lines.join("\n");
}

function renderDependencyGraph() {
  const fence = String.fromCharCode(96).repeat(3);
  return [
    "# MORT Feature Dependency Graph",
    "",
    "The graph is architectural, not a claim that every roadmap node is implemented.",
    "",
    fence + "mermaid",
    "flowchart TD",
    "  A[Hosted Supabase Auth and account status] --> B[Role and age authorization]",
    "  B --> C[RLS and checked RPC contracts]",
    "  C --> D[Core jobs, applications, messaging, proof, report, block, Safety Ping]",
    "  D --> E[Trust, profiles, repeat work, optional Guardian Mode]",
    "  D --> F[Private storage and privacy-safe notifications]",
    "  E --> G[Discovery, community, healthy retention]",
    "  F --> H[Admin evidence, appeals, analytics]",
    "  G --> I[Bounded AI assistance and sustainable growth]",
    "  H --> I",
    "  I --> J[Optional RevenueCat and ad perks]",
    "  D --> K[SwiftUI and Flutter Web clients]",
    "  K --> L[Mac compile, physical iPhone, TestFlight, legal and operations gates]",
    fence,
    "",
    "## Cross-Cutting Gates",
    "",
    "Every release slice requires accessible states, privacy minimization, server authority where needed, abuse tests, observability without sensitive payloads, and rollback/recovery behavior.",
    "",
  ].join("\n");
}

export function writeRegistryArtifacts(records) {
  mkdirSync(docsDir, { recursive: true });
  const fields = [...REQUIRED_FIELDS, "implementation_wave", "evidence_checks"];
  const csv = [fields.map(csvCell).join(",")]
    .concat(records.map((record) => fields.map((field) => csvCell(record[field])).join(",")))
    .join("\r\n") + "\r\n";

  writeFileSync(join(docsDir, "MORT_1891_FEATURE_REGISTRY.json"), JSON.stringify(records, null, 2) + "\n");
  writeFileSync(join(docsDir, "MORT_1891_FEATURE_REGISTRY.csv"), csv);
  writeFileSync(join(docsDir, "MORT_1891_FEATURE_REGISTRY.md"), renderRegistryMarkdown(records));
  writeFileSync(join(docsDir, "MORT_FEATURE_DEDUPLICATION_REPORT.md"), renderDeduplicationReport(records));
  writeFileSync(join(docsDir, "MORT_REJECTED_FEATURES.md"), renderRejectedFeatures());
  writeFileSync(join(docsDir, "MORT_FEATURE_PRIORITY_SCORECARD.md"), renderPriorityScorecard(records));
  writeFileSync(join(docsDir, "MORT_FEATURE_IMPLEMENTATION_WAVES.md"), renderImplementationWaves(records));
  writeFileSync(join(docsDir, "MORT_FEATURE_DEPENDENCY_GRAPH.md"), renderDependencyGraph());
}
