---
name: api-design-review
description: API contract design and review conventions — design-first workflow, single source of truth, source control, structuring large specs, and what "matches the contract" actually means for a generated client/server. Use when designing, splitting, or reviewing an OpenAPI spec, or when reviewing generated-code usage for contract compliance. For openapi-generator configuration/usage itself, see openapi-generator-patterns.
---

# API Design & Review

Reference: [learn.openapis.org/best-practices.html](https://learn.openapis.org/best-practices.html)

## Design-first, not code-first

Write the OpenAPI description before implementing code. Code-first (annotations generated after
the fact) tends to produce descriptions that are unintuitive, incomplete, and hard to maintain as
the API grows — the set of things expressible in code is far larger than what OpenAPI can describe,
so a description bolted on afterward is usually a lossy, awkward fit. Design-first also unlocks
skeleton/client code generation and early tooling support before any implementation exists.

Wire a validation step into CI that checks the implementation still matches the spec, so the spec
can be trusted and updated with confidence rather than drifting silently.

## Single source of truth

Never let two representations of the same API disagree. The common failure mode: an OpenAPI file is
generated from code annotations, and both the annotations and the generated file end up committed —
now nobody knows which one is authoritative when they diverge. Pick one canonical source (ideally the
hand-authored/edited spec itself), or add a CI check that fails when the two drift apart.

## Treat the spec as a first-class source file

- Commit it to version control early, not as an afterthought once the API stabilizes.
- Review changes to it the same way you review code.
- Drive tooling off of it: code generation, contract tests, mock servers, documentation.

## Publish the spec to consumers

Make the raw OpenAPI description available to API consumers, not just rendered documentation. It
lets them generate their own clients, build language bindings, and do runtime discovery — treat this
as a value-add of having a machine-readable contract at all.

## Prefer tooling over hand-writing at scale

Hand-writing a small spec is fine. For anything larger, use an OpenAPI-aware editor, a DSL, or
code annotations to generate the bulk of it, then hand-tune the result — but whatever comes out of
that process becomes the single source of truth (see above), not a second copy alongside the tool's
input.

## Structuring large specs

- **DRY it up**: move repeated schemas/parameters/responses into `components/` and reference them
  with `$ref` instead of duplicating structure across operations.
- **Split by resource** once one file gets unwieldy: let the natural URL hierarchy guide the split
  (e.g. all `/users/**` operations in one file), rather than an arbitrary line-count threshold.
- **Tag every operation** so tooling (and generated client/server code — see the naming conventions
  below) can group and navigate by resource area.

## Reviewing generated-code usage for contract compliance

This is the half of "API design review" that applies on the backend/frontend side, after the spec
already exists — checking that the code built against it hasn't quietly drifted from the contract:

- The controller/service implements the **generated** interface — no hand-written
  `@RequestMapping`/route that bypasses what the spec declares.
- Response types and status codes match what the spec declares — not just "returns something
  plausible."
- The error response body's shape matches the spec's declared error schema, including on paths
  that only fail sometimes (validation errors, 404s) — these are the ones most often only
  hand-tested against the happy path and never checked against the schema.
- A frontend call site's request payload matches the generated request type — a manually
  constructed object literal that happens to satisfy TypeScript's structural typing can still be
  missing a field the backend requires, if a type import ever gets loosened to `any`/`Partial<T>`.

## Applying this alongside REST/schema conventions

This skill covers spec-level process, structure, and generated-code compliance review. For the
concrete conventions this project uses inside a spec — resource naming, required fields per
operation, schema naming, pagination shape, breaking-change rules — see the "Designing new
endpoints" section of the `api-contract-engineer` agent itself; that content is project-specific
and stays in the agent's own instructions rather than duplicated here. For how to actually run and
configure `openapi-generator` (Spring Boot / Angular generator options, generated-code layout,
regeneration workflow), see `openapi-generator-patterns` instead — this skill is about the contract
itself, not the tool that turns it into code.
