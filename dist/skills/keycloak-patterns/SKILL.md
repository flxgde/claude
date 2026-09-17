---
name: keycloak-patterns
description: Keycloak and Spring Security OAuth2/OIDC integration patterns — realm/client setup, resource server configuration, role/scope mapping, token validation, and Angular-side auth integration. Use when configuring Keycloak, Spring Security OAuth2 resource servers, or wiring frontend authentication against Keycloak.
---

# Keycloak Patterns

Reference: https://www.keycloak.org/docs/latest/server_admin/

## Realm and client setup

- One realm per application/tenant boundary, not per environment — use separate Keycloak
  *instances* (or at minimum separate client configs pointing at the same realm) for
  dev/staging/prod, so realm-level settings don't need to be kept in lockstep across environments
  by hand.
- Two client types per app, matching two different trust levels:
  - **Confidential client** (backend, has a client secret) — for the Spring Boot resource server's
    own service-to-service calls, if any.
  - **Public client, PKCE-enabled** (Angular SPA) — never put a client secret in frontend code; a
    public client with Authorization Code + PKCE is the correct flow for a browser app, not the
    (deprecated) Implicit flow.

## Spring Boot as an OAuth2 resource server

```java
// application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://keycloak.example.com/realms/myapp
```

```java
@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health/**").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

- Let Spring Security validate the JWT against Keycloak's issuer (`issuer-uri` triggers automatic
  discovery of the JWK set) — never hand-roll token signature verification.
- Map Keycloak's `realm_access.roles`/`resource_access.<client>.roles` claims to Spring Security
  authorities with a custom `JwtAuthenticationConverter` — the default converter only reads the
  standard `scope` claim, not Keycloak's nested role structure.
- Use `@PreAuthorize("hasRole('...')")` at the method level (with `@EnableMethodSecurity`) for
  fine-grained checks, not just a broad `authorizeHttpRequests` path match.

## Token validation gotchas

- Validate the **issuer** matches exactly (including trailing slash) — a mismatch here is a common
  "works locally, 401s in another environment" bug when the issuer URL differs by a trailing `/`
  between environments.
- Don't disable audience/issuer validation "to make it work" — that's a real security hole, not a
  workaround; fix the actual config mismatch instead.
- Token clock skew: Keycloak and the resource server's clocks need to agree closely enough for
  `exp`/`iat` checks — in containerized/VM environments, confirm NTP is actually working rather than
  assuming it.

## Angular-side integration

- Use `keycloak-angular`/`keycloak-js`'s silent SSO check (`onLoad: 'check-sso'`) rather than
  forcing a login redirect on every app load — it lets an already-authenticated user land on the
  page without a visible redirect flicker.
- Store the access token in memory (the library's own state), not `localStorage` — reduces XSS
  token-theft blast radius. Let the library handle silent token refresh via the hidden iframe/
  refresh token flow rather than a hand-rolled `setInterval` refresh.
- Attach the token via an `HttpInterceptor`, applied only to requests targeting your own API's
  origin — never forward the access token to a third-party request by accident.

## Local development

Run Keycloak via Docker Compose (see `docker-patterns`) with a pre-provisioned realm export
(`--import-realm` + a checked-in `realm-export.json`) so a fresh clone gets a working realm/client/
test-user setup without manual admin-console clicking.
