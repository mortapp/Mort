# MORT Verify RLS and Authorization Matrix

| Surface | Ordinary teen | Other user | Guardian | Reviewer | Service role |
| --- | --- | --- | --- | --- | --- |
| Private verification tables | No direct access | No | No | No direct table access | Yes |
| Start/read own verification via RPC | Own account only | No | No | No special bypass | Yes |
| School-ID Storage upload | Own active session only | No | No | No | Yes |
| School-ID direct owner download | No policy | No | No | Assigned reviewer only | Yes |
| Unregistered upload cleanup | Own path only | No | No | No | Yes |
| Review queue metadata | No | No | No | Role + audit context | Yes |
| Raw school-ID review | No | No | No | Assignment + 5-minute grant + role | Yes |
| Review decision | No | No | No | Assignment + evidence grant + role | Yes |
| Retention purge | No | No | No | No | Yes |

All new private tables have RLS enabled and client grants revoked. No permissive public table policy is introduced for raw verification data.

Storage helpers additionally bind supplied user/reviewer identifiers to auth.uid(), so they cannot be used as cross-account state probes.
