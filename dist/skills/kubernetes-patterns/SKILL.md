---
name: kubernetes-patterns
description: Kubernetes and Helm best practices — resource requests/limits, health probes, Helm chart structure, rolling updates, and secrets handling. Use when creating or updating Helm charts, K8s manifests, or CI/CD deployment pipelines to a cluster.
---

# Kubernetes Patterns

Reference: https://kubernetes.io/docs/concepts/configuration/overview/

## Resource requests and limits

Always set both, on every container — an unset request means the scheduler can't reason about bin
packing; an unset limit means one runaway pod can starve every other workload on the node:

```yaml
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Set the memory limit close to the actual working set — a JVM app OOM-killed by a too-low limit
looks identical to a real memory leak from the outside; measure before guessing.

## Health probes

Configure all three when the app supports them, and don't conflate them:

- **Startup probe** — for slow-starting apps (JVM apps especially); gates the other two probes
  until it succeeds once, so a legitimately slow boot doesn't get killed as unhealthy.
- **Liveness probe** — "is the process still functioning" (restart the pod if this fails). Keep it
  cheap — no downstream dependency checks (a database blip shouldn't restart the app).
- **Readiness probe** — "can this pod currently serve traffic" (remove from the Service's endpoints
  if this fails, don't restart). This one *should* check critical dependencies.

Spring Boot Actuator's `/actuator/health/liveness` and `/actuator/health/readiness` map directly
onto these — enable `management.endpoint.health.probes.enabled=true` rather than hand-rolling a
health endpoint.

## Helm chart structure

- Keep `values.yaml` the single place environment-specific values live — templates reference
  `.Values.*`, never a hardcoded environment name.
- Use `values-<env>.yaml` overlays (`-f values-prod.yaml`) for per-environment overrides, not
  separate near-duplicate charts per environment.
- `helm lint` and `helm template` (rendering locally) before every install/upgrade — catches
  YAML/templating mistakes before they hit the cluster.

## Rolling updates

Set `strategy.rollingUpdate.maxUnavailable`/`maxSurge` deliberately rather than accepting the
default — for a small deployment (1-2 replicas), the default can still cause a brief capacity dip
during a rollout. Pair with a readiness probe (above) so Kubernetes actually waits for the new pod
to be ready before routing traffic to it and terminating the old one.

## Secrets

- Never put a real secret value in a `values.yaml` committed to git — reference an existing
  `Secret` object (created out-of-band, or via a sealed-secrets/external-secrets controller) from
  the chart instead.
- `kubeseal`/sealed-secrets (if the cluster has it) lets an encrypted secret be committed safely —
  only the cluster's controller can decrypt it.

## Ingress

- Terminate TLS at the ingress controller, not the application — let cert-manager (or equivalent)
  handle certificate issuance/rotation rather than baking certs into the image or config.
- Scope ingress rules to the specific host/path the service needs — an overly broad path (`/`)
  on a shared ingress can accidentally shadow another service's routes.

## CI/CD

- A GitHub Actions deployment workflow should `helm template`/`helm lint` in a pre-deploy job
  (fail fast on a bad chart before touching the cluster), then `helm upgrade --install` with
  `--atomic` so a failed rollout automatically rolls back instead of leaving the release half-applied.
