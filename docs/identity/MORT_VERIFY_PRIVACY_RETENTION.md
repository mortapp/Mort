# MORT Verify Privacy and Retention

## Data minimization

MORT Verify stores the minimum information needed to make and audit a verification decision. School affiliation, age assurance, and identity status are stored as separate results.

The client re-encodes submitted school-ID images to JPEG before upload, removing ordinary source image metadata. Raw documents are stored only in the private teen-school-id Storage bucket.

## Access

Ordinary users cannot list or download another user's school ID. A reviewer needs:
1. an active verification-review role,
2. an active case assignment,
3. an access reason and case identifier, and
4. a short-lived evidence access grant.

Review decisions are also guarded by a database trigger requiring an active assignment and evidence grant.

## Retention

School-ID metadata receives a retention deletion timestamp, defaulting to 30 days. A preservation timestamp may defer deletion for a legitimate hold.

The retention worker:
- lists only expired, unpreserved evidence with no active reviewer assignment/grant,
- removes the object through the Storage API,
- then finalizes metadata deletion and writes a safe audit event.

Account deletion uses the existing owner-based Storage cleanup and therefore also covers the teen-school-id bucket for user-owned objects.

Production collection must remain disabled until legal/privacy approval and trained reviewer operations are recorded in the server control row.
