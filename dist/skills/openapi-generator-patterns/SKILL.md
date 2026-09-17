---
name: openapi-generator-patterns
description: openapi-generator usage and configuration — Spring Boot server-stub generation options, Angular client-stub generation options, generated-code layout, the regeneration workflow, and CI integration. Use when configuring or running openapi-generator, or working with its generated output. For the API contract's own design conventions, see api-design-review.
---

# OpenAPI Generator Patterns

Reference: https://openapi-generator.tech/docs/usage

This skill is about the **tool** — configuring and running `openapi-generator` and working with
what it produces. For designing or reviewing the contract itself, see `api-design-review`.

## Never edit generated code

Generated output is regenerated wholesale on every build — any manual edit is silently lost the
next time generation runs. If generated code needs something different, that always means either
the spec needs to change, or the generator's own options/templates need to change — never the
output file directly. Keep generated output out of version control (or, if committed for
visibility, clearly marked and re-generated in CI to catch drift) so a stray manual edit can't
survive a rebase unnoticed.

## Spring Boot server-stub generation

Gradle plugin (`org.openapi.generator`):

```kotlin
openApiGenerate {
    generatorName.set("spring")
    inputSpec.set("$rootDir/api/openapi.yaml")
    outputDir.set("$buildDir/generated")
    apiPackage.set("de.flxg.api")
    modelPackage.set("de.flxg.model")
    configOptions.set(mapOf(
        "interfaceOnly" to "true",       // generate the API interface only — we write the @RestController
        "useTags" to "true",              // group generated classes by spec `tags`, not by path segment
        "delegatePattern" to "false",     // interfaceOnly already gives us the seam we need
        "useSpringBoot3" to "true",       // Boot 4 still uses this flag name upstream
        "documentationProvider" to "none" // skip generating springdoc/swagger annotations if the project doesn't use them
    ))
}
```

- **`interfaceOnly: true`** is the important one — it generates the `UsersApi` interface for the
  controller to `implement`, instead of a full annotated controller class the generator expects
  you to extend. This is what makes "implement the generated interface" (see `api-design-review`
  and `spring-boot-engineer`) possible at all.
- Kotlin projects: pass `library.set("spring-boot")` and confirm `useTags`/model generation
  produces Kotlin data classes, not Java POJOs — the Spring generator's Kotlin support is driven by
  the project's own Kotlin plugin being detected, not a separate generator name.

## Angular client-stub generation

Via `@openapitools/openapi-generator-cli` (npm), not the Gradle/Maven plugin:

```json
{
  "scripts": {
    "generate:api": "openapi-generator-cli generate -i ../api/openapi.yaml -g typescript-angular -o src/app/api --additional-properties=providedInRoot=true,ngVersion=22"
  }
}
```

- **`providedInRoot: true`** — generated services register as root-provided injectables
  (`@Injectable({ providedIn: 'root' })`) instead of requiring a generated `ApiModule` import. Skip
  the module-based setup entirely for a standalone-components project (see `angular-patterns`).
- Set `ngVersion` to match the actual Angular version — the generator's TypeScript output shape
  (constructor injection style, RxJS operator imports) has changed across major Angular versions.
- Commit `openapitools.json` (pins the generator CLI version used) so a teammate's local
  regeneration produces byte-identical output, not a diff caused by a newer generator version.

## Generated-code layout

- Keep generated output under one dedicated directory (`src/app/api`, `build/generated`, etc.) —
  never interleaved with hand-written source. This is what makes a `.gitignore`/build-clean rule
  for "delete and regenerate" safe to run without also deleting hand-written files.
- Use a `.openapi-generator-ignore` file only for the rare case of a single generated file that
  genuinely needs a permanent hand-edit (uncommon) — prefer fixing the spec or generator config
  over reaching for this.

## Regeneration workflow

1. Spec changes land first (see `api-design-review`) and get agreed/merged.
2. Regenerate locally (`./gradlew openApiGenerate` / `npm run generate:api`) before writing any
   code against the new/changed operations — never hand-write against a spec you haven't actually
   regenerated from, since a typo in the spec becomes a hand-typed-and-therefore-uncaught mismatch.
3. Compile/typecheck immediately after regenerating, before touching implementation code — a
   breaking spec change should surface as a compile error in generated-code consumers, not as a
   runtime surprise later.

## CI integration

Add a CI step that regenerates from the spec and fails the build on any diff against what's
committed (if generated code is committed) or simply runs generation + compile (if it isn't) — this
is what actually enforces "the spec is the single source of truth" (see `api-design-review`) rather
than just documenting the intent.
