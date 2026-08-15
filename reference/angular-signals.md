# Angular Signals (Official)

Source: https://angular.dev/guide/signals
Fetched: 2026-03-25

## Core APIs

### signal() — Writable State
```typescript
const count = signal(0);
count();           // read
count.set(5);      // overwrite
count.update(v => v + 1);  // derive from current
```

### computed() — Derived State
```typescript
const doubled = computed(() => count() * 2);
// Cached, lazy — only re-evaluates when accessed and dependencies changed
```

### effect() — Side Effects
```typescript
effect(() => {
  console.log(`User: ${currentUser()}`);
  // Runs whenever currentUser() changes
});
```
Use for non-reactive side effects (logging, DOM interop, analytics). Avoid for state synchronization — use computed() instead.

### linkedSignal() — Dependent Writable State
```typescript
const source = signal('hello');
const derived = linkedSignal(() => source().toUpperCase());
// derived is writable but resets when source changes
```

### asReadonly() — Encapsulation
```typescript
export class UserState {
  private readonly _user = signal<User | null>(null);
  readonly user = this._user.asReadonly();  // expose read-only

  setUser(user: User) { this._user.set(user); }
}
```

## Service State Pattern

```typescript
@Injectable({ providedIn: 'root' })
export class UserState {
  private readonly _user = signal<User | null>(null);
  readonly user = this._user.asReadonly();

  private readonly _loading = signal(false);
  readonly loading = this._loading.asReadonly();

  readonly userName = computed(() => this._user()?.name ?? 'Unknown');

  setUser(user: User) { this._user.set(user); }
}
```

## Signal Inputs, Outputs, Model

### input() and input.required()
```typescript
export class ChildComponent {
  name = input<string>();          // optional input — string | undefined
  id   = input.required<number>(); // required — throws if not provided

  // With transform
  disabled = input(false, { transform: booleanAttribute });
}
```

### model() — Two-Way Binding
```typescript
export class ToggleComponent {
  isOpen = model(false);     // readable + writable signal
  toggle() { this.isOpen.update(v => !v); }
}
// Parent: <app-toggle [(isOpen)]="parentOpen" />
```

### output()
```typescript
export class ClickerComponent {
  clicked = output<string>();
  handleClick() { this.clicked.emit('hello'); }
}
```

## untracked()
Excludes reads from dependency tracking:
```typescript
effect(() => {
  const a = trackThis();
  const b = untracked(() => dontTrackThis()); // no dependency
});
```

## Reactive Context
Signals track dependencies automatically inside: computed(), effect(), component templates, resource().
