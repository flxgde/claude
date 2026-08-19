# Global Instructions

<!-- IF_PRACTICE:plan-mode -->
## Plan Mode Default

- Enter plan mode for any non-trivial task (3+ steps, architectural decisions, or non-trivial bugfixes)
- For non-trivial bugfixes: investigate root cause in plan mode, then delegate the fix to the appropriate engineer agent
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity
<!-- END_IF -->

<!-- IF_PRACTICE:self-improvement -->
## Self-Improvement Loop

- After ANY correction: update `tasks/lessons.md` in the current project with the pattern
- Write rules that prevent the same mistake from recurring
- Review `tasks/lessons.md` at the start of each project session if it exists
<!-- END_IF -->

<!-- IF_PRACTICE:verification -->
## Verification Before Done

- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness
<!-- END_IF -->

## Git Workflow

<!-- GIT_WORKFLOW_POLICY -->

<!-- IF_PRACTICE:demand-elegance -->
## Demand Elegance (Balanced)

- For non-trivial changes: pause and ask "is there a more elegant solution?"
- If a fix feels hacky: step back and implement the elegant solution instead
- Skip for simple, obvious fixes — do not over-engineer
- Challenge your own work before presenting it
<!-- END_IF -->

<!-- IF_PRACTICE:skills -->
## Skills

- Use skills for any task that matches a defined capability
- Skills live in `.claude/skills/` (project) or `~/.claude/skills/` (global)
- Invoke with natural language; each skill is one independent capability
<!-- END_IF -->

<!-- IF_PRACTICE:sub-agents -->
## Sub-agents — Prefer Over Main Context

**Default to delegating** — if a specialist agent exists for the task, use it instead of handling it in the main context. The main context is for orchestration, not implementation.

- Check your agents directory before starting any non-trivial task — `.claude/agents/` (project) or
  `~/.claude/agents/` (global) for Claude Code; `.opencode/agents/` (project) or
  `~/.config/opencode/agents/` (global) for OpenCode
- If the task matches an agent's domain, delegate — do not implement it yourself
- One focused task per sub-agent invocation — do not overload a single agent
- The main context coordinates; agents implement

**When to delegate:**
- The task has a clear domain (backend, frontend, database, infra, security, docs)
- The work would pollute the main context with implementation detail
- A specialist would produce higher-quality output than generalist handling

**When to stay in main context:**
- Simple, cross-cutting tasks with no matching agent
- Coordination between multiple agents
- Short answers or lookups that don't warrant a full delegation

**Context cost rule — never read large files in the main loop:**
Every file read in the main context is re-sent as input tokens on *every subsequent turn* for the rest of the session. This accumulates fast, especially on Opus.
- **Never `Read` a file over ~100 lines directly in the main loop.** Delegate to an `Explore` or `general-purpose` subagent and keep only its conclusion.
- For multi-file exploration, always use the `Explore` subagent — never fan out `Read` calls in the main thread.
- Prefer `/clear` between unrelated tasks over `/compact`; compaction pays a full Opus pass, clear is free.

**Available agents:**

| Trigger | Agent |
|---|---|
<!-- IF_AGENT:architect -->
| New project, system design, tech selection, architectural decision | `architect` |
<!-- END_IF -->
<!-- IF_AGENT:api-designer -->
| API contract: new endpoints, spec changes, pre-generation review | `api-designer` |
<!-- END_IF -->
<!-- IF_AGENT:spring-boot-engineer -->
| Backend implementation or bugfix: Spring Boot / Kotlin code, openapi-generator | `spring-boot-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:angular-engineer -->
| Frontend implementation or bugfix: Angular components, services, routing | `angular-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:spring-boot-reviewer -->
| Backend code review or pre-commit check | `spring-boot-reviewer` |
<!-- END_IF -->
<!-- IF_AGENT:angular-reviewer -->
| Frontend code review or pre-commit check | `angular-reviewer` |
<!-- END_IF -->
<!-- IF_AGENT:docker-engineer -->
| Dockerfile or Docker Compose | `docker-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:kubernetes-engineer -->
| Helm charts, K8s manifests, deploy pipelines | `kubernetes-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:ansible-engineer -->
| Ansible playbooks, roles, server provisioning/config management | `ansible-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:postgres-engineer -->
| PostgreSQL schema, migrations, query optimization | `postgres-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:mongodb-engineer -->
| MongoDB schema, aggregation, indexes, Spring Data | `mongodb-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:security-engineer -->
| Security review, Keycloak/Spring Security config, pre-production | `security-engineer` |
<!-- END_IF -->
<!-- IF_AGENT:doc-writer -->
| README, ADRs, API docs, onboarding docs | `doc-writer` |
<!-- END_IF -->
<!-- END_IF -->

## Core Principles

- **Simplicity First**: Every change should be as small and focused as possible
- **No Laziness**: Find root causes — no temporary fixes; senior developer standards
- **Ask First**: Ask before making major architecture decisions, project structure choices, or technology selections

## Project Defaults

These apply to all new projects unless the project context says otherwise.

<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
### Language & Framework

- **Backend**: Kotlin with Spring Boot — prefer Kotlin for all new projects
- Fall back to Java only when working in an existing Java codebase
- No Lombok — Kotlin data classes, extension functions, and null safety make it unnecessary
<!-- END_IF -->

<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
### Serialization

- Use **kotlinx.serialization** (`@Serializable`) — avoid Jackson unless a dependency forces it
- If Jackson is unavoidable, flag it explicitly and keep it isolated
<!-- END_IF -->

<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
### Build Tool

- **Gradle** (Kotlin DSL: `build.gradle.kts` / `settings.gradle.kts`)
- Manage all dependency versions in `gradle/libs.versions.toml` (version catalog)
- Keep Gradle files minimal — no unnecessary plugins, configurations, or boilerplate
- Always use the latest stable versions of dependencies
<!-- END_IF -->

### Project Identity

- Artifact/project name must match the parent directory name
- Semantic versioning: bump the PATCH segment for each new generated version
<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
- Group ID: `de.flxg`
- Base Kotlin/Java package: `de.flxg`
<!-- END_IF -->

<!-- IF_AGENT:api-designer -->
### API First

- The OpenAPI spec is the contract between backend and frontend — design it before writing code
- Use openapi-generator to produce Spring Boot server stubs and Angular client stubs
- Never write controller mappings manually when a spec and generator are in place
<!-- END_IF -->

### Preferred Technology Defaults

These are defaults — suggest alternatives when a use case clearly calls for something better.

| Concern | Default |
|---|---|
<!-- IF_AGENT:postgres-engineer -->
| Relational DB | PostgreSQL |
<!-- END_IF -->
<!-- IF_AGENT:mongodb-engineer -->
| Document / NoSQL | MongoDB |
<!-- END_IF -->
<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
| Messaging | RabbitMQ |
<!-- END_IF -->
<!-- IF_AGENT:security-engineer -->
| Auth / SSO | Keycloak (when basic username/password login is not sufficient) |
<!-- END_IF -->
<!-- IF_AGENT:angular-engineer,angular-reviewer -->
| Frontend | Angular (TypeScript) |
<!-- END_IF -->
<!-- IF_AGENT:kubernetes-engineer -->
| Container orchestration | Kubernetes + Helm |
<!-- END_IF -->
<!-- IF_AGENT:docker-engineer -->
| Local development infra | Docker Compose |
<!-- END_IF -->
<!-- IF_AGENT:ansible-engineer -->
| Server provisioning / config management | Ansible |
<!-- END_IF -->

### Testing

- Always write tests for generated code: both positive (happy path) and negative (error/edge cases) cases
<!-- IF_AGENT:spring-boot-engineer,spring-boot-reviewer -->
- Unit tests for service layer; slice tests (`@WebMvcTest`) for controllers
- Use Kotlin backtick test names: `` `should return 404 when user not found`() ``
<!-- END_IF -->

### CI/CD

- Use **GitHub Actions** — generate workflows in `.github/workflows/`
- A standard pipeline: lint → test → build → (push image if applicable)

<!-- IF_AGENT:docker-engineer -->
### Docker Compose

- Generate a `docker-compose.yml` for local development covering all infrastructure the application needs
- Use health checks so dependent services wait for readiness
<!-- END_IF -->

<!-- IF_AGENT:ansible-engineer -->
### Ansible

- Keep inventory and playbooks in version control, separate `inventory/<environment>/` directories per environment
- Use `ansible-vault` for any secret values — never commit plaintext credentials
- Always dry-run (`--check --diff`) before applying to a real environment
<!-- END_IF -->

### Documentation

- Update `README.md` each time a new version is generated
- Keep README concise: description, prerequisites, local setup, test instructions, API reference link

### Reference Material

- When asked to use a URL as reference: fetch the page and save it to `reference/<descriptive-name>.md` in the current project
- Reference the local file in subsequent work instead of re-fetching

### Code Volume

- Minimize the amount of generated code — prefer concise, idiomatic code over verbose boilerplate
