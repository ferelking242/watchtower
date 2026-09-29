---
name: GitHub Actions availability
description: Validation behavior when this repository's GitHub Actions are disabled.
---

GitHub Actions may be present in `.github/workflows` but disabled at the repository level, preventing both push-triggered runs and `workflow_dispatch`.

**Why:** The repository accepted a code push, but its Flutter analysis workflow returned GitHub API 422 when manually dispatched because the workflow was disabled.

**How to apply:** Treat local checks and the pushed commit as the available validation unless the repository owner enables Actions; never claim CI passed when no run exists.