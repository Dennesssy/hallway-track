---
title: "No secrets in the repository"
description: "Block keys, tokens and private data"
type: check
when: "Any PR"
actions: "Comment and request removal of anything that looks like a secret"
---
# No secrets in the repository
Scan the diff for API keys, bearer tokens (`auth_...`), Elasticsearch `ApiKey` values, private keys, `.env` contents and personal data.
If found, comment with the file and line, never repeating the value, and ask for removal and rotation.
