---
name: docker-patterns
description: Docker best practices — multi-stage builds, layer caching order, non-root users, minimal base images, and Docker Compose conventions for local development infrastructure. Use when writing or reviewing Dockerfiles or Compose setups.
---

# Docker Patterns

Reference: https://docs.docker.com/build/building/best-practices/

## Multi-stage builds

Always separate the build environment from the runtime image — the final image should contain the
built artifact and its runtime dependencies only, never a JDK/SDK, build tool cache, or source
tree:

```dockerfile
FROM eclipse-temurin:25-jdk AS build
WORKDIR /app
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:25-jre AS runtime
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
USER 1000:1000
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Layer ordering for cache efficiency

Order instructions from least- to most-frequently-changing, so Docker's build cache invalidates as
little as possible on a rebuild:

1. Base image
2. Dependency manifests only (`build.gradle.kts`/`package.json` + lockfile) — install dependencies
   in their own layer before copying source
3. Application source
4. Build step

Copying the whole project before installing dependencies busts the dependency-install cache layer
on every source change, turning a 2-second rebuild into a full re-download every time.

## Base images

- Prefer a minimal, actively-maintained base (`-jre`/`-slim`/distroless variants) over a full OS
  image — smaller attack surface, faster pulls, fewer CVEs to patch.
- Pin a specific version tag, never `latest` — `latest` silently changes what gets built on a later
  rebuild, breaking reproducibility.
- Rebuild periodically even without an application change, to pick up base-image security patches.

## Run as non-root

Set `USER` to a non-root UID in the final stage (see example above). A container running as root
that gets compromised has root inside the container, which is a meaningfully worse starting point
for a container-escape than a non-root process.

## `.dockerignore`

Keep one, matching (at minimum) what the project's `.gitignore` excludes plus build output
directories — without it, `COPY . .` sends build caches, `node_modules`, and `.git` into the build
context, slowing every build and occasionally leaking local state into the image.

## Health checks

Add a `HEALTHCHECK` (or the equivalent readiness probe at the orchestrator level — see
`kubernetes-patterns` for the Kubernetes case) so the container reports "unhealthy" instead of
looking "running" while the application inside has actually deadlocked or failed to start.

## Docker Compose for local infrastructure

- Compose is for **local development dependencies** (databases, message queues, Keycloak) — not a
  production deployment mechanism; production goes through Kubernetes/Helm (see
  `kubernetes-patterns`).
- Pin image versions in `docker-compose.yml` the same way as in a Dockerfile — no bare `postgres`/
  `mongo` without a tag.
- Use named volumes for anything that needs to survive a `down`/`up` cycle (database data
  directories); anonymous volumes silently orphan on every recreate.
- Add healthchecks + `depends_on: condition: service_healthy` for services with a startup order
  dependency (e.g. the app container needing the database to actually be accepting connections, not
  just have its process started).

## Scanning

Run `trivy`/`docker scout` (or the project's existing scanner) against the built image before
considering a Dockerfile change done — a clean multi-stage build can still ship a base image with
known CVEs.
