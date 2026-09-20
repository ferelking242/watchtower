---
name: GitHub push authentication
description: Authentication behavior for GitHub API calls versus Git smart HTTP pushes in this workspace.
---

GitHub API requests may work with a Bearer PAT, while Git smart HTTP pushes require Basic authentication using the PAT as the password with the `x-access-token` username.

**Why:** The same configured PAT successfully authenticated the GitHub API but the Bearer extra header was rejected by `git push`.

**How to apply:** For a push, use a one-shot Basic `Authorization` extra header and never persist or print the credential.