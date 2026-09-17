# tailwind-patterns — component variants and dark mode

## Component Variants

`class-variance-authority` (CVA) is framework-agnostic — it just returns a class string — so it
works in Angular the same way it does anywhere else. Compute the class string from signal inputs
with `computed()`:

```typescript
// button-variants.ts
import { cva, type VariantProps } from 'class-variance-authority';

export const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors ' +
    'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring ' +
    'disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-border bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'size-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);
export type ButtonVariants = VariantProps<typeof buttonVariants>;
```

```typescript
// button.component.ts
@Component({
  selector: 'app-button',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<button [class]="classes()" [disabled]="disabled()"><ng-content /></button>`,
})
export class ButtonComponent {
  readonly variant = input<ButtonVariants['variant']>('default');
  readonly size = input<ButtonVariants['size']>('default');
  readonly disabled = input(false, { transform: booleanAttribute });
  readonly classes = computed(() => buttonVariants({ variant: this.variant(), size: this.size() }));
}
```

```html
<app-button variant="destructive" size="lg">Delete</app-button>
```

For a shared `cn()` helper (merges conflicting Tailwind classes), use `tailwind-merge` + `clsx`:

```typescript
import { type ClassValue, clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

## Dark Mode (Angular)

Toggle the `.dark` class on `documentElement`; persist the choice and react to
`prefers-color-scheme` for `system`. Keep the state in a signal-based service, matching
`[[angular-patterns]]` conventions — readonly public signals, private writable state:

```typescript
@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly _theme = signal<'light' | 'dark' | 'system'>(
    (localStorage.getItem('theme') as 'light' | 'dark' | 'system' | null) ?? 'system',
  );
  readonly theme = this._theme.asReadonly();
  readonly resolvedTheme = computed<'light' | 'dark'>(() => {
    const t = this._theme();
    if (t !== 'system') return t;
    return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  });

  constructor() {
    effect(() => {
      document.documentElement.classList.toggle('dark', this.resolvedTheme() === 'dark');
    });
  }

  setTheme(theme: 'light' | 'dark' | 'system'): void {
    localStorage.setItem('theme', theme);
    this._theme.set(theme);
  }
}
```

`effect()` is correct here — it's a DOM-integration side effect, not derived state (see
`[[angular-patterns]]`'s signal rules).

## Native CSS Animations

v4 favors native CSS over JS animation libraries. `@starting-style` handles enter transitions,
including for the native `popover` API, without `tailwindcss-animate`:

```css
[popover] {
  transition: opacity 0.2s, transform 0.2s, display 0.2s allow-discrete;
  opacity: 0;
  transform: scale(0.95);
}
[popover]:popover-open { opacity: 1; transform: scale(1); }
@starting-style {
  [popover]:popover-open { opacity: 0; transform: scale(0.95); }
}
```

For state-driven components (dialogs, dropdowns), define the keyframes in `@theme` so they're
picked up by `--animate-*`, and drive them off a `data-state` attribute bound from a signal:

```css
@theme {
  --animate-dialog-in: dialog-fade-in 0.2s ease-out;
  @keyframes dialog-fade-in {
    from { opacity: 0; transform: scale(0.95) translateY(-0.5rem); }
    to { opacity: 1; transform: scale(1) translateY(0); }
  }
}
```

```html
<div [attr.data-state]="open() ? 'open' : 'closed'"
     class="data-[state=open]:animate-dialog-in">
```
