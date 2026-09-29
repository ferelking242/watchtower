---
name: Browse source boundary
description: Architecture rule separating installed-source browsing from repository/network refreshes
---

Browse must display the installed sources already persisted in Isar and must not fetch every configured extension repository during app startup or repository-setting changes. Network refreshes belong to explicit user actions such as Marketplace installation, manual refresh, or repository management.

**Why:** Implicit startup fetches left Browse tabs in loading states, caused unnecessary network traffic, and could trigger malformed remote-index failures before the user opened Marketplace.

**How to apply:** When changing Browse initialization, source repositories, or extension installation, preserve the Isar-only read path and require an active persisted source before reporting an installation success.