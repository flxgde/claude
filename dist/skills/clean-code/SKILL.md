---
name: clean-code
description: Language-agnostic clean code principles — naming, functions, comments, source structure, objects/data structures, tests, and common code smells, condensed from Robert C. Martin's "Clean Code". Use when writing new code, reviewing for readability/maintainability, or when asked to clean up or refactor something that's gotten messy.
---

# Clean Code

Code is clean if it can be understood easily by everyone on the team — not just its original
author. With understandability comes readability, changeability, extensibility, and
maintainability. These rules apply regardless of language; full source list in
`reference/clean-code-cheatsheet.md`.

## General

- Follow the existing codebase's conventions before your own preferences.
- Keep it simple — reduce complexity as much as possible, don't build for hypothetical futures.
- Boy Scout Rule: leave the code cleaner than you found it, even in an unrelated change.
- Fix the root cause, not the symptom.

## Naming

- Choose descriptive, unambiguous, pronounceable, searchable names.
- Replace magic numbers/strings with named constants:
  ```
  // ❌
  if (status == 3) { ... }
  // ✅
  if (status == OrderStatus.SHIPPED) { ... }
  ```
- Don't encode type information into the name (no `strName`, no Hungarian notation) — let the
  type system carry that.
- Make meaningful distinctions — `userData` vs `userInfo` vs `userDetails` side by side is a sign
  none of them are named for what they actually hold.

## Functions

- Small, and do one thing.
- Prefer fewer arguments — three or more is usually a sign the function is doing too much or
  wants a parameter object.
- No side effects a caller wouldn't expect from the name.
- Avoid flag/boolean arguments — split into two functions instead:
  ```
  // ❌
  render(withHeader: true)
  // ✅
  renderWithHeader()
  renderWithoutHeader()
  ```

## Comments

- Prefer making the code self-explanatory over commenting what it does.
- A comment justified only when it captures the *why* — intent, a non-obvious constraint, a
  warning of consequences — not a restatement of the code.
- Delete commented-out code; version control already remembers it.
- No closing-brace comments (`} // end if`) — if a block is long enough to need one, it's a sign
  the block itself should be extracted into a named function instead.

## Source structure

- Declare variables close to where they're used.
- Keep related code vertically dense; keep weakly-related code visually separated.
- Order top-down: a function should be followed by the functions it calls, not the reverse.
- Keep lines short; don't hand-align columns of code — it rots the first time someone edits one
  line and not the others.

## Objects & data structures

- Hide internal structure — expose behavior, not fields.
- Avoid hybrids that are half object (behavior) and half data (public fields) — pick one.
- Keep classes small, with a small number of instance variables, doing one thing.
- Avoid negative conditionals — `if (!isNotValid())` reads worse than `if (isValid())`.
- Encapsulate boundary conditions (off-by-one edges, empty/null cases) in one place instead of
  repeating the check everywhere the value is used.

## Design

- Prefer polymorphism to a long `if`/`else` or `switch` chain over a type.
- Keep configurable data at high levels (constructor/config), not buried in low-level logic.
- Use dependency injection instead of a class constructing its own collaborators.
- Law of Demeter: a class should only talk to its direct dependencies, not reach through one
  object to get to another (`a.getB().getC().doSomething()` is a smell).

## Tests

- One assertion (or one logical assertion) per test — a failure should point at exactly one thing.
- Fast, independent, and repeatable — a test that depends on another test's side effects or on
  execution order will eventually lie to someone.

## Code smells to watch for

- **Rigidity** — a small change cascades into changes elsewhere.
- **Fragility** — one change breaks unrelated things.
- **Immobility** — code can't be reused elsewhere because it's too entangled to extract safely.
- **Needless complexity / needless repetition** — solving a simple problem in a complicated way,
  or solving the same problem more than once.
- **Opacity** — a reader can't tell what the code does without running it.
