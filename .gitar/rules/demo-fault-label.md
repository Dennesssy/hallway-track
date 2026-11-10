---
title: "Label demo faults"
description: "Make injected demo faults easy to spot"
type: automation
when: "PRs that touch the Keynote Rush load generator, the chaos button or fault injection code"
actions: "Add the demo-fault label and comment reminding to update docs/runbooks"
---
# Label demo faults
- Add the `demo-fault` label.
- Comment: this changes demo-only fault code; update the matching runbook in `docs/runbooks/` and make sure the UI and README still label the fault as a demo fault.
