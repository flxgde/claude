# Angular Resource API (Official)

Source: https://angular.dev/api/core/resource
Fetched: 2026-03-25
Status: Experimental (since v19.0) — read-only operations only

## resource()

For loader functions returning a Promise.

```typescript
import { resource, ResourceStatus } from '@angular/core';

const userResource = resource({
  request: () => ({ id: userId() }),   // reactive request — re-runs when userId() changes
  loader: async ({ request, abortSignal }) => {
    const res = await fetch(`/api/users/${request.id}`, { signal: abortSignal });
    return res.json() as User;
  },
  defaultValue: null,
});

// Signals exposed
userResource.value()     // T | undefined
userResource.status()    // ResourceStatus enum
userResource.error()     // unknown
userResource.isLoading() // boolean shortcut
userResource.reload()    // manually trigger loader
```

## ResourceStatus Enum
```typescript
ResourceStatus.Idle      // no request yet
ResourceStatus.Loading   // loader in flight
ResourceStatus.Resolved  // successfully loaded — deprecated name, prefer Success
ResourceStatus.Error     // loader threw
```

## rxResource()

For loader functions returning an Observable (RxJS interop).

```typescript
import { rxResource } from '@angular/core/rxjs-interop';

const userResource = rxResource({
  request: () => ({ id: userId() }),
  loader: ({ request }) => this.userService.getUser(request.id),
});
```

## httpResource() — HTTP shorthand

Directly wraps HttpClient, returns a resource.

```typescript
import { httpResource } from '@angular/common/http';

const user = httpResource<User>(() => `/api/users/${userId()}`);
// user.value(), user.isLoading(), user.error(), user.reload()
```

## Key Behaviors

- **Automatic cancellation**: in-flight requests are aborted when request signal changes or component is destroyed (via AbortSignal in loader options)
- **Read-only**: do NOT use for POST/PUT/DELETE — mutations cancel in-progress loads
- **Request signal**: when the request() function returns a primitive/object, Angular tracks signal reads inside it and re-runs the loader automatically
