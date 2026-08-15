---
name: angular-patterns
description: Angular patterns for zoneless, signals-first development — provideZonelessChangeDetection, signal(), computed(), resource(), signal forms (experimental), standalone components, inject(), CLI usage, Keycloak integration, and official style guide conventions. Use when writing or reviewing Angular frontend code.
---

# Angular Patterns

Reference: https://angular.dev/style-guide

---

## Zoneless Setup

**Always use zoneless.** Zone.js is legacy — never start a new project with it.

```typescript
// app.config.ts
import { ApplicationConfig, provideZonelessChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(withInterceptors([errorInterceptor])),
  ],
};
```

Remove `zone.js` from `angular.json`:
```json
"polyfills": []
```
Then: `npm uninstall zone.js`

**Every component must have `ChangeDetectionStrategy.OnPush`** — signals in templates trigger change detection automatically. Without OnPush, the component falls back to zone-style dirty checking.

```typescript
@Component({
  selector: 'app-example',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `...`,
})
```

---

## Signals

### State in Services

Expose read-only signals publicly; keep writable signals private.

```typescript
@Injectable({ providedIn: 'root' })
export class UserStore {
  private readonly _user = signal<User | null>(null);
  private readonly _loading = signal(false);

  readonly user = this._user.asReadonly();
  readonly loading = this._loading.asReadonly();
  readonly userName = computed(() => this._user()?.name ?? 'Unknown');

  setUser(user: User): void { this._user.set(user); }
  clearUser(): void { this._user.set(null); }
}
```

### Signal Primitives

```typescript
// Writable signal
const count = signal(0);
count();              // read
count.set(5);         // overwrite
count.update(v => v + 1); // relative update

// Derived state — cached, lazy
const doubled = computed(() => count() * 2);

// Side effect — for non-reactive integrations only
effect(() => {
  document.title = `Items: ${count()}`;
});

// Writable derived — resets when source changes
const options = signal(['a', 'b', 'c']);
const selected = linkedSignal(() => options()[0]);
```

**Rule:** use `computed()` for derived state, `effect()` only for DOM/third-party integrations. Never use `effect()` to synchronize state — that's `computed()` territory.

---

## Signal Inputs, Outputs, Model

Use `input()`, `output()`, and `model()` — not `@Input()`, `@Output()`, or `EventEmitter`.
Apply `readonly` to all signal inputs.

```typescript
@Component({
  selector: 'app-user-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2>{{ user().name }}</h2>
    <button (click)="select()">Select</button>
  `,
})
export class UserCardComponent {
  // Inputs — always readonly
  readonly user = input.required<UserResponse>();
  readonly disabled = input(false, { transform: booleanAttribute });

  // Two-way binding
  readonly isOpen = model(false);

  // Events
  readonly selected = output<UserResponse>();

  protected select(): void {
    this.selected.emit(this.user());
  }
}
```

**Parent usage:**
```html
<app-user-card
  [user]="currentUser()"
  [(isOpen)]="panelOpen"
  (selected)="onUserSelected($event)"
/>
```

---

## resource() — Async Data Loading

Use `resource()` for data that depends on reactive signals. It handles loading, errors, and cancellation automatically.

```typescript
import { resource } from '@angular/core';

@Component({
  selector: 'app-user-detail',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (userResource.isLoading()) {
      <p>Loading...</p>
    } @else if (userResource.error()) {
      <p>Error loading user</p>
    } @else if (userResource.value(); as user) {
      <h2>{{ user.name }}</h2>
    }
    <button (click)="userResource.reload()">Refresh</button>
  `,
})
export class UserDetailComponent {
  readonly userId = input.required<number>();

  protected readonly userResource = resource({
    request: () => ({ id: this.userId() }),
    loader: async ({ request, abortSignal }) => {
      const res = await fetch(`/api/users/${request.id}`, { signal: abortSignal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json() as UserResponse;
    },
  });
}
```

### rxResource() — RxJS Loader

When using generated API services (Observable-based), use `rxResource()`:

```typescript
import { rxResource } from '@angular/core/rxjs-interop';

protected readonly userResource = rxResource({
  request: () => ({ id: this.userId() }),
  loader: ({ request }) => inject(UsersService).getUserById(request.id),
});
```

### httpResource() — HTTP Shorthand

For simple GET requests without the generated service:

```typescript
import { httpResource } from '@angular/common/http';

protected readonly user = httpResource<UserResponse>(
  () => `/api/users/${this.userId()}`,
);
```

**Rule:** `resource()` is for reads only — never use it for POST/PUT/DELETE mutations.

---

## RxJS Interop

When consuming existing Observable-based services, convert at the boundary:

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

@Component({ ... })
export class SearchComponent {
  protected readonly query = signal('');

  // Signal → Observable (for debounce)
  private readonly query$ = toObservable(this.query).pipe(
    debounceTime(300),
    distinctUntilChanged(),
  );

  // Observable → Signal (for template consumption)
  protected readonly results = toSignal(
    this.query$.pipe(switchMap(q => this.searchService.search(q))),
    { initialValue: [] },
  );
}
```

**Prefer signals** for local component state. Use RxJS only where it adds value (debounce, complex async orchestration, streams).

---

## Signal Forms (default)

**Use Signal Forms (`@angular/forms/signals`) for all new forms.** Do not use `ReactiveFormsModule` / `FormGroup` / `FormControl` / `formControlName` / `[formControl]`. The API is marked experimental by the Angular team, but on this project it is the default — accept the trade-off.

Shape:

1. Declare the data model as a `signal` holding a plain object.
2. Pass the signal to `form()` to get a `FieldTree` mirroring the shape.
3. Bind inputs with `[formField]="form.fieldName"` — two-way by default.
4. Read values / state via `form.field().value()`, `.valid()`, `.touched()`, `.errors()`, `.dirty()`, `.pending()`, `.disabled()`, `.readonly()`.
5. Update programmatically with `form.field().value.set(...)`.
6. Validators live in a schema callback, second argument to `form()`: `required`, `email`, `min`, `max`, `minLength`, `maxLength`, `pattern`, plus custom async validation. Pass `{ message: '…' }` for error text.

```typescript
import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { form, FormField, required, email } from '@angular/forms/signals';

interface LoginData {
  email: string;
  password: string;
}

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormField],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <form (submit)="onSubmit($event)">
      <label>
        Email
        <input type="email" [formField]="loginForm.email" />
      </label>
      @if (loginForm.email().touched() && !loginForm.email().valid()) {
        @for (err of loginForm.email().errors(); track err.kind) {
          <span class="error">{{ err.message }}</span>
        }
      }

      <label>
        Password
        <input type="password" [formField]="loginForm.password" />
      </label>

      <button type="submit" [disabled]="!loginForm().valid()">Log in</button>
    </form>
  `,
})
export class Login {
  protected readonly loginModel = signal<LoginData>({ email: '', password: '' });

  protected readonly loginForm = form(this.loginModel, (path) => {
    required(path.email, { message: 'Email is required' });
    email(path.email, { message: 'Enter a valid email address' });
    required(path.password, { message: 'Password is required' });
  });

  protected onSubmit(event: Event): void {
    event.preventDefault();
    if (!this.loginForm().valid()) return;
    const credentials = this.loginModel();
    // ...authService.login(credentials)
  }
}
```

Notes and gotchas:

- Import `form`, `FormField`, validators from `@angular/forms/signals` — never from `@angular/forms`.
- `[formField]` auto-syncs `required`, `disabled`, `readonly` attributes when appropriate. Do not also bind `[disabled]` or `[required]` — drive them through the form.
- The model signal and the field tree stay in sync both ways: typing updates the signal, `field.value.set(x)` updates both.
- Date/time inputs store ISO strings (`YYYY-MM-DD`, `HH:mm`). Convert via `new Date(field().value())` when needed.
- Multi-select `<select multiple>` is not supported by `[formField]` yet.
- Use `debounce(path.field, ms)` inside the schema to delay validation for expensive async validators — not for throttling general input.
- For wrapper components (PrimeNG, design-system inputs) that cannot accept `[formField]` directly, expose a custom `Field<T>` input and forward it to a native input inside the wrapper that carries `[formField]`. Do **not** fall back to `FormControl`.
- Reading `form.field()` returns a `FieldState` — call signals on it (`value()`, `valid()`, etc.). `form()` itself (the root) also returns a `FieldState` aggregating the whole tree.

When migrating existing Reactive Forms code, move it over in whole components — no mixed forms inside one component.

---

## Standalone Components

All components, directives, and pipes must be `standalone: true`. Do not use NgModule.

```typescript
@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [UserCardComponent, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @for (user of users(); track user.id) {
      <app-user-card [user]="user" />
    } @empty {
      <p>No users found.</p>
    }
  `,
})
export class UserListComponent {
  protected readonly users = input.required<UserResponse[]>();
}
```

---

## Template Syntax

Use Angular 17+ block syntax — never `*ngIf`, `*ngFor`, `*ngSwitch`:

```html
<!-- Conditional -->
@if (user(); as u) {
  <app-user-card [user]="u" />
} @else {
  <p>No user selected.</p>
}

<!-- Iteration — always provide track -->
@for (item of items(); track item.id) {
  <li>{{ item.name }}</li>
} @empty {
  <li>No items.</li>
}

<!-- Switch -->
@switch (status()) {
  @case ('active') { <span class="badge active">Active</span> }
  @case ('inactive') { <span class="badge">Inactive</span> }
  @default { <span>Unknown</span> }
}
```

**Rules:**
- No complex logic in templates — move to `computed()` or methods
- Name event handlers for the action: `(click)="saveUser()"` not `(click)="handleClick()"`
- Use `[class]` and `[style]` bindings over `NgClass`/`NgStyle`

---

## inject() and Property Access Modifiers

Use `inject()` over constructor injection. Apply correct access modifiers:

```typescript
@Component({ ... })
export class UserDetailComponent {
  // Services — private
  private readonly userStore = inject(UserStore);
  private readonly router = inject(Router);

  // Template-facing — protected (not public; not accessible outside template)
  protected readonly user = this.userStore.user;
  protected readonly loading = this.userStore.loading;

  // Signal inputs — readonly (Angular sets them)
  readonly userId = input.required<number>();
}
```

| Access | When to use |
|--------|-------------|
| `private` | Internal-only — not used in template |
| `protected` | Used in template only |
| `public` | Accessed by parent or external code |
| `readonly` | Signal inputs, outputs, queries, injected services |

---

## Feature-Based Project Structure

Do NOT create `components/`, `directives/`, `services/` type folders.

```
src/
├── app/
│   ├── core/                    # app-wide singletons: auth, http interceptors
│   ├── shared/                  # reusable UI components, pipes, directives
│   ├── users/
│   │   ├── user-list/
│   │   │   ├── user-list.component.ts
│   │   │   ├── user-list.component.html
│   │   │   └── user-list.component.spec.ts
│   │   ├── user-detail/
│   │   ├── user-store.ts        # signal-based state for this feature
│   │   └── user.routes.ts
│   ├── app.config.ts
│   ├── app.component.ts
│   └── app.routes.ts
├── api/                         # openapi-generator output (never edited manually)
```

---

## Angular CLI — Always Use It

Generate all artifacts via CLI — never create component files manually.

```bash
# Component with OnPush (add manually after — CLI doesn't set it by default)
ng generate component users/user-list --standalone

# Service
ng generate service users/user-store

# Guard (functional)
ng generate guard core/auth --functional

# Pipe
ng generate pipe shared/format-date --standalone

# Directive
ng generate directive shared/highlight --standalone

# Interface / type (for local models)
ng generate interface users/user-summary

# Full module-less lazy-loaded route (generates component + routes file)
ng generate @angular/core:app-shell
```

After generating a component, always:
1. Add `changeDetection: ChangeDetectionStrategy.OnPush`
2. Convert constructor injection to `inject()`
3. Move to the correct feature folder if the generator placed it elsewhere

---

## HTTP Error Handling

Use a functional interceptor — register in `appConfig` via `withInterceptors`:

```typescript
// core/interceptors/error.interceptor.ts
export const errorInterceptor: HttpInterceptorFn = (req, next) =>
  next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        inject(KeycloakService).login();
      } else if (error.status >= 500) {
        inject(NotificationService).error('Server error — please try again');
      }
      return throwError(() => error);
    }),
  );
```

---

## Keycloak Integration

```typescript
// app.config.ts
import { KeycloakService } from 'keycloak-angular';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(
      withInterceptors([authInterceptor, errorInterceptor]),
    ),
    {
      provide: APP_INITIALIZER,
      useFactory: (keycloak: KeycloakService) => () =>
        keycloak.init({ config: '/assets/keycloak.json', initOptions: { onLoad: 'check-sso' } }),
      deps: [KeycloakService],
      multi: true,
    },
  ],
};

// core/interceptors/auth.interceptor.ts
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(KeycloakService).getToken();
  const authReq = token
    ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : req;
  return next(authReq);
};

// Route guard
export const authGuard: CanActivateFn = () => inject(KeycloakAuthGuard).canActivate();
```

**Rules:**
- Never manually store or refresh tokens — `KeycloakService` handles this
- Never check roles in templates — enforce authorization at the backend
- Use `KeycloakAuthGuard` for protected routes, not manual checks

---

## Generated API Services

Never use raw `HttpClient` for API calls. Always use the generated service:

```typescript
// Bad — manually defining types and paths
const user = this.http.get<{ id: number; name: string }>('/api/users/1');

// Good — use generated service with generated types
import { UsersService, UserResponse } from '../api';

@Injectable({ providedIn: 'root' })
export class UserStore {
  private readonly api = inject(UsersService);

  readonly userResource = rxResource({
    request: () => ({ id: this.selectedId() }),
    loader: ({ request }) => this.api.getUserById(request.id),
  });
}
```

Regenerate after every OpenAPI spec change:
```bash
npm run generate:api
```

Do not edit files under the `api/` (or `generated/`) directory — they will be overwritten.

---

## afterNextRender / afterEveryRender

Replace `ngAfterViewInit` for DOM access in zoneless apps:

```typescript
// One-time DOM initialization
export class ChartComponent {
  private readonly canvas = viewChild.required<ElementRef>('canvas');

  constructor() {
    afterNextRender(() => {
      new Chart(this.canvas().nativeElement, { type: 'bar', data: this.chartData() });
    });
  }
}
```

Use `afterEveryRender` only when you need to react to every change detection pass.
