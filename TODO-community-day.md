# TODO: gaps vs. Community Day slides (cd-2026-09-18)

Compared `../../Work/OC/cd-2026-09-18/slides/SLIDES.md` (slides 05/06) against what actually
exists in `dist/agents/*.md` and `dist/skills/*/` in this repo. The example project's stack is
Angular 22 / Tailwind 4 / TaigaUI 5 (frontend), Spring Boot 4 / Java 25 (backend, **not** Kotlin),
MongoDB 8, Keycloak 26. Below is everything the slides name that doesn't exist yet, or exists
under a different name than the slides use.

## Missing agents

- ~~`api-contract-engineer`~~ — **done**: `dist/agents/api-designer.md` renamed to
  `dist/agents/api-contract-engineer.md` (and `name:`/all references across `README.md`,
  `dist/AGENTS.md`, `FEATURES.md`, `CLAUDE.md`, `lib/detect/openapi.sh`,
  `dist/skills/openapi-patterns/SKILL.md` updated to match).
- ~~`java-spring-engineer` / `java-spring-reviewer`~~ — **resolved differently**: rather than adding
  a second Java-named agent pair, `spring-boot-engineer`/`-reviewer` were made language-neutral.
  New `dist/skills/java-patterns/SKILL.md` mirrors `kotlin-patterns` (records, `Optional`, pattern
  matching/sealed interfaces, Jackson, naming conventions, Spring Boot patterns). Both agent
  bodies now detect Kotlin vs. Java at the top and defer idiom/code-style detail to whichever
  skill applies; `lib/detect/java.sh`'s `_java_apply()` now adds `java-patterns` to
  `DETECTED_SKILLS` (previously only `logging-patterns clean-code`). `dist/AGENTS.md`'s Project
  Defaults (Language & Framework, Serialization, Build Tool, Testing sections) and `README.md`'s
  agent/skill tables and tech-defaults row were updated to match. Verified via
  `install.sh --auto --no-confirm --dry-run` against separate Java-only and Kotlin-only scratch
  projects — each now selects the correct skill. So the slides' `java-spring-engineer`/`-reviewer`
  naming should just be replaced with `spring-boot-engineer`/`-reviewer` (Kotlin or Java).
- ~~`infra-engineer`~~ — **resolved by updating the slide instead of the repo**: decided to keep
  Docker/Kubernetes/security as three separate agents rather than unifying them, since that's how
  the repo actually models them (`docker-engineer`, `kubernetes-engineer`, `security-engineer`,
  each with its own scoped tools/permissions/skill). Slide 06's single "Infra → infra-engineer" row
  was split into three rows in `../../Work/OC/cd-2026-09-18/slides/SLIDES.md` — Docker →
  `docker-engineer`, Kubernetes → `kubernetes-engineer`, Security → `security-engineer` (now
  carrying both Security Review (OWASP) and Keycloak Best Practices). Slide 06's Backend row was
  also updated in the same pass: `java-spring-engineer`/`java-spring-reviewer` → the actual
  `spring-boot-engineer`/`spring-boot-reviewer` names.
- ~~Keycloak has no agent~~ — **resolved via the existing `security-engineer` agent**, not a new
  one: `lib/detect/security.sh` already maps Keycloak/OAuth2/Spring Security evidence to
  `security-engineer`, so a new `dist/skills/keycloak-patterns/SKILL.md` was added and wired into
  `security-engineer.md`'s `skills:` frontmatter + `_security_apply()`'s `DETECTED_SKILLS`. The
  slides' "Keycloak Best Practices" skill box should point at `security-engineer`, not a
  standalone Keycloak agent.

## Missing or mismatched skills

- ~~Testing Best Practices~~ — **done**: new `dist/skills/testing-patterns/SKILL.md`
  (Arrange-Act-Assert, naming, what to mock, coverage priorities, flaky-test causes — language
  agnostic). Wired into `spring-boot-engineer`/`-reviewer` and `angular-engineer`/`-reviewer`
  frontmatter, and added to `_kotlin_apply()`/`_java_apply()`/`_angular_apply()`'s
  `DETECTED_SKILLS` in `lib/detect/`, the same way `clean-code` already was — so Auto/Guided
  actually installs it, not just the frontmatter reference.
- ~~Spring Boot Best Practices~~ — **done**: new `dist/skills/spring-boot-patterns/SKILL.md` —
  framework-level, language-independent (DI, `@ConfigurationProperties` binding, transaction
  boundaries, controller/service/repository/`@ControllerAdvice` layering, profiles, testing
  strategy, actuator/health probes, the `@ConditionalOnBean` auto-config gotcha, and the Boot 4
  migration pitfalls section moved here from `spring-boot-engineer.md`'s body). `kotlin-patterns`/
  `java-patterns`'s previously-duplicated "Spring Boot Patterns" code-snippet sections were trimmed
  to a one-line pointer at this skill plus the one genuinely language-specific note each
  (`data class`/Mockito-Kotlin vs. `record`/Mockito). `spring-boot-engineer.md`'s own Steps
  2/3/6/7 and its old "Spring Boot 4 gotchas" section now point at this skill instead of repeating
  the content inline. Wired into both `spring-boot-engineer`/`-reviewer` frontmatter and
  `_kotlin_apply()`/`_java_apply()`'s `DETECTED_SKILLS`. Verified via
  `install.sh --auto --no-confirm --dry-run` against separate Java-only and Kotlin-only scratch
  projects — both now install `spring-boot-patterns` alongside the language skill.
- ~~Java Best Practices~~ — **done** (this was resolved as part of the earlier Kotlin/Java
  language-neutrality work — see the `spring-boot-engineer`/`-reviewer` section of this repo's
  history — `dist/skills/java-patterns/SKILL.md` exists and `_java_apply()` adds it).
- ~~MongoDB Best Practices~~ — **done**: new `dist/skills/mongodb-patterns/SKILL.md` (embed vs.
  reference, index design/ESR rule, aggregation pipeline ordering, Spring Data MongoDB
  conventions, change streams, transaction scope). Wired into `mongodb-engineer.md`'s `skills:`
  and `_mongodb_apply()`'s `DETECTED_SKILLS`.
- ~~Docker Best Practices~~ — **done**: new `dist/skills/docker-patterns/SKILL.md` (multi-stage
  builds, layer-cache ordering, base image hygiene, non-root user, `.dockerignore`, health checks,
  Compose conventions, scanning). Wired into `docker-engineer.md` and `_docker_apply()`.
- ~~Kubernetes Best Practices~~ — **done**: new `dist/skills/kubernetes-patterns/SKILL.md`
  (requests/limits, the three probe types, Helm chart/values structure, rolling-update strategy,
  secrets handling, ingress/TLS, CI/CD rollout pattern). Wired into `kubernetes-engineer.md` and
  `_kubernetes_apply()`.
- ~~Keycloak Best Practices~~ — **done**, see the resolved missing-agent note above:
  `dist/skills/keycloak-patterns/SKILL.md` (realm/client setup, Spring Security resource-server
  config, role/scope mapping, token validation gotchas, Angular-side integration, local dev via
  Compose).
- ~~Security Review (OWASP)~~ — **done**: new `dist/skills/security-review/SKILL.md` — OWASP Top
  Ten-aligned checklist covering injection, broken auth/session management, broken access control,
  sensitive data exposure, security misconfiguration, vulnerable dependencies, SSRF, logging/
  monitoring, plus a frontend-specific section (bundle secrets, `npm audit`, interceptor scope).
  Cross-cutting by design, matching slide 05's "Allgemein" framing — wired into `security-engineer`,
  both `spring-boot-engineer`/`-reviewer`, and both `angular-engineer`/`-reviewer`, the same way
  `clean-code`/`testing-patterns` are: added to `_kotlin_apply()`/`_java_apply()`/
  `_angular_apply()`/`_security_apply()`'s `DETECTED_SKILLS` in `lib/detect/`, not left to the
  frontmatter alone. Verified via `install.sh --auto --no-confirm --dry-run`: installs exactly once
  even though four different `_apply()` functions each add it (existing `awk '!seen[$0]++'` dedup
  in `lib/auto.sh` handles this for free).
- ~~API-Design-Review~~ / ~~OpenAPI-Generator Best Practices~~ — **done, via a real split**:
  `dist/skills/openapi-patterns/` renamed to `dist/skills/api-design-review/` (spec design-first
  workflow, single source of truth, structuring large specs — plus a new "Reviewing generated-code
  usage for contract compliance" section covering the backend/frontend-side half of contract
  review: generated-interface implementation, response/error-schema matching, request-payload
  drift). New `dist/skills/openapi-generator-patterns/SKILL.md` covers the tool itself: never edit
  generated code, Spring Boot generator options (`interfaceOnly`, `useTags`, `useSpringBoot3`,
  Kotlin vs. Java model output), Angular generator options (`providedInRoot`, pinning
  `openapitools.json`), generated-code layout, the regeneration workflow, and a CI-enforcement step.
  Wired: `api-contract-engineer` gets both; `spring-boot-engineer`/`angular-engineer` get both
  (they run the generator *and* need to stay contract-compliant); `spring-boot-reviewer`/
  `angular-reviewer` get `api-design-review` only (review, not generation).
  `lib/detect/openapi.sh`'s `_openapi_apply()` updated to add both new skill names. Verified via
  `install.sh --auto --no-confirm --dry-run` against the same full-stack scratch project used
  earlier — both skills install cleanly, no leftover `openapi-patterns` references anywhere in the
  repo (`grep -rn openapi-patterns` outside this TODO file returns nothing).
- **Git-/Commit-Hygiene** — not a gap exactly; this is already handled by the installed
  `## Git Workflow` policy in `AGENTS.md` (see `lib/git_workflow.sh`) rather than a `dist/skills/`
  entry. Slide 05 lists it alongside skills, so just confirm the talk explains it as "built into
  every agent via AGENTS.md," not a pickable skill.

## Pre-existing mismatch spotted while checking (not slide-driven, worth fixing anyway)

- ~~`angular-engineer.md`'s `skills:` frontmatter listed `primeng-patterns`/`frontend-design`,
  neither existing under `dist/skills/`~~ — **done**: new `dist/skills/taigaui-patterns/SKILL.md`
  (standalone import style, `NG_EVENT_PLUGINS`/`provideAnimations()` app-config gotcha, CSS
  custom-property theming alongside Tailwind, forms/tables/dialogs, common pitfalls) replaces
  `primeng-patterns` in both `angular-engineer.md` and `angular-reviewer.md`'s `skills:`
  frontmatter (the slides use TaigaUI, not PrimeNG). `frontend-design` was dropped from the
  frontmatter entirely rather than given a `dist/skills/` stand-in — it's a genuinely separate,
  already-available built-in Claude Code skill, and the `skills:` frontmatter field's contract
  (per `CLAUDE.md`) is "must exist under `dist/skills/`," which a reference to a built-in skill
  can never satisfy.
- ~~`taigaui-patterns`/`tailwind-patterns` only reachable via static frontmatter, never actually
  installed by Auto/Guided~~ — **done, via independent detection** (superseding an earlier attempt
  at unconditional bundling into `_angular_apply()`, reverted): new
  `lib/detect/tailwind.sh`/`lib/detect/taigaui.sh`, each a skill-only category (no agent of its
  own, same shape as `jpa.sh`) that greps `PROJECT_PACKAGE_JSON_FILES` for `"tailwindcss"`/
  `"@tailwindcss/`" and `"@taiga-ui/`" respectively. `_angular_apply()` itself no longer adds
  either — an Angular project genuinely can have neither (plain CSS, a different component
  library), so this is a real either/or, not a fixed stack default. Both are reflection-discovered
  automatically by Auto (`detect_tailwind`/`detect_taigaui`) and Guided
  (`_tailwind_apply`/`_taigaui_apply`), grouped under "Frontend" — no registry changes needed.
  Verified via `install.sh --auto --no-confirm --dry-run`: a `package.json` with both dependencies
  installs both skills; a bare `angular.json` with neither dependency installs neither.
