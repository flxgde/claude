# Angular Zoneless (Official)

Source: https://angular.dev/guide/zoneless
Fetched: 2026-03-25

## Status

Zoneless is the **default in Angular v21+**. For v19/v20, opt in explicitly.

## Enabling Zoneless

```typescript
// app.config.ts — standalone bootstrap (Angular v19/v20)
import { provideZonelessChangeDetection } from '@angular/core';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(),
  ]
};
```

## Removing zone.js

1. Remove `zone.js` from `polyfills` in `angular.json`:
   ```json
   "polyfills": []
   ```
2. `npm uninstall zone.js`

## OnPush

Not strictly required for zoneless, but strongly recommended — ensures components declare changes explicitly rather than relying on Zone.js patching.

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
  ...
})
```

Signal reads in templates automatically schedule change detection — OnPush + signals is the intended pattern.

## Timing APIs

Replace `ngAfterViewInit` and `NgZone.onStable`:

```typescript
// One-time after next render
afterNextRender(() => {
  this.chart = new Chart(this.canvas.nativeElement);
});

// After every render cycle
afterEveryRender(() => {
  // responds to every change detection pass
});
```

## Migration Cautions

- Do NOT remove `NgZone.run()` / `NgZone.runOutsideAngular()` — removing causes regressions in libraries
- Remove: `NgZone.onStable`, `NgZone.onUnstable`, `NgZone.isStable`
- SSR: use `PendingTasks` to prevent premature serialization during async ops
- Reactive forms: require `ChangeDetectorRef.markForCheck()` or signal bindings for zoneless compatibility
