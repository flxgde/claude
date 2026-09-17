---
name: spring-boot-patterns
description: Framework-level Spring Boot best practices, independent of Kotlin vs. Java — dependency injection, configuration binding, transaction boundaries, layering, profiles, testing strategy, actuator/health probes, bean-lifecycle gotchas, and Spring Boot 4 migration pitfalls. Use when writing or reviewing Spring Boot application code or configuration. For language idioms, see kotlin-patterns/java-patterns.
---

# Spring Boot Patterns

Reference: https://docs.spring.io/spring-boot/reference/

This skill covers the framework itself — everything here applies whether the project is Kotlin or
Java. For language idioms and code style, see `kotlin-patterns`/`java-patterns`; for API-contract
generation specifics, see `openapi-generator-patterns`.

## Dependency injection

Constructor injection only, always — never `@Autowired` on a field or setter. A class that can't be
constructed without Spring (because its dependencies are silently field-injected) can't be
unit-tested without Spring either, and a class with too many constructor parameters becomes an
obvious, visible signal that it's doing too much — a benefit field injection quietly hides.

```java
@Service
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;

    public UserService(UserRepository userRepository, EmailService emailService) {
        this.userRepository = userRepository;
        this.emailService = emailService;
    }
}
```

A single-constructor class needs no `@Autowired` annotation at all — Spring uses it implicitly.

## Configuration binding

Prefer `@ConfigurationProperties` over scattered `@Value("${...}")` injections once a component has
more than one or two related settings — it's type-checked at startup (with `@ConstructorBinding`/
a records or data class constructor), documented in one place, and testable without a full context.

```java
@ConfigurationProperties(prefix = "app.mail")
public record MailProperties(String host, int port, String from) { }
```

Enable validation (`@Validated` + Bean Validation annotations on the properties type) for anything
where a misconfigured value should fail fast at startup rather than at first use.

## Transaction boundaries

- `@Transactional(readOnly = true)` at the service class level; override with a plain
  `@Transactional` on write methods. This documents intent and lets the persistence layer apply
  read-only optimizations by default.
- Controllers are never `@Transactional` — a transaction should not span the HTTP request lifecycle
  or wait on client behavior.
- A transaction should never span an external call (another service's HTTP API, a message broker
  publish) — holding a DB transaction open across a network call to another system risks long lock
  hold times and makes failure semantics (partial commit vs. rollback) far harder to reason about.
  Do the external call before or after the transactional unit of work, not inside it.

## Layering

- **Controller**: implement the generated API interface (see `openapi-generator-patterns`) —
  never a hand-written `@RequestMapping` that bypasses the contract. Thin: parse/delegate only, no
  business logic.
- **Service**: owns transaction boundaries and business logic; throws typed domain exceptions;
  never returns/accepts HTTP types (`ResponseEntity`, `HttpStatus`) — that couples business logic
  to the web layer for no benefit.
- **Repository**: thin data-access interface; `@Query` with named parameters, never string
  concatenation.
- **`@ControllerAdvice`**: the one place HTTP-mapping of domain exceptions happens
  (`EntityNotFoundException` → 404, bean-validation failures → 400 with field-level messages,
  etc.) — keeps that mapping out of every controller.

## Profiles

- `application.yml` for shared defaults; `application-<profile>.yml` for what actually differs per
  environment (dev/test/prod) — activate via `spring.profiles.active`, not an environment-variable
  `if`/`switch` sprinkled through application code.
- Prefer expressing environment differences as configuration (a different property value) over
  `@Profile`-gated bean definitions where possible — a config value is easier to audit across
  environments than a set of conditionally-registered beans.

## Testing strategy

- Unit tests for the service layer, mocking the repository/collaborators — no Spring context
  needed, so these should be fast and make up the bulk of the suite.
- `@WebMvcTest` slice tests for the controller layer — loads only the web layer, not the whole
  application context.
- Integration tests via `@SpringBootTest` + Testcontainers for anything that needs to verify real
  persistence/query behavior — see the Boot 4 note below for what replaced the old
  `@DataJpaTest`/`@DataMongoTest` slices.

## Actuator & health

Enable `management.endpoint.health.probes.enabled=true` and expose
`/actuator/health/liveness`/`/actuator/health/readiness` rather than hand-rolling a health endpoint
— this is also what a Kubernetes deployment's liveness/readiness probes should point at directly
(see `kubernetes-patterns`). Add a custom `HealthIndicator` for any critical external dependency
(a downstream service, a non-Spring-Data datastore) that isn't already covered by an
auto-configured indicator.

## Bean lifecycle gotcha: `@ConditionalOnBean` on auto-config classes

`@ConditionalOnBean(SomeBean.class)` at the `@Configuration` *class* level is evaluated during the
auto-configuration phase, before all beans necessarily exist — it will skip your configuration if
the dependency comes from another auto-configuration that hasn't run yet. Two fixes, use both
together when wiring on top of another auto-configuration:

1. Move `@ConditionalOnBean` to the `@Bean` *method* instead — Spring evaluates it lazily during
   bean creation.
2. Add `@AutoConfigureAfter(TheirAutoConfig.class)` at the class level so your configuration is
   guaranteed to see their beans.

```java
@Configuration(proxyBeanMethods = false)
@ConditionalOnClass(ReactiveMongoTemplate.class)
@AutoConfigureAfter(DataMongoReactiveAutoConfiguration.class)
public class MyAutoConfiguration {
    @Bean
    @ConditionalOnBean(ReactiveMongoTemplate.class)   // method level, not class level
    MyBean myBean(ReactiveMongoTemplate mongo) {
        return new MyBean(mongo);
    }
}
```

## Spring Boot 4 migration pitfalls

Boot 4 reorganized several packages and properties. These keep biting regardless of language:

### MongoDB properties moved namespace

Connection-level properties moved from `spring.data.mongodb.*` to `spring.mongodb.*`. Boot
**silently ignores** the old names — the client falls back to defaults (`localhost:27017`, no DB
selected) and this only surfaces at first read/write, not at startup.

```properties
# Boot 3 (WRONG in Boot 4 — silently ignored):
spring.data.mongodb.uri=mongodb://localhost:27017/mydb

# Boot 4:
spring.mongodb.uri=mongodb://localhost:27017/mydb
spring.mongodb.representation.uuid=STANDARD   # required if any @Document has UUID fields

# Still under spring.data.mongodb (Spring Data layer, not the driver):
spring.data.mongodb.auto-index-creation=true
```

The Mongo auto-configuration also moved out of `spring-boot-autoconfigure` into the dedicated
`spring-boot-data-mongodb` module. The reactive auto-config class is
`org.springframework.boot.data.mongodb.autoconfigure.DataMongoReactiveAutoConfiguration` — needed
when wiring `@AutoConfigureAfter(...)` (see above).

### Test slice annotations removed

`@DataMongoTest`, `@DataR2dbcTest`, `@WebMvcTest` (for WebFlux projects) and several other slice
annotations are **removed** in Boot 4. Use `@SpringBootTest` + `@ServiceConnection` + Testcontainers
instead:

```java
@SpringBootTest
@Testcontainers
class FooRepositoryTest {
    @Container @ServiceConnection
    static MongoDBContainer mongo = new MongoDBContainer("mongo:8");
}
```

### Spring Cloud Gateway artifact renamed

For Spring Boot 4 + Spring Cloud 2025.1.x, the gateway artifact is
`spring-cloud-starter-gateway-server-webflux` (not `spring-cloud-starter-gateway`). Routes config
moved under `spring.cloud.gateway.server.webflux.routes[*]`.

### `spring-boot-devtools` + Spring Cloud Gateway collide

Devtools' restart classloader clashes with Gateway's filter chain. Remove devtools from the gateway
module specifically.
