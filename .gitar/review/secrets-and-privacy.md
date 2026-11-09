# Secrets and privacy

- No API key, token, password or private key in code, docs, tests, fixtures or logs. `.env.example` has variable names only.
- Real-looking tokens in examples must be obviously fake (`auth_REDACTED`).
- Session data is fictional. No real names, emails, phone numbers, locations or photos with metadata.
- Kubernetes manifests read secrets from a Kubernetes Secret, never from a ConfigMap or an image layer.
