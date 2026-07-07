# Security and Trust

## Implemented controls

- Production requests require HTTPS using the trusted proxy protocol and HSTS/security headers.
- Redis-backed limits are stricter for login, registration, OTP, uploads, search, and writes.
- Platform-admin and moderator roles protect report review; platform admins can read audit logs.
- Mutation audit events record actor, request ID, IP, user agent, HTTP result, and metadata.
- Passwords use per-user random salts and versioned scrypt parameters with constant-time checks. Legacy hashes upgrade after successful login.
- Direct uploads enforce an exact MIME/extension allowlist, signed content length, object metadata checks, usage-specific size limits, quarantine, and asynchronous ClamAV scanning.
- Reports are queued for moderation, blocking is persisted, and moderator actions are audited.
- Secrets can come from environment variables, `NAME_FILE`, or `/run/secrets/name`.
- CI runs dependency audit, TypeScript checks, builds, and Trivy filesystem scanning. Dependabot tracks npm and container updates.

## Deployment requirements

Application code cannot provision an edge WAF, certificates, or a managed secrets service. Production must provide these controls:

1. Put Cloudflare WAF, AWS WAF, or an equivalent service before the TLS reverse proxy. Enable managed OWASP rules, bot protection, IP reputation, request-size limits, and country/risk rules based on measured abuse rather than blanket regional blocking.
2. Terminate TLS at the load balancer or the supplied Nginx configuration. Only the load balancer may reach the API service. Set `TRUST_PROXY=true` only when direct API access is blocked.
3. Store the media bucket privately. The scanner promotes clean objects from `quarantine/` to `trusted/` and deletes infected objects; configure the CDN to expose only the `trusted/` prefix.
4. Supply secrets through AWS Secrets Manager, Vault, Doppler, Kubernetes Secrets, or Docker Secrets. Never commit production values.
5. Protect Postgres, Redis, Meilisearch, MinIO/S3, and ClamAV on private networks. Require authentication and encryption in transit.
6. Export audit logs to append-only storage/SIEM and alert on repeated authentication failures, admin changes, malware, and high-priority reports.

The Nginx file in `infra/nginx/security.conf` is defense in depth, not a replacement for a managed WAF.
