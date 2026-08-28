> RECOMMENDED - ADULT ACCOUNT OWNER MUST CONFIRM

| Console field | Recommended answer | Evidence | Owner confirmation | Risk if incorrect |
|---|---|---|---|---|
| In-app path | Settings > Account > Delete account | AccountDeletionRequestScreen | [ ] | Discovery requirement failure |
| Web path | Public /account-deletion/ with private email ownership link | Legal site package and web QA | [ ] | User Data policy rejection |
| Enumeration | Generic response regardless of account existence | Web client and enumeration QA | [ ] | Account disclosure |
| Security | Recent reauth, one-use expiring token, replay and cross-user rejection | Deletion QA suites/RPCs | [ ] | Account takeover/deletion |
| Retention | Ordinary data removed; narrow legitimate evidence documented and access restricted | Retention policy/schema | [ ] | Misleading deletion claim |
