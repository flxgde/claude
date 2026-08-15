# Angular Style Guide (Official)

Source: https://angular.dev/style-guide
Fetched: 2026-03-25

## Naming

- File names: kebab-case with type suffix: `user-profile.component.ts`, `auth.guard.ts`
- Test files: `.spec.ts` suffix
- Classes: UpperCamelCase — `UserProfileComponent`, `AuthGuard`
- Selectors: kebab-case with app prefix — `app-user-profile`
- Directives (attribute): camelCase — `[appTooltip]`

## Project structure

Feature-based, NOT type-based:
```
src/
├── movie-reel/
│   ├── show-times/
│   │   ├── film-calendar/
│   │   ├── film-details/
│   ├── reserve-tickets/
│   │   ├── payment-info/
│   │   ├── purchase-confirmation/
```
Do NOT create `components/`, `directives/`, `services/` folders.

## Dependency injection

Prefer `inject()` function over constructor injection — more readable, better type inference.

## Class organization order

1. Injected dependencies (via inject())
2. Inputs and outputs
3. Queries
4. Other properties
5. Methods

## Property access modifiers

- `protected` for properties only accessed in templates
- `readonly` for signal inputs, outputs, queries (Angular initializes them)
- `private` for internal-only

## Template

- Prefer `[class]` and `[style]` bindings over `NgClass`/`NgStyle`
- Name event handlers for actions: `(click)="saveUserData()"` not `(click)="handleClick()"`
- No complex logic in templates — move to computed signals or methods
