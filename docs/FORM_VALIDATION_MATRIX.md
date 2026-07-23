# Form Validation Matrix

| Flow | Validation | Repeat-tap lock |
| --- | --- | --- |
| Sign in/sign up/reset | Email, password length, autofill, safe errors | Yes |
| Age/profile | `MM/DD/YYYY` DOB normalized to ISO, real calendar date, role range, name/city/state | Yes for save |
| Payment preference | Required Cash App tag or secure Square URL | Yes |
| Job post | Required lengths, state, decimal pay, prohibited terms | Yes |
| Application | Proposal max 500 characters | Yes |
| Message | Non-empty, max 2,000, backend scanner | Yes |
| Report | Reason, details required for Other, max 1,000 | Yes |
| Support | Subject 4-120, message 10-2,000 | Yes |
| Safety Ping | Explicit confirmation and optional note | Yes |

Server constraints and RLS remain authoritative after client validation.
