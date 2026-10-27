# New MORT production Supabase project

This directory is isolated from the repository's historical `supabase/`
configuration, which still targets `mort-mobile` and its legacy migration
history. The destination is `jxbnrkasktbhtiujkhay` and is configured in the
nested `supabase/config.toml` here.

The destination currently has seven applied migrations, but their SQL source
files are not present in the Flutter repository. Do not push the historical
root migration chain to the destination. New destination changes are kept in
this directory and applied as forward-only migrations after review; retain the
exact SQL here so the source matches the recorded remote migration.

`20261027072203_mort_job_interests.sql` adds the first client-backed
recommendation signal. It stores only a teen's own job-interest edges, enables
RLS, and grants access only to active teen owners. It does not expose those
signals to posters, other users, or anonymous clients.

`20261027073519_mort_protect_exact_job_address.sql` removes broad table-level
job reads and grants authenticated clients access only to the non-address job
columns. Exact job addresses are not readable through the Data API; a future
assignment workflow must add a narrowly authorized, time-bounded access path.

`20261027082432_mort_enforce_job_age_eligibility.sql` derives applicant age
from the account profile and enforces each job's configured age range both
when applying and again when an adult accepts an application. The second check
prevents stale or directly inserted applications from bypassing eligibility.
