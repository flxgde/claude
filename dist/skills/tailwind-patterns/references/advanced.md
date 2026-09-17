# tailwind-patterns — advanced v4 patterns, migration, and best practices

## Advanced v4 Patterns

**Custom utilities** — reusable CSS without a JS plugin:

```css
@utility text-gradient {
  @apply bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent;
}
```

**Theme modifiers** — `@theme inline` when a token references another CSS variable (e.g. a
`next/font`-style CSS var); `@theme static` to force a variable to always emit, even if unused
directly in a utility class:

```css
@theme inline { --font-sans: var(--font-custom), system-ui; }
@theme static { --color-brand: oklch(65% 0.15 240); }
```

**Namespace overrides** — clear a default palette scale and define your own instead of extending it:

```css
@theme {
  --color-*: initial;
  --color-white: #fff;
  --color-primary: oklch(45% 0.2 260);
}
```

**Alpha scales via `color-mix()`** — instead of hardcoding a separate token per opacity step:

```css
@theme {
  --color-primary-50: color-mix(in oklab, var(--color-primary) 5%, transparent);
  --color-primary-100: color-mix(in oklab, var(--color-primary) 10%, transparent);
}
```

**Container queries** — define named container sizes, then use `@sm`/`@lg` variants scoped to a
`container-type` ancestor rather than the viewport:

```css
@theme {
  --container-sm: 24rem;
  --container-lg: 32rem;
}
```

## v3 → v4 Migration Checklist

- [ ] Replace `tailwind.config.ts` with a CSS `@theme` block
- [ ] Change `@tailwind base/components/utilities` to `@import "tailwindcss"`
- [ ] Move color definitions into `@theme { --color-*: value }`
- [ ] Replace `darkMode: "class"` with `@custom-variant dark (&:where(.dark, .dark *))`
- [ ] Move `@keyframes` inside `@theme` (only keyframes referenced by an `--animate-*` var emit)
- [ ] Replace `tailwindcss-animate` with native `@starting-style` transitions
- [ ] Replace `h-N w-N` with `size-N`
- [ ] Consider OKLCH for new color tokens
- [ ] Replace custom JS plugins with `@utility`

## Do's and Don'ts

- Use semantic tokens (`bg-primary`) — never raw palette utilities (`bg-blue-500`) in components
- Use `size-*` instead of pairing `h-*`/`w-*` for equal dimensions
- Always add a `.dark` override for any new `--color-*` token — a token with no dark counterpart is
  a bug, not an oversight
- Don't reach for `tailwind.config.ts` or `@tailwind` directives in a v4 project — that's v3
- Don't hardcode colors or add arbitrary values (`bg-[#1a1a1a]`) where a token extension belongs
  in `@theme` instead
