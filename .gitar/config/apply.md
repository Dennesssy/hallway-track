# Auto-apply criteria

Apply a fix automatically only when all of these hold:
- The failure is a build error, a failing test, or a lint/format error, and the analysis confirms this PR caused it.
- The fix is small and local to the files the PR already changes.
- The fix makes the code correct. It must not delete a test, loosen an assertion, skip a test that should run, or lower the relevance baseline in `eval/`.

Never auto-apply a change to:
- `.env`, `.env.example` values, secrets, or `deploy/` manifests
- `eval/` baselines or `data/sessions.json`
- anything under `.gitar/`

When unsure, post the analysis and wait for a person.
