---
name: testing-patterns
description: Language-agnostic testing best practices — test structure (Arrange-Act-Assert), naming, what to mock vs. what not to, test doubles, coverage priorities, and flaky-test causes. Use when writing new tests, reviewing test quality, or deciding what a change actually needs test coverage for.
---

# Testing Best Practices

These are structural/process rules that apply regardless of language or framework. For
language-specific test syntax and tooling, see `kotlin-patterns`/`java-patterns` (Spring Boot
backend) or `angular-patterns` (Angular frontend).

## Structure: Arrange-Act-Assert

Every test has three parts, visually separated (blank line or comment) even when short:

```
// Arrange
val user = User(id = 1, name = "Alice")
whenever(repository.findById(1)).thenReturn(user)

// Act
val result = service.getById(1)

// Assert
assertThat(result.name).isEqualTo("Alice")
```

A test that mixes setup, action, and assertion inline is harder to scan and harder to tell what
actually broke when it fails.

## Naming describes behavior, not implementation

A test name should read as a sentence describing the expected behavior — `returns 404 when user
not found`, not `testGetUser2` or `getUserThrowsException`. If the test fails, the name alone
should tell you what broke without opening the file.

## What to mock

- Mock **external boundaries**: databases, HTTP clients, message queues, the clock, randomness.
- Don't mock **the thing you're testing** or its plain internal collaborators (a value object, a
  pure mapping function) — mocking too deep makes the test assert against its own mocks instead of
  real behavior, and breaks on refactors that don't change behavior.
- Prefer a real in-memory/test-container instance over a mock when the boundary is cheap to spin up
  and the interaction (a query, a serialization round-trip) is exactly what you need confidence in.

## Coverage priorities

In order, when time is limited:
1. The happy path for the change being made.
2. The error/edge cases the change introduces or touches (validation failures, not-found, boundary
   values).
3. A regression test for any bug being fixed — written to fail against the old code first.

Don't chase 100% line coverage on generated code, trivial getters, or framework glue — coverage
that doesn't correspond to a decision point is noise.

## Common causes of flaky tests

- Real wall-clock time (`Instant.now()`, `Date()`) instead of an injected/fakeable clock.
- Shared mutable state between tests (a static field, a shared test-container not reset between
  runs).
- Relying on collection/map iteration order that isn't actually guaranteed.
- Sleep-based waiting for async work instead of an explicit await/poll on the actual condition.

## One assertion concept per test

A test can have multiple `assert` statements, but they should all verify one behavior. If a test
needs an unrelated second assertion to pass, that's usually a sign it should be two tests — a
failure should point at one thing, not require reading the whole test to figure out which
assertion actually failed.
