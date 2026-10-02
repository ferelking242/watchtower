---
name: GitHub push authentication
description: Authentication behavior for GitHub API calls versus Git smart HTTP pushes in this workspace.
---

GitHub API requests and Git smart HTTP pushes can use different authentication paths. Prefer the GitHub CLI credential helper with `GH_TOKEN` supplied through the workspace secret. If `gh auth status` succeeds but a push fails, reset helpers for that command and explicitly select `gh auth git-credential`; do not put the token in a remote URL or output.

**Why:** GitHub CLI API authentication succeeded while Git initially used another configured credential helper and rejected the push.

**How to apply:** Use `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push ...` with `GH_TOKEN` set in the command environment.