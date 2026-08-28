# Vibe Security Skill Review

Review date: 2026-07-22

Repository: `https://github.com/raroque/vibe-security-skill`

Reviewed commit: `850938f20f6915e7c3688d85c0a838f7909c87bb`

## Supply-Chain Review

- Repository owner displayed by GitHub: `raroque`.
- Four-commit public repository with MIT license at review time.
- Inspected `vibe-security/SKILL.md`, `agents/openai.yaml`, and every Markdown file under `vibe-security/references`.
- Inspected the complete Git tree and searched for package installation, executable hooks, scripts, process execution, network calls, and file reads/writes.
- The skill contains Markdown and YAML only. There is no package manifest, executable hook, install script, or runtime code.
- README contains installation instructions and external badge/author links; the installed skill itself does not perform those network calls.

The exact commit was installed to the personal Codex skill directory with the reviewed installer helper. It becomes available to a newly loaded task. This task also manually applied all nine categories: secrets, database, auth, rate limits, payments, mobile, AI, deployment, and data/input validation.

The external skill is an additional checklist, not an independent penetration test and not a replacement for Supabase advisors, direct RLS/Storage tests, payment tests, dependency scans, device tests, or qualified review.
