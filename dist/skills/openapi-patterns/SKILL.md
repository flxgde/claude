---
name: openapi-patterns
description: OpenAPI specification design best practices — design-first workflow, single source of truth, source control, tooling, and structuring large specs. Use when designing, splitting, or reviewing an OpenAPI spec.
---

# OpenAPI Best Practices

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

## Applying this alongside REST/schema conventions

This skill covers spec-level process and structure. For the concrete conventions this project uses
inside a spec — resource naming, required fields per operation, schema naming, pagination shape,
breaking-change rules — see the "Designing new endpoints" section of the `api-designer` agent itself;
that content is project-specific and stays in the agent's own instructions rather than duplicated here.
