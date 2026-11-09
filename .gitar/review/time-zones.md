# Time zones

- Every session time is stored and passed around with a time zone or UTC offset (ISO-8601). A bare "10:30" or a date without a zone is a bug.
- The venue zone is `America/Denver`. Display defaults to the venue zone and offers the viewer's zone.
- Never derive a zone from the server's or the browser's locale without saying so in the code.
- Clash detection and "walking gap" maths compare instants, not strings.
- Tests cover at least: a session spanning midnight in another zone, and a day on a daylight-saving boundary.
