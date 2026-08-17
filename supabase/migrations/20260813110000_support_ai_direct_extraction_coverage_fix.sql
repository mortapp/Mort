-- Support AI direct extraction coverage fix (2026-08-13).
--
-- This migration narrows the classifier so that ordinary security education is
-- allowed without overblocking, while actual exfiltration attempts remain
-- blocked. It distinguishes prompt theft, secret theft, sensitive disclosure,
-- quoted hostile content, and urgent safety in the same order used by the
-- TypeScript mirror.

alter function private.support_classify_message(text)
rename to support_classify_message_20260813101000;

create or replace function private.support_classify_message(p_message text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_raw text := coalesce(p_message, '');
  v_message text := lower(
    trim(
      regexp_replace(
        translate(
          regexp_replace(
            replace(v_raw, '　', ' '),
            E'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\uFEFF]',
            '',
            'g'
          ),
          '！＂＃＄％＆＇（）＊＋，－．／０１２３４５６７８９：；＜＝＞？＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ［＼］＾＿｀ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ｛｜｝～',
          '!"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
        ),
        '[[:space:]]+',
        ' ',
        'g'
      )
    )
  );
  v_level smallint := 0;
  v_band text := 'routine';
  v_category text := 'general';
  v_intent text := 'general_support';
  v_action text := 'answer';
  v_prompt_extraction boolean := false;
  v_prompt_educational boolean := false;
  v_has_show_verb boolean := false;
  v_has_internal_target boolean := false;
  v_secret_extraction boolean := false;
  v_secret_educational boolean := false;
  v_negated_secret boolean := false;
  v_account_support boolean := false;
  v_job_pin_education boolean := false;
  v_cross_user_data_request boolean := false;
  v_sensitive_data_disclosure boolean := false;
  v_quoted_or_report_context boolean := false;
  v_quoted_security_payload boolean := false;
  v_quoted_guidance_request boolean := false;
  v_reported_security_concern boolean := false;
  v_quoted_example_context boolean := false;
  v_quoted_reporting_context boolean := false;
  v_has_quoted_text boolean := false;
  v_security_override boolean := false;
  v_authority_impersonation boolean := false;
  v_direct_prompt_target boolean := false;
  v_benign_reporting boolean := false;
  v_benign_prompt_education boolean := false;
  v_benign_context_boundary boolean := false;
  v_benign_secret_education boolean := false;
  v_guardian_account_flow boolean := false;
  v_account_education boolean := false;
  v_educational_workflow_concept boolean := false;
  v_workflow_help boolean := false;
  v_teen_job_workflow boolean := false;
  v_job_search_support boolean := false;
  v_job_workflow boolean := false;
  v_guardian_job_flow boolean := false;
  v_job_support boolean := false;
  v_active_trust_safety_report boolean := false;
  v_first_person_trust_safety boolean := false;
  v_unsafe_job_report boolean := false;
  v_reporter_generic boolean := false;
  v_scam_indicator boolean := false;
  v_database_dump boolean := false;
  v_start_finish_solicit boolean := false;
  v_reporter_solicit boolean := false;
  v_has_retrieval_verb boolean := false;
  v_has_secret_noun boolean := false;
  v_cross_user_need boolean := false;
  v_secret_need boolean := false;
  v_legacy jsonb;
begin
  v_legacy := private.support_classify_message_20260813101000(p_message);
  v_active_trust_safety_report := v_message ~ '(?:someone|a user|an adult|the adult|a stranger|they|this user|that user|the poster|the other user|another user|a person).{0,45}(?:sent|sends|sent me|keeps|keep|continued to|continue to|is trying to|are trying to|is attempting to|are attempting to|asked me|asked for|asked me for|requested|requested my|wanted me to|want me to|want to|wants me to|wants|told me|told me to|told me not to|told a teen|told the teen|said|said to|made me|pressured me|kept|need me to|asked to see|asked to view).{0,100}(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|verification code|pin|password|social security|ssn|passport|driver.?s license|card number|cvv|cvc|home address|address|cashapp|gift card|move.*off-platform|off-platform|private data|messages|transcript|profile data|keep this a secret|secret|scam|fraud|weapon|knife|gun|alcohol|circular saw|no supervision|unsafe|alone|rape|assault)';
  v_first_person_trust_safety := v_message ~ '(?:i (?:received|got|was sent|got sent|received a|was sent a|got a)).{0,80}(?:threat|stalk|harass|blackmail|extort|nude|sexual|private photo|scam|fraud|weapon|knife|gun|rape|assault|pressured|asked for|requested|asked me to|asked for my|requested my)';
  v_unsafe_job_report := v_message ~ '(?:feel unsafe|unsafe at).{0,40}(?:job|work|at the job|at work)';
  v_reporter_generic := v_message ~ '(?:received|got a message|i received|i got|was sent|dmed|dm|received a).{0,80}(?:asked|asked for|asked me to|told me to|told me|requested|requested my|pressured|blackmail|threat|extort|scam|fraud|asked that)';
  v_scam_indicator := v_message ~ '(?:looks like a scam|this looks like a scam|scam or fraud|this is a scam|possible scam|suspected fraud)';
  v_database_dump := v_message ~ '(?:dump|dump the|dump the profiles|return all database|dump.*table|dump profiles|return all rows|dump the table|export.*database|different conversation|other conversation|different transcript|other transcript)';
  v_start_finish_solicit := v_message ~ '(?:send me|give me|send|please send).{0,40}(?:finish code|start code|finish pin|start pin|finish code before|send the finish code)';
  v_reporter_solicit := v_message ~ '(?:someone|a user|they|this message|a message|the sender|the other user|i received|i got|i was sent|received a message|got a message|dm|dmed).{0,80}(?:asked|asked me|asked for|asked that i|told me to|told me|requested|requested my|wanted me to|want me to|pressured me|tried to make me).{0,140}(?:verification code|cvv|cvc|password|card number|ssn|social security|service.?role key|api key|private transcript|messages|profile data|developer message|system prompt|code|pin|finish pin|start pin)';

  v_quoted_security_payload := v_message ~ '(?:someone|a user|a stranger|a message|this message|i saw|i received|i found|friend|review|comment|post|conversation).{0,45}(?:said|asked|quoted|wrote|sent|shared|pasted|posted|contained|containing|with the words).{0,30}["''].{0,140}["'']';
  v_quoted_guidance_request := v_message ~ '(?:report|block|flag|handle|guidance|what should i do|is (?:that|this) (?:suspicious|a scam|a problem|malicious)|safety concern)';
  v_reported_security_concern := v_message ~ '(?:someone|a user|a stranger|a message|this message|they).{0,55}(?:asked|requested|wanted|told|sent|wrote).{0,70}(?:password|verification code|pin|cvv|cvc|card number|home address|api key|service-role key|system prompt|developer message)';
  v_quoted_example_context := v_message ~ '(?:i saw|someone|a user|a stranger|they|friend|review|comment|post|message|chat|conversation).{0,35}(?:said|quoted|wrote|shared|pasted|sent|posted|messaged|commented).{0,35}["'']|(?:quote|quoted|example|for example).{0,40}(?:system prompt|developer message|verification code|password|cvv|cvc|api key|service-role key|transcript|messages|profile data|database|instructions|rules|account details|account)';
  v_quoted_reporting_context := v_message ~ '(?:someone|a user|a stranger|they|this message|a message|i saw|friend|review|comment|post).{0,25}(?:said|told me|asked|quoted|messaged me|wrote|posted|sent|shared|pasted|with the words).{0,25}["''].{0,100}(?:system prompt|developer message|verification code|cvv|cvc|password|card number|ssn|service.?role key|api key|private transcript|transcript|messages|profile data|database|instructions|rules|developer mode|account details|account).{0,80}["'']|["''].{0,80}(?:show me|print|reveal|send|give|read back|dump|tell|ignore).{0,40}(?:system prompt|developer message|service-role key|verification code|password|transcript|database|instructions|rules|cvv|card number|ssn|account details|account).{0,80}["'']';
  v_has_quoted_text := v_message ~ '["''].+["'']';
  v_quoted_or_report_context :=
    (v_quoted_security_payload and v_quoted_guidance_request)
    or (v_reported_security_concern and v_quoted_guidance_request)
    or (v_quoted_reporting_context and not v_quoted_example_context);
 
  v_direct_prompt_target := v_message ~ '(?:your (?:system )?prompt|your hidden instructions|your internal instructions|the developer message|the system prompt|the service-role key|the (?:hidden|internal|confidential) instructions)';
  v_has_show_verb := v_message ~ '(?:^|[^[:alnum:]_])(?:show(?: me)?|print|reveal|translate|summarize|read back|repeat|return|dump|share|display|expose|tell(?: me)?|give(?: me)?|paste|post|copy|send over|spill|leak|what(?:''s| is| are)|can you|could you|would you)(?:$|[^[:alnum:]_])';
  v_has_internal_target :=
    v_message ~ '(?:your|the|internal|hidden|private|confidential).{0,30}(?:prompt|system prompt|system message|system instruction|developer message|developer instruction|service-role key|hidden instruction|private instruction|confidential instruction|rules|operating rules)s?'
    or v_message ~ '(?:prompt|system prompt|system message|system instruction|developer message|service-role key|developer instruction|rules)s?.{0,35}(?:show|print|reveal|read back|repeat|return|dump|display|expose)';
  v_prompt_extraction := v_has_show_verb and (v_has_internal_target or v_direct_prompt_target);
  v_prompt_educational := v_message ~ '(?:what is a|what''s a|how does a|how do (?:system prompts|system prompt)|can you explain what a|why (?:are|should)|what does (?:prompt extraction|prompt injection)|in general terms|normal purpose|difference between).{0,100}(?:system prompt|developer message|service-role key|hidden instructions|developer instructions|prompt extraction|prompt injection|internal instructions|private rules)|(?:without|not).{0,25}(?:revealing|exposing|showing|sharing).{0,40}(?:(?:your|the) )?(?:internal )?(?:prompt|instructions|rules|message|key)';
 
  v_has_retrieval_verb := v_message ~ '(?:^|[^[:alnum:]_])(?:tell(?: me)?|show(?: me)?|send(?: me)?|give(?: me)?|read(?: back)?|print|reveal|share|display|return|dump|expose|provide|what(?:''s| is| are)|can you|could you|would you)(?:$|[^[:alnum:]_])';
  v_has_secret_noun := v_message ~ '(?:^|[^[:alnum:]_])(?:password|verification code|otp|one-time code|one time code|one-time passcode|passcode|pass code|pass-code|cvv|cvc|pin|ssn|passport|card number|api key|api token|secret key|service-role key|service role key|recovery code|2fa code)(?:$|[^[:alnum:]_])';
  v_secret_need := v_message ~ '(?:i need|i need to|get me|i need the|i need my).{0,40}(?:password|verification code|otp|one-time code|one time code|one-time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service-role key|service role key|home address|driver.?s license|recovery code|2fa code)';
  v_secret_extraction := v_message ~ '(?:tell(?: me)?|show(?: me)?|send(?: me)?|give(?: me)?|read(?: back)?|print|reveal|share|display|return|dump|expose|provide).{0,35}(?:my|the|your|another user''s|someone else''s).{0,50}(?:password|verification code|otp|one-time code|one time code|one-time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service-role key|service role key|home address|driver.?s license|recovery code|2fa code)|(?:what(?:''s| is| are)|can you|could you|would you).{0,25}(?:the|my|your).{0,20}(?:password|verification code|otp|one-time code|one time code|one-time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service-role key|service role key|home address|driver.?s license|recovery code|2fa code)|(?:password|verification code|otp|one-time code|one time code|one-time passcode|passcode|pass code|pass-code|cvv|cvc|finish ?pin|start ?pin|ssn|passport|card number|api key|api token|secret key|service-role key|service role key|home address|driver.?s license|recovery code|2fa code).{0,35}(?:for me|to me|right now|please|now|you use|on file|that is on file|here)';

  v_cross_user_need := v_message ~ '(?:need|i need|i need to|get me|i need the).{0,40}(?:another user|other user|someone else''s|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details)';
  v_cross_user_data_request := v_message ~ '(?:show|give|return|reveal|dump|print|expose|share|get|access).{0,20}(?:me|us).{0,20}(?:another user|other user|someone else|a different user|every user).{0,60}(?:messages|transcript|profile|account|records|data|details)|(?:show|return|reveal|dump|print|expose|share|get|access).{0,40}(?:another user|other user|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details)|(?:another user|other user|someone else).{0,60}(?:private|profile|account|messages|transcript|records|data|details).{0,50}(?:show|give|return|reveal|dump|print|expose|access|share|get)|(?:show|give|return|reveal|dump|print|expose|share|get|access).{0,40}(?:from|for).{0,20}(?:another user|other user|someone else''s|someone else|a different user).{0,60}(?:messages|transcript|profile|account|records|data|details|session)';

  v_sensitive_data_disclosure := v_message ~ '(?:can i (?:give|send|share|paste|provide|tell)|should i (?:paste|share|send|provide|give|tell)|do you (?:need|want)|would i (?:give|share|send|tell)|i (?:will|can|could|would) (?:give|send|share|paste|provide|tell)|i(?:[''’]ll| will) (?:give|send|share|paste|provide|tell)).{0,45}(?:ssn|social security|card number|verification code|cvv|cvc|passport|driver(?:.?s)? license|home address|address|password|pin|api key|api token|secret key|service-role key|2fa code|passcode|one-time code|otp|phone number)';

  v_negated_secret := v_message ~ '(?:never|do not|don.?t|would not|wouldn.?t|i would never|i won.?t|will not|not going to|won.?t|not asking|not asking for|this is not a request).{0,60}(?:password|verification code|otp|one-time code|passcode|cvv|cvc|pin|ssn|passport|card number|api key|api token|secret key|service-role key|home address|driver.?s license|code)';
  v_account_support := v_message ~ '(?:reset|change|update|recover|verify|login|sign.?in|sign.?out|log.?out|locked out|account password|password reset|password change|account email|login link expired|identity review|verification status)';
  v_secret_educational := v_message ~ '(?:how (?:do|can)|how to|what is|what''s|what are|why should|can you explain|where do i|where is).{0,60}(?:password|verification code|otp|one-time code|passcode|pin|cvv|cvc|api key|api token|secret key|service-role key)';
  v_job_pin_education := v_message ~ '(?:how|what|why|where|when|which|is|can).{0,70}(?:(?:job|start|finish|arrival|end).{0,25}(?:pin|code)|(?:pin|code).{0,25}(?:job|start|finish|arrival|end))';

  v_benign_reporting := v_message ~ '(?:how should i report|what should i do|is that suspicious).{0,40}(?:prompt-injection|prompt extraction|attack)|(?:i saw|someone|a user|a stranger|they|friend).{0,35}(?:ask(?:ed)? for|asked|told me|requested|sent|said).{0,40}(?:system prompt|developer message|service-role key|verification code|password|cvv|api key|private transcript|cvc|ssn).{0,40}(?:should i report|what should i do|is that suspicious|scam)';
  v_benign_prompt_education := v_message ~ '(?:how do i|why should(?: i)?|where do i|what is a|what''s a|what does|what are|can you explain|why are|how does|how can i|what should i do|can i|should i|is that suspicious|ask a question about).{0,60}(?:system prompt|developer message|developer instructions|prompt extraction|internal instructions|hidden instructions)';
  v_benign_context_boundary := v_message ~ '(?:not asking|not a request|not asking for|not (?:for|trying to perform) (?:a )?(?:jailbreak|bypass|prompt extraction)|don.?t want to (?:see|access|get)|not to (?:send|make)|public (?:job )?safety guide|in training.{0,40}(?:understand|what))';
  v_benign_secret_education := v_message ~ '(?:how do i|why should(?: i)?|where do i|what is a|what''s a|what does|what are|where is|why does|can you explain|why are|how does|how can i|what should i do|can i|should i|is that suspicious|ask a question about).{0,80}(?:password|verification code|pin|cvv|cvc|api keys?|api tokens?|secret keys?|service-role keys?|security settings|card details|address|exact address|recovery code|2fa|otp|social security|passport|driver.?s license|home address|ssn|passcode|one-time code|one-time passcode)';
  v_guardian_account_flow := v_message ~ '(?:guardian.*(?:account|settings|link|unlink|profile|mode|dashboard|contact|screen|login|access|help|support|reset|password|verification)|(?:link|unlink|login|access|settings|help|support|setup|screen|profile|dashboard|verification|password).*(?:guardian|parental|caregiver)|guardian mode|account.*guardian|guardian.*dashboard|guardian.*contact|guardian.*profile|guardian.*screen|guardian.*settings|parental controls|teen.*guardian)';
  v_account_education := v_message ~ '(?:^|[^[:alnum:]_])(?:how do i|how can i|what is|what''s|what are|where do i|why do i|can i|could i|should i|what should i do|is there a way to)(?:$|[^[:alnum:]_]).{0,70}(?:^|[^[:alnum:]_])(?:account|login|sign-in|sign-out|log-in|log-out|password|verification|verify|email|security settings|2fa|passcode|locked out)(?:$|[^[:alnum:]_])|(?:^|[^[:alnum:]_])(?:account|login|sign-in|sign-out|log-in|log-out|password|verification|verify|email|security settings|2fa|passcode|locked out)(?:$|[^[:alnum:]_]).{0,70}(?:^|[^[:alnum:]_])(?:how do i|how can i|what is|what''s|what are|where do i|why do i|can i|could i|should i|what should i do|is there a way to)(?:$|[^[:alnum:]_])';
  v_educational_workflow_concept := v_message ~ '(?:what is|what''s|what are|what does|how does|can you explain|explain what|difference between|how does a).{0,60}(?:account|profile|login|password|verification|payment|privacy|report|block|safety|guardian|pin|settings)';
  v_workflow_help := v_message ~ '(?:how do i|how can i|what should i do|can i|could i|where do i|i need help|can you help me|help me with|need help with).{0,60}(?:(?:find|search|apply|review|save|close|edit|pin|withdraw|track|check|view|get|look).{0,30}(?:job|jobs|application|applications|listing|work|gig|shift|role)|(?:job|jobs|application|applications|listing|work|gig|shift|role).{0,30}(?:search|find|apply|review|save|close|edit|pin|withdraw|track|check|view|get|look))';
  v_teen_job_workflow := v_message ~ '(?:teen|minor|under 18|underage).{0,80}(?:(?:look for|search for|search|find|apply|review|status|pin).{0,40}(?:job|work|application|listing|gig|shift|employment)|(?:job|work|application|listing|gig|shift|employment).{0,40}(?:search|find|apply|review|status|pin))|(?:look for|search for|search|find|apply|review|status|pin).{0,40}(?:job|work|application|listing|gig|shift|employment)';
  v_job_search_support := v_message ~ '(?:(?:find|search|view|apply|review|save|close|edit|pin|track|check|withdraw|get|look|need|want).{0,40}(?:jobs?|applications?|listings?|work|roles?|gigs?|shifts?)|(?:jobs?|applications?|listings?|work|roles?|gigs?|shifts?).{0,40}(?:search|find|apply|review|save|close|edit|pin|track|check|withdraw|get|view|need|want)|(?:job search|find a job|search for jobs|looking for work|look for work|get a job|get jobs|find jobs|apply for a job|need a job|want a job|need work|want work|looking for a job|looking for jobs|job listings|nearby jobs))';
  v_job_workflow := v_message ~ '(?:application|applications|job application|job applications|apply(?:ing)? for a job|withdraw(?:ing)? an application|job status|job history|job details|job category|save a job|close a completed job|review.*application|approve.*application|guardian.*application|application.*status|job.*distance|distance.*job|post(?:ed|ing)? a job|edit.*job listing|job.*listing|application.*pending|pending.*application|close.*listing|review.*job|job.*review|application.*review|find jobs|search jobs|job search|nearby jobs|job.*pin|pin.*job|job poster|post.*job|listing.*status|manage.*listing|how do i.*(?:search|find|get|apply|review|pin|look for|search for).*?(?:job|work)|how can i.*(?:search|find|get|apply|review|pin|look for|search for).*?(?:job|work)|(?:look for|search for|find|search|get|apply|review|status|pin|track|check|save|close|withdraw).*?(?:job|work|application|listing))';
  v_guardian_job_flow := v_message ~ '(?:guardian.*(?:job|jobs|work|application|applications|listing|listings|settings)|(?:job|jobs|work|application|applications|listing|listings).*guardian|guardian.*(?:settings.*(?:job|work|application|listing)|(?:job|work|application|listing).*(?:settings|profile)))';
  v_job_support := v_workflow_help
    or v_teen_job_workflow
    or v_job_search_support
    or v_job_workflow
    or v_guardian_job_flow
    or v_message ~ '(?:^|[^[:alnum:]_])(?:jobs?|applications?|listings?)(?:$|[^[:alnum:]_])|job pin|start pin|finish pin|start code|finish code|work location|pin screen|pin instructions|code i need before i start';

  v_security_override := v_message ~ '(?:ignore|disregard|forget|override|bypass|replace|reset|discard|remove|skip|break).{0,60}(?:previous|earlier|all|your|the).{0,60}(?:instructions|guidelines|rules)|for this reply only|ignore everything above|forget everything above|no restrictions|new system message';
  v_authority_impersonation := v_message ~ '(?:as the system administrator|as an admin|mort staff|mort developer|developer mode|authorized override|this is an authorized override|i am.*(?:mort )?(?:staff|developer|admin|administrator))';

  if v_message ~ 'suicid|kill myself|kill me|hurt myself|self.?harm|kill (him|her|them|someone)|kidnap|abduct|traffick|immediate danger|being followed right now|sexual assault|rape|won.?t let me leave|trapped at.*job|csam|child pornography|underage nude|end(ing)? my life|want(ing)? to die|no reason to (live|keep going)|not worth living|(don.?t|do not) want to (live|be alive)|i do not want to live|i do not want to be alive|there is (a )?(gun|knife|weapon) (here|at)|(?:someone|a person).{0,30}(?:has|brought|pulled out|pointed).{0,15}(?:gun|knife|weapon)|(?:gun|knife|weapon).{0,30}(?:pointed|attacked|threat|scared)|(?:they|someone|the person|the attacker).{0,40}(?:is going to|going to|gonna).{0,20}(?:kill|murder|rape|stab|shoot)|(?:being threatened|being attacked|being assaulted).{0,30}(?:right now|now|here)|(?:pointed|pointing|threatened|threaten|threat|attack|assault|stab|shoot).{0,40}(?:gun|knife|weapon|shoot|stab|murder|kill)|(?:gun|knife|weapon|shoot|stab|murder|kill).{0,40}(?:pointed|pointing|threatened|threat|attack|assault|someone here|someone near me|someone has)|(?:(?:i need help|help me|need help).{0,40}(?:now|right now|immediately).{0,80}(?:ignore|disregard).{0,40}(?:instruction|rule|developer|guideline))' then
    v_level := 3;
    v_band := 'urgent';
    v_category := 'urgent_safety';
    v_intent := 'safety_emergency';
    v_action := 'safety_center';
  elsif v_quoted_or_report_context then
    v_level := 1;
    v_band := 'concern';
    v_category := 'quoted_hostile_content';
    v_intent := 'report_or_block';
    v_action := 'offer_handoff';
  elsif v_active_trust_safety_report
      or v_first_person_trust_safety
      or v_unsafe_job_report
      or v_reporter_generic
      or v_scam_indicator
      or v_start_finish_solicit
      or v_reporter_solicit then
    v_level := 2;
    v_band := 'serious';
    v_category := 'trust_safety';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_database_dump then
    v_level := 2;
    v_band := 'serious';
    v_category := 'cross_user_data_request';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_prompt_educational and not v_direct_prompt_target then
    v_level := 0;
    v_band := 'routine';
    v_category := 'general';
    v_intent := 'general_support';
    v_action := 'answer';
  elsif (v_authority_impersonation or v_security_override)
      and not v_quoted_example_context
      and not v_benign_reporting then
    v_level := 2;
    v_band := 'serious';
    v_category := case
      when v_authority_impersonation then 'authority_impersonation'
      else 'security_override'
    end;
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_prompt_extraction
      and not v_prompt_educational
      and not v_quoted_example_context
      and not v_benign_reporting then
    v_level := 2;
    v_band := 'serious';
    v_category := 'prompt_extraction';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif (
      (
        v_has_retrieval_verb
        and v_has_secret_noun
        and not v_negated_secret
        and not v_secret_educational
        and not v_sensitive_data_disclosure
        and not v_account_support
        and not v_quoted_example_context
        and not v_benign_reporting
      )
      or (
        v_secret_need
        and not v_negated_secret
        and not v_account_support
        and not v_job_pin_education
      )
      or (
        v_secret_extraction
        and not v_negated_secret
        and not v_sensitive_data_disclosure
        and not v_quoted_example_context
        and not v_benign_reporting
      )
    ) then
    v_level := 2;
    v_band := 'serious';
    v_category := 'secret_extraction';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_cross_user_need or v_cross_user_data_request then
    v_level := 2;
    v_band := 'serious';
    v_category := 'cross_user_data_request';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_sensitive_data_disclosure
      and not v_secret_educational
      and not v_negated_secret
      and not v_benign_reporting then
    v_level := 1;
    v_band := 'concern';
    v_category := 'sensitive_data_disclosure';
    v_intent := 'privacy_or_deletion';
    v_action := 'required_handoff';
  elsif v_message ~ '(?:don.?t tell.*(?:guardian|parent)|keep this a secret|without telling anyone|alcohol.*teen|circular saw.*alone|alone with no supervision|no supervision|secret between us)' then
    v_level := 2;
    v_band := 'serious';
    v_category := 'guardian_bypass';
    v_intent := 'report_or_privacy';
    v_action := 'required_handoff';
  elsif v_benign_reporting then
    v_level := 0;
    v_band := 'routine';
    v_category := 'general';
    v_intent := 'general_support';
    v_action := 'answer';
  elsif v_benign_context_boundary or v_benign_prompt_education then
    v_level := 0;
    v_band := 'routine';
    v_category := 'general';
    v_intent := 'general_support';
    v_action := 'answer';
  elsif v_message ~ '(?:profile photo|username|public profile|ratings? and reviews?|ratings?|respond to a review|remove a review|review i wrote|low rating|difference between a rating and a review|transportation preference|availability|saved filters|completed jobs on my profile|profile temporarily|profile settings|profile is active)' then
    v_level := 0;
    v_band := 'routine';
    v_category := 'general';
    v_intent := 'general_support';
    v_action := 'answer';
  elsif v_message ~ '(?:safety center|safety.*(?:center|settings|policy|guidelines)|report.*(?:user|message)|block.*(?:profile|user)|where is the report button|how do i report|how do i block|how do i review my safety settings|how do i contact support about a safety issue|what is the difference between reporting and blocking|safety settings|safety policy|safety guidelines|feel uncomfortable|uncomfortable.*(?:job|work)|job seems unsafe|unsafe.*(?:job|work)|help.*(?:unsafe|safety)|safety issue|safety concern|support.*safety|report.*or.*block|block.*someone|i want to block|blocked users|report someone|report inappropriate conduct|feel unsafe|hide exact addresses|submit a report|undo a report|safer job practices|unsafe work environment)' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'trust_safety';
    v_intent := 'report_or_block';
    v_action := 'offer_handoff';
  elsif v_message ~ '(?:privacy|delete.*account|account delet|account data|data.*visible|visible to others|exact address|address visibility|conversations after deletion|message settings)' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'privacy';
    v_intent := 'privacy_or_deletion';
    v_action := 'offer_handoff';
  elsif v_message ~ '(?:^|[^[:alnum:]_])human(?:$|[^[:alnum:]_])|(?:real person|support agent|talk to (?:a )?person|contact support|support hours|schedule a call|phone number|screenshot for help|support topic|follow up on|existing ticket|payment question from support|explain a problem to support|support message|support.*escalated|email support|support resources|support usually take)' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'support';
    v_intent := 'human_handoff';
    v_action := 'required_handoff';
  elsif v_message ~ '(?:payment|paid|unpaid|refund|dispute|payout|billing|charge)' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'billing';
    v_intent := 'payment_or_dispute';
    v_action := 'offer_handoff';
  elsif v_job_support
      and not (
        v_educational_workflow_concept
        and not v_job_search_support
        and not v_job_workflow
        and not v_teen_job_workflow
      ) then
    v_level := 1;
    v_band := 'concern';
    v_category := 'marketplace';
    v_intent := 'jobs_or_applications';
    v_action := 'offer_handoff';
  elsif v_guardian_account_flow or v_account_education or v_benign_secret_education then
    v_level := 1;
    v_band := 'concern';
    v_category := 'account';
    v_intent := 'account_access';
    v_action := 'offer_handoff';
  elsif v_message ~ '(?:identity|verif|login|sign.?in|account)' then
    v_level := 1;
    v_band := 'concern';
    v_category := 'account';
    v_intent := 'account_access';
    v_action := 'offer_handoff';
  elsif v_quoted_example_context or v_has_quoted_text then
    v_level := 0;
    v_band := 'routine';
    v_category := 'general';
    v_intent := 'general_support';
    v_action := 'answer';
  else
    return v_legacy;
  end if;

  return jsonb_build_object(
    'level', v_level,
    'triage_band', v_band,
    'category', v_category,
    'intent', v_intent,
    'action', v_action,
    'provider_allowed', v_level < 2 and v_intent <> 'human_handoff'
  );
end;
$$;

revoke all on function private.support_classify_message(text)
from public, anon, authenticated;
grant execute on function private.support_classify_message(text)
to service_role;
