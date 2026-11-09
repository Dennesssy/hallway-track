---
title: "Times carry a time zone"
description: "Session times must never be zone-less"
type: check
when: "PRs that add or change code handling session start times, agenda, schedules or clash detection"
actions: "Comment on any time handled without a zone and request a fix"
---
# Times carry a time zone
When schedule or agenda code changes:
- Check that every stored or passed time has a zone or UTC offset.
- Check clash detection compares instants, not strings.
- If a test for a daylight-saving boundary is missing, comment asking for one.
