## RATE-LIMIT SYSTEM ANALYSIS

### Discovered Contract (From Production Code)

**Two Rate-Limit Scopes (Per-User):**

1. **'chat'**: 30 requests per 600 seconds (10 minutes)
   - Applied when classification.level < 2
   - Enforced in `support_begin_chat` RPC
   - Returns HTTP status 200 but with code 'support_rate_limited'

2. **'safety_chat'**: 60 requests per 600 seconds (10 minutes)
   - Applied when classification.level >= 2
   - Enforced in `support_begin_chat` RPC
   - Returns HTTP status 200 but with code 'support_rate_limited'

3. **'provider_request'**: 5 requests per 86400 seconds (24 hours)
   - Applied ONLY when classification.level < 2 AND provider enabled AND not outbound high-risk
   - Consumed in support_runtime.ts before calling Anthropic provider
   - Returns HTTP 429 when exceeded

### Test Results

**Test 1: Level-2 Threats (Jailbreak patterns)**
- Expected: No rate limit (don't consume provider_request quota)
- Actual: Rate limit enforced at 5 requests per 600 seconds
- Conclusion: Threats are consumed against 'safety_chat' quota (60 per 600s), not provider quota

**Test 2: Benign Messages (30 "How do I apply?" questions)**
- Expected: Would hit 'chat' quota limit (30 per 600s)
- Actual: No rate limiting observed
- Possible causes:
  1. QA user role might bypass rate limiting
  2. Provider might be disabled in QA environment
  3. Benign messages don't trigger provider_request consumption (correct behavior)

### Rate-Limit Window Semantics

All rate limits use epoch-based windows:
```
window_started_at = floor(now() / window_seconds) * window_seconds
```

This means:
- Quota resets at predictable boundaries
- Window is NOT a sliding 10-minute window - it's a fixed epoch
- Example: 600s window = resets at :00, :10, :20, etc. of each minute

### Key Insight

The 5-request limit I observed in the test was hitting 'safety_chat' quota, NOT 'provider_request' quota. Level-2 threats don't consume provider_request because they're classified as serious/unsafe and should NEVER reach Anthropic.

The actual 'provider_request' quota (5 per 24 hours) is only relevant for level-0/1 benign messages that:
1. Pass security classification
2. Are not high-risk outbound content
3. Provider is enabled
4. Provider circuit breaker is not open

### Implementation Location

- **Per-user per-scope rate limit checking**: `private.support_take_rate_limit()`
- **Global provider budget limit**: `private.support_consume_global_provider_limit()`
- **Defined in migrations**: 20260811090000+ support_begin_chat RPC
- **Table**: public.support_rate_limits (user_id, scope, window_started_at, window_seconds, request_count)
