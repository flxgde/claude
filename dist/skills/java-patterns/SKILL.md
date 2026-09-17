---
name: java-patterns
description: Java idioms for Spring Boot development — records, sealed interfaces, pattern matching, Optional, naming conventions, Jackson serialization, and Java-idiomatic Spring patterns. Aligned with Oracle's Java code conventions. Use when writing or reviewing Java backend code.
---

# Java Patterns for Spring Boot

Reference: https://www.oracle.com/java/technologies/javase/codeconventions-namingconventions.html

## Naming Conventions

```java
// Packages — lowercase, no underscores
package de.flxg.order.service;

// Classes / interfaces — UpperCamelCase
class OrderService { }
interface PaymentGateway { }

// Methods / fields / local variables — lowerCamelCase
void processOrder() { }
int declarationCount = 1;

// Constants (static final) — SCREAMING_SNAKE_CASE
static final int MAX_RETRY_COUNT = 3;

// Type parameters — single uppercase letter (T, E, K, V, R, ...)
class Repository<T, ID> { }
```

### Test method names

Prefer `@DisplayName` on the method (Java has no backtick method names): a plain camelCase method
name plus a readable `@DisplayName`, not a long `should_do_x_when_y` method name.

```java
@Test
@DisplayName("returns 404 when user not found")
void getById_notFound() { }
```

## Records for DTOs and value objects

Use `record` for immutable data carriers — request/response bodies, value objects — the direct
equivalent of a Kotlin `data class`:

```java
public record UserResponse(Long id, String name, String email) { }

// Compact canonical constructor for validation
public record CreateUserRequest(String name, String email) {
    public CreateUserRequest {
        Objects.requireNonNull(name, "name must not be null");
    }
}
```

Don't use `record` for JPA entities — entities need mutable fields and identity-based
equals/hashCode, not the value-based semantics records generate. Use a plain class there (see
Entity definition below).

## `Optional` for nullable single results

```java
Optional<User> findByEmail(String email);

User user = userRepository.findByEmail(email)
    .orElseThrow(() -> new EntityNotFoundException("User not found: " + email));
```

- Use `Optional<T>` for method return types where "absent" is a valid outcome — never as a field
  type or method parameter type.
- Prefer `.map()`/`.orElseThrow()`/`.orElseGet()` chains over `.isPresent()` + `.get()`.

## Pattern matching & sealed types

```java
sealed interface PaymentResult permits Success, Failure { }
record Success(String transactionId) implements PaymentResult { }
record Failure(String reason) implements PaymentResult { }

String describe(PaymentResult result) {
    return switch (result) {
        case Success s -> "Paid: " + s.transactionId();
        case Failure f -> "Failed: " + f.reason();
    };
}
```

Use a `sealed interface` + `record` implementations instead of a wide `enum` or a boolean flag when
a value can be one of several distinct shapes — the compiler enforces the `switch` stays exhaustive
when a new case is added.

## `var` for local type inference

Use `var` when the right-hand side already makes the type obvious (`var users = new ArrayList<User>()`);
skip it when it would obscure the type (`var result = service.process(input)` — spell out the type
instead if `process`'s return type isn't clear from the call site).

## Streams

```java
List<UserResponse> responses = users.stream()
    .map(User::toResponse)
    .toList();
```

- Prefer a stream pipeline over an explicit loop when it's a straight transform/filter/collect —
  fall back to a plain `for` loop once the pipeline needs multiple exit points or side effects.
- `.toList()` (Java 16+) over `.collect(Collectors.toList())` for a plain immutable list result.

## No Lombok

Prefer plain Java (constructors, `record`, builder methods written by hand) over Lombok
annotations (`@Data`, `@Builder`, `@Getter`/`@Setter`). Records already remove most of the
boilerplate Lombok exists to hide, and hand-written code doesn't depend on annotation processing.
If a project already has Lombok in place, follow its existing convention rather than migrating away
mid-task.

---

## Jackson serialization

```java
// build.gradle.kts — Jackson comes bundled with spring-boot-starter-web, no extra dependency needed

public record UserResponse(
    Long id,
    String name,
    @JsonProperty("email_address") String email,
    @JsonIgnore String internalField
) { }
```

Jackson is the default serializer for a Spring Boot Java project — unlike the Kotlin side (which
prefers kotlinx.serialization), there's no reason to avoid it here.

---

## Spring Boot integration

For framework-level Spring Boot conventions (dependency injection, transaction boundaries,
layering, profiles, Boot 4 migration pitfalls), see `spring-boot-patterns` — those apply
identically regardless of language. The only Java-specific note: use `record` for
`@ConfigurationProperties` classes (see the Records section above) and Mockito (not
Mockito-Kotlin) in tests.
