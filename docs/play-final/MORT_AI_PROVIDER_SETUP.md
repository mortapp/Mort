# MORT Guide Provider Setup

Closed-test default is `faq_only`: approved MORT knowledge only, no external model, no provider cost, and no prompt leaves MORT. `ai-support` is deployed but external generation remains disabled because provider secrets are absent.

To test sandbox mode later:

1. Obtain policy/legal approval for teen data handling and provider-specific minor consent.
2. Set `OPENAI_API_KEY`, `MORT_AI_MODEL`, `MORT_AI_DAILY_BUDGET_USD`, `MORT_AI_MAX_INPUT_TOKENS`, and `MORT_AI_MAX_OUTPUT_TOKENS` only as Supabase Edge Function secrets.
3. Keep database runtime mode `sandbox`; approve only named QA users and use synthetic prompts.
4. Verify input and output moderation, `store: false`, timeout/retry behavior, daily/user limits, consent withdrawal, deletion, export, high-stakes refusal, and emergency escalation.
5. Review provider logs and MORT safety events without copying private prompt content into analytics.

Production mode additionally requires adult account-owner approval, updated privacy disclosures, legal review, budget monitoring, incident response, deletion testing, and an explicit runtime-control change. The Flutter app never receives the OpenAI key. References: [Responses API](https://platform.openai.com/docs/api-reference/responses) and [Moderations API](https://platform.openai.com/docs/api-reference/moderations).
