# Remote Push Status

Updated: 2026-10-28

Firebase is not used by the MORT Flutter app. There is no Firebase SDK,
Firebase client configuration, or Firebase runtime path in the app. No remote
push provider has been selected for MORT.

Remote push is disabled in the production release profile. The Flutter release
gate rejects an attempt to enable it while no approved provider is available.
In-app notifications remain available independently of remote delivery.

Do not configure Firebase for MORT. Remote push can be reconsidered only after
the owner selects a non-Firebase provider and its client, server, privacy, and
delivery behavior are implemented and verified.
