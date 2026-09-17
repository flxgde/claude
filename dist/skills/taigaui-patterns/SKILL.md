---
name: taigaui-patterns
description: TaigaUI v5 patterns for Angular — module/import structure, standalone component usage, theming with CSS custom properties, form controls (TuiTextfield, TuiSelect, TuiDataList), tables, and dialogs. Use when building Angular UI with TaigaUI components.
---

# TaigaUI Patterns (v5)

Reference: https://taiga-ui.dev/

## Import style

TaigaUI v5 components are standalone — import the component directly, never a feature module:

```typescript
import { TuiButton } from '@taiga-ui/core';
import { TuiTextfield } from '@taiga-ui/core';

@Component({
  selector: 'app-user-form',
  imports: [TuiButton, TuiTextfield],
  template: `...`,
})
export class UserFormComponent {}
```

Avoid the old `TuiRootModule`/feature-module (`TuiButtonModule`, etc.) imports from v3-era
TaigaUI docs/examples — they don't exist in v5's standalone API.

## App root setup

```typescript
import { provideAnimations } from '@angular/platform-browser/animations';
import { NG_EVENT_PLUGINS } from '@taiga-ui/event-plugins';

export const appConfig: ApplicationConfig = {
  providers: [
    provideAnimations(),
    NG_EVENT_PLUGINS,
    // ...other providers
  ],
};
```

`NG_EVENT_PLUGINS` is required for TaigaUI's custom event bindings (e.g. dialogs closing on
backdrop click) — a common source of "component renders but doesn't behave right" bugs when
missing.

## Theming

TaigaUI themes via CSS custom properties, not a TS theme object — set overrides in a global
stylesheet:

```css
:root {
  --tui-background-base: oklch(98% 0 0);
  --tui-text-primary: oklch(20% 0 0);
}

:root[data-theme='dark'] {
  --tui-background-base: oklch(15% 0 0);
  --tui-text-primary: oklch(95% 0 0);
}
```

Combine with Tailwind's own `@theme` tokens (see `tailwind-patterns`) rather than maintaining two
separate design-token systems — point Tailwind's tokens at the same CSS custom properties TaigaUI
reads, so both stay visually consistent from one source.

## Forms

Prefer `TuiTextfield`/`TuiSelect`/`TuiDataList` bound to Angular's typed reactive forms (or signal
forms — see `angular-patterns`) over native `<input>`/`<select>`:

```typescript
@Component({
  imports: [TuiTextfield, ReactiveFormsModule],
  template: `
    <tui-textfield>
      <input tuiTextfield formControlName="email" />
      <label tuiLabel>Email</label>
    </tui-textfield>
  `,
})
export class UserFormComponent {
  protected readonly form = new FormGroup({
    email: new FormControl('', { nonNullable: true, validators: [Validators.email] }),
  });
}
```

## Tables

`@taiga-ui/addon-table`'s `TuiTable` directive works on a plain `<table>` — don't reach for a
separate data-grid library for straightforward paginated/sortable lists; it composes with Angular's
`@for` and signals directly.

## Dialogs

Use `TuiDialogService.open()` (injected via `inject(TuiDialogService)`), not a manually toggled
`*ngIf`-gated component — it handles focus trapping, backdrop click, and escape-key close for free,
and returns an `Observable` for the dialog's result.

## Common pitfalls

- Forgetting `provideAnimations()`/`NG_EVENT_PLUGINS` in `app.config.ts` — components render inert.
- Mixing v3 module-based import examples (still common in search results) with v5's standalone
  API — always check against the v5 docs, not cached v3 knowledge.
- Overriding TaigaUI's CSS custom properties in a component-scoped stylesheet instead of globally —
  they're designed to cascade from `:root`, so a scoped override usually just fails silently.
