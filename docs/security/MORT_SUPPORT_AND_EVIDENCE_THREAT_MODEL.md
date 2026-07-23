# Support and Evidence Threat Model

Threats: cross-user case access, staff impersonation, public object URLs, path traversal, MIME spoofing, oversized uploads, stale links, evidence tampering, prompt injection, sensitive-data leakage, unsafe AI decisions, attachment cost abuse, and conflicted staff.

Controls: private owner-prefixed Storage, JPEG/size/path constraints, server manifests/hashes, caller-bound short-lived signed URLs, request throttles, assignment/role checks, immutable access/status audit events, deterministic safety diversion, external AI off, server budgets, no raw SQL/tools, human decisions, and separated payment roles.

Residual risk: no malware/content moderation provider is connected, real support staffing is unverified, external AI/provider budgets are unconfigured, and no independent penetration test has been completed. Real identity evidence remains disabled.
