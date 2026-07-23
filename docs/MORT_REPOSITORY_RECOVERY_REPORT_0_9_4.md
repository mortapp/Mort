# MORT Repository Recovery Report 0.9.4

Date: 2026-07-22

## Recovery result

- Authoritative working tree: `C:\Users\micha\Mort`
- Authoritative Flutter application: `C:\Users\micha\Mort\flutter_mort`
- Reported GitHub repository: `https://github.com/mortapp/Mort.git`
- Verified remote default branch: `main`
- Verified remote tip at recovery time: `7bcfca79a5a41708d3ccc7d0342f1dc9ade56008`
- Recovered history mirror: `C:\Users\micha\MortRepositoryRecovery\Mort.git`
- Target completion branch: `mort-0.9.4-completion-security`
- Recovery baseline commit: `33013561adf3f163616dcd9ab73d86509df3edcf`

## What was found

The authoritative directory contained the current MORT source and a newly
initialized `.git` directory with no commits, no reflog, and no local Git
objects. The source was therefore a disconnected working copy, not a Git
history that could be repaired from local objects.

The reported GitHub repository was reachable without credentials and its
existing history was fetched without checking out or replacing any working
files. The remote contains five reachable commits, including the `main` tip
shown above. A mirror clone was made outside the project directory before any
history attachment work.

## Discovered Git roots

- `C:\Users\micha\Mort\.git`: fresh, empty metadata attached to the
  authoritative source before recovery.
- `C:\Users\micha\MortRepositoryRecovery\Mort.git`: history-preserving mirror
  created during this recovery.
- `C:\Users\micha\Mort\build\security\vibe-security-skill\.git`: generated,
  excluded security-tool evidence; not MORT source history.
- Other Git directories found under the user profile belonged to Codex
  plugins, package caches, or unrelated projects and were not selected.

No MORT worktree, submodule, nested authoritative repository, usable reflog,
or source archive containing `.git` metadata was found.

## Safety controls

- No reset, clean, checkout, rebase, force push, or history rewrite was used.
- The remote was fetched without altering the working tree.
- Existing source, local evidence, generated artifacts, and backups were not
  deleted.
- `backups/`, generated builds, environment files, archives, signing files,
  and package caches are excluded from commits.
- Root Expo native generation folders remain ignored, while
  `flutter_mort/android` and `flutter_mort/ios` are eligible for source control.
- Staged filenames and content must pass secret and artifact checks before any
  baseline commit is created.

## History attachment method

The verified current source will be recorded as a recovery baseline whose
parent is the existing `origin/main` tip. This preserves the public repository
history and adds the authoritative current tree as a forward commit. The
0.9.4 work then continues on `mort-0.9.4-completion-security`.

This was completed locally. Commit `33013561adf3f163616dcd9ab73d86509df3edcf`
has parent `7bcfca79a5a41708d3ccc7d0342f1dc9ade56008`. The baseline used the explicit
local identity `MORT Local Recovery <local-recovery@invalid>` because the
machine-wide identity was `Your Name <your_email@example.com>`. The commit
contains no forbidden artifact paths and does not track `.env.local`.

The baseline has 142 inherited whitespace findings reported by
`git diff --cached --check`. They are primarily Markdown hard breaks, blank
lines at end of file, and pre-existing generated documentation/script text.
They were preserved to avoid an unrelated mass rewrite during history recovery.

## Push status

Push is blocked at recovery time. GitHub CLI is not authenticated, repository
ownership has not been verified in this environment, and the configured Git
author identity is a placeholder. No push will be attempted until credentials,
ownership, destination, and author identity are verified by the repository
owner. Local commits do not prove that remote publication occurred.

## Recovery limitations

Source archives in the workspace do not include Git metadata and cannot prove
the lineage of the disconnected changes. Connecting the current tree as a
forward baseline preserves both states, but review of the resulting large
source delta is still required before a remote merge.
