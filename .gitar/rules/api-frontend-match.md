---
title: "API and front end stay in sync"
description: "Server routes and HTMX templates must agree"
type: check
when: "PRs that change server routes, response shapes, query parameters or HTMX fragment templates"
actions: "Comment listing any front-end file or copy that no longer matches and add the needs-frontend-update label"
---
# API and front end stay in sync
When a route, parameter or fragment changes:
- Check `swift-server/Public/` and the view templates still use the same names and parameters.
- Check `docs/design/COPY.md` still matches any text that changed.
- If something no longer matches, add the `needs-frontend-update` label and comment with the exact mismatch.
