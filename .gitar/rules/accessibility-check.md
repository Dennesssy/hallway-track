---
title: "Accessibility must not regress"
description: "Keep the UI keyboard, screen-reader and JS-off friendly"
type: check
when: "PRs that modify files under swift-server/Public or HTML view templates"
actions: "Comment on accessibility problems found and suggest code changes"
---
# Accessibility must not regress
Check each changed control and page for:
- a real button, link or form control with an accessible name
- a visible focus style
- state shown by more than colour
- results announced in an aria-live region
- search and filters still working with JavaScript off
- no inline script, onclick or inline style
Suggest a code change for each problem.
