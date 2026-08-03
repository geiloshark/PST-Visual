---
name: GitHub push pattern for PST-Visual
description: How to push files to origin/main (PST-Visual) without wiping Replit artifacts
---

# GitHub push pattern for PST-Visual

## The problem
The Replit workspace (`main` branch) and `origin/main` (PST-Visual on GitHub) have **divergent histories**. When you `git checkout` a branch based on `origin/main`, the `.replit-artifact/` directories disappear from the working tree, causing Replit to immediately deregister all artifacts and kill all workflows.

**Why:** PST-Visual `main` only contains `README.md` and `pstom/`. The Replit project code lives in `artifacts/`, `lib/`, etc. — none of which exist on origin/main. Checking out origin/main removes those directories from disk.

## The correct pattern

Never check out a branch based on `origin/main` in this workspace. Instead:

1. Make commits on local `main` as normal.
2. To push a specific commit to `origin/main`, use `git worktree` OR cherry-pick onto a throwaway branch **without switching the main worktree**:

```bash
# Fetch remote
git fetch origin main

# Create throwaway branch without checking it out
git branch --no-track push-tmp origin/main
git cherry-pick <commit-sha> --onto push-tmp  # doesn't work directly

# Better: use git format-patch + git am
git format-patch -1 HEAD -o /tmp/patches/
git checkout -b push-tmp origin/main  # UNAVOIDABLE checkout — see below
git am /tmp/patches/*.patch
```

The checkout step is unavoidable with current tooling. When it happens:

3. Immediately push (gitPush callback), then `git checkout main`, then call `verifyAndReplaceArtifactToml` for all three artifacts to restore them.

## Restore sequence (run after every forced checkout)

```bash
cp artifacts/pstom-ui/.replit-artifact/artifact.toml /tmp/pstom-ui.edit.toml
cp artifacts/api-server/.replit-artifact/artifact.toml /tmp/api-server.edit.toml
cp artifacts/mockup-sandbox/.replit-artifact/artifact.toml /tmp/mockup-sandbox.edit.toml
# then verifyAndReplaceArtifactToml x3 in parallel
```

## How to apply
Any time a task involves pushing a file change to `origin/main` (PST-Visual):
- Plan for the artifact restore step
- Do the push *before* switching back to local main
- Have the three `verifyAndReplaceArtifactToml` calls ready to fire immediately after checkout
