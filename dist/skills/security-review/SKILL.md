---
name: security-review
description: OWASP-aligned security review checklist — injection, broken auth, XSS, access control, sensitive data exposure, security misconfiguration, dependency vulnerabilities, SSRF, and logging/monitoring gaps. Use when writing or reviewing code that handles user input, authentication, authorization, or external requests, on either the frontend or backend. For Keycloak/OAuth2-specific configuration, see keycloak-patterns.
---

# Security Review (OWASP)

Reference: https://owasp.org/www-project-top-ten/

Cross-cutting checklist, applicable to both the Angular frontend and the Spring Boot backend.
For Keycloak/Spring Security OAuth2 configuration specifics, see `keycloak-patterns` — this skill
covers what to check regardless of which auth provider is in use.

## Injection

- **Backend**: no SQL/JPQL built by string concatenation — parameterized queries / `@Query` with
  named parameters only (see `jpa-patterns`/`mongodb-patterns`).
- **Backend**: no OS command built from unsanitized input passed to `ProcessBuilder`/`Runtime.exec`.
- **Frontend**: never bind unsanitized user/API content via `[innerHTML]` or
  `bypassSecurityTrustHtml` — Angular's default template binding already escapes; a bypass call is
  the thing to scrutinize, not the default path.

## Broken authentication & session management

- Tokens/session identifiers are never logged, and never appear in URLs (query params end up in
  server logs, browser history, and `Referer` headers).
- Password/credential fields use a proper hashing algorithm (bcrypt/Argon2 via Spring Security) —
  never a fast general-purpose hash (MD5/SHA-256 alone) for password storage.
- Session/token expiry is enforced server-side — a frontend-only "logged out" state is not a
  security control.

## Broken access control

- Every endpoint that requires authentication/authorization is actually covered by a security rule
  (`@PreAuthorize`, `authorizeHttpRequests`) — not "covered by being behind the same base path as
  one that is."
- Authorization checks happen server-side; a hidden frontend button/route is not a security
  boundary — the backend must independently reject the same action.
- Object-level checks: an endpoint taking an ID (`/orders/{id}`) verifies the *authenticated user*
  is allowed to access *that specific* resource, not just that they're authenticated at all
  (insecure direct object reference).

## Sensitive data exposure

- No secrets (API keys, DB credentials, signing keys) in source control, `application.yml`, or a
  frontend bundle — use environment variables / a secrets manager, referenced, not inlined.
- PII/credentials/tokens never appear in log statements (see `logging-patterns`) or error messages
  returned to the client — a stack trace or verbose error in a production response is an
  information-disclosure bug, not just a UX issue.
- TLS everywhere in production — no plaintext HTTP between services that carry sensitive data, even
  internally, unless the network boundary is explicitly trusted and documented as such.

## Security misconfiguration

- No default credentials left active (a seeded admin user, a database's default password) past
  local development.
- Framework security defaults left in place unless there's a specific, documented reason to
  loosen them (CORS wide open, CSRF disabled, actuator endpoints exposed) — a loosened default
  needs a comment explaining why, not silence.
- Dependency versions kept current — an outdated framework/library version is itself a
  misconfiguration once a CVE exists for it.

## Vulnerable dependencies

- Run a dependency scanner (`./gradlew dependencyCheckAnalyze`, `npm audit`, `trivy` on the built
  image — see `docker-patterns`) before considering a release done, not just on ad-hoc request.
- A flagged CVE in a transitive dependency still needs a decision (upgrade, pin an override, or a
  documented risk acceptance) — "it's transitive" is not a reason to ignore it.

## SSRF

Any code path that takes a URL/host from user input and makes a server-side request to it
(webhook registration, "fetch this image", callback URLs) needs an allowlist or at minimum a check
against internal/private IP ranges — otherwise a user can make the server issue requests to
internal-only services on your behalf.

## Logging & monitoring

- Security-relevant events (failed logins, authorization denials, password changes) are logged with
  enough context to investigate an incident, but without the sensitive data itself (see above).
- A spike in 401/403 responses or failed-auth attempts should be something the team can actually
  notice — via existing logging/alerting, not something only discoverable after the fact via
  manual log archaeology.

## Frontend-specific

- Dependencies audited the same as the backend (`npm audit`) — a frontend bundle ships every
  transitive dependency's code to the browser, including its vulnerabilities.
- No secrets/API keys embedded in frontend bundles — anything shipped to the browser is public,
  regardless of build-time "environment variable" naming.
- `HttpInterceptor`s that attach auth tokens only target the application's own API origin — never
  forward credentials to a third-party request by accident (see `keycloak-patterns`).
