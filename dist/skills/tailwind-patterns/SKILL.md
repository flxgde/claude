---
name: tailwind-patterns
description: Tailwind CSS v4 patterns — CSS-first configuration with @theme, design tokens, OKLCH colors, dark mode, native CSS animations, and component variants in Angular. Use when styling Angular components with Tailwind, setting up or migrating a v4 theme, or standardizing design tokens across a codebase.
---

# Tailwind Patterns (v4)

Reference: https://tailwindcss.com/docs

> v4 replaced JS config with CSS-first configuration. If a project still has a `tailwind.config.ts`
> with `theme.extend`, treat that as a migration target — see `references/advanced.md`.

## When to Use

- Setting up Tailwind in a new Angular project, or auditing an existing v3 config for a v4 migration
- Defining design tokens (colors, radius, spacing, animation) with `@theme`
- Building variant-driven Angular components (buttons, cards, badges) styled with Tailwind
- Implementing dark mode
- Reviewing Tailwind usage for hardcoded colors, missing dark-mode coverage, or leftover v3 patterns

## Key v3 → v4 Changes

| v3 Pattern | v4 Pattern |
|---|---|
| `tailwind.config.ts` | `@theme` block in CSS |
| `@tailwind base/components/utilities` | `@import "tailwindcss"` |
| `darkMode: "class"` | `@custom-variant dark (&:where(.dark, .dark *))` |
| `theme.extend.colors` | `@theme { --color-*: value }` |
| `require("tailwindcss-animate")` | `@keyframes` inside `@theme` + `@starting-style` |
| `h-10 w-10` | `size-10` |

## CSS-First Configuration

```css
/* styles.css */
@import "tailwindcss";

@theme {
  /* Semantic tokens in OKLCH — better perceptual uniformity than HSL/hex */
  --color-background: oklch(100% 0 0);
  --color-foreground: oklch(14.5% 0.025 264);
  --color-primary: oklch(14.5% 0.025 264);
  --color-primary-foreground: oklch(98% 0.01 264);
  --color-destructive: oklch(53% 0.22 27);
  --color-border: oklch(91% 0.01 264);
  --color-ring: oklch(14.5% 0.025 264);

  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;

  /* Keyframes referenced by an --animate-* var are the ones v4 actually emits */
  --animate-fade-in: fade-in 0.2s ease-out;
  @keyframes fade-in {
    from { opacity: 0; }
    to { opacity: 1; }
  }
}

@custom-variant dark (&:where(.dark, .dark *));

.dark {
  --color-background: oklch(14.5% 0.025 264);
  --color-foreground: oklch(98% 0.01 264);
  --color-primary: oklch(98% 0.01 264);
  --color-primary-foreground: oklch(14.5% 0.025 264);
  --color-border: oklch(22% 0.02 264);
  --color-ring: oklch(83% 0.02 264);
}

@layer base {
  * { @apply border-border; }
  body { @apply bg-background text-foreground antialiased; }
}
```

**Token hierarchy** — never bind a component to a raw palette value:

```
Brand (oklch(45% 0.2 260)) → Semantic (--color-primary) → Utility (bg-primary)
```

Use `bg-primary`, never `bg-blue-500`, so a theme change is a one-line edit in `@theme`, not a
find-and-replace across every component.

## Detailed Patterns

- `references/components.md` — Angular component variants with CVA + signal inputs, a shared
  `cn()` helper, the signal-based dark-mode `ThemeService`, and native `@starting-style` animations.
- `references/advanced.md` — custom `@utility` definitions, `@theme inline`/`@theme static`,
  namespace overrides, `color-mix()` alpha scales, container queries, the full v3→v4 migration
  checklist, and do's/don'ts.

Read the relevant reference file when the summary above isn't enough — don't guess at CVA/signal
wiring or the migration steps from memory.
