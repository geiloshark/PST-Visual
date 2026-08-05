---
name: GitHub push pattern for PST-Visual
description: How to push files to origin/main (PST-Visual) without wiping Replit artifacts
---

# GitHub push pattern for PST-Visual

## Current state (as of 2026-08-05)

Local `main` and `origin/main` are now **in sync** (same linear history) after a force-push resolved the divergence. Future pushes can use `gitPush` directly from local main — no throwaway branch needed.

```javascript
// Simple push — works when histories are in sync
const result = await gitPush({ branch: "main" });
```

Do NOT use `git push origin main` directly in the shell — authentication via HTTPS tokens expires; always go through the `gitPush` callback.

---

## Historical context (kept for reference)

The Replit workspace (`main` branch) and `origin/main` previously had **divergent histories**. Checking out a branch based on `origin/main` caused Replit to deregister all artifacts and kill all workflows, because `pstom/`, `artifacts/`, etc. weren't all present on the same branch.

The workaround was:
1. `git checkout -b push-tmp origin/main`
2. `git checkout main -- .` (brings all local files without touching files already in push-tmp)
3. `git add -A && git commit`
4. `gitPush({ branch: "main" })`
5. `git checkout main && git branch -D push-tmp`
6. Restore all three artifact tomls via `verifyAndReplaceArtifactToml`

**That workaround is no longer needed** as long as histories stay in sync.

---

## If histories diverge again

If a git operation causes divergence (you'll see "Your branch and 'origin/main' have diverged"), the safest recovery is:

```bash
git push origin main --force
```

Run this in the Replit Shell tab. This re-syncs GitHub to local main. Then check that `pstom/` is still present on GitHub — if force-push wiped it (because local main didn't have it), recover it with:

```bash
git checkout <old-commit-sha> -- pstom/
git add pstom/ && git commit -m "Restore pstom R package source"
# then gitPush callback
```

## Artifact restore sequence (only needed if checkout wipes artifacts)

```javascript
const root = "/home/runner/workspace";
const [a, b, c] = await Promise.all([
  verifyAndReplaceArtifactToml({ tempFilePath: "/tmp/pstom-ui.toml",      artifactTomlPath: `${root}/artifacts/pstom-ui/.replit-artifact/artifact.toml` }),
  verifyAndReplaceArtifactToml({ tempFilePath: "/tmp/api-server.toml",    artifactTomlPath: `${root}/artifacts/api-server/.replit-artifact/artifact.toml` }),
  verifyAndReplaceArtifactToml({ tempFilePath: "/tmp/mockup-sandbox.toml",artifactTomlPath: `${root}/artifacts/mockup-sandbox/.replit-artifact/artifact.toml` }),
]);
```

Save the tomls before any checkout:
```bash
cp artifacts/pstom-ui/.replit-artifact/artifact.toml /tmp/pstom-ui.toml
cp artifacts/api-server/.replit-artifact/artifact.toml /tmp/api-server.toml
cp artifacts/mockup-sandbox/.replit-artifact/artifact.toml /tmp/mockup-sandbox.toml
```
