# Implementation Plan: Rate Limiting for auth_middleware via cache_layer (Redis)

## Task

Add rate limiting to the `auth_middleware` component, using Redis through the existing `cache_layer` component.

## Formal Analysis Summary

Analysis derived from `full auth_middleware,cache_layer` against the C4 ontology. The ontology validated without issues (2 contexts, 6 containers, 12 components, 12 dependencies).

---

## Change Scope

**Target components:** `auth_middleware`, `cache_layer`

| Category | Components |
|---|---|
| **Upstream (must understand)** | `token_issuer`, `db_pool` |
| **Downstream (may break)** | `user_controller`, `order_controller`, `api_client`, `auth_ui`, `dashboard`, `app_shell` |
| **Total scope** | 10 components across 3 containers |

---

## Impact Analysis

### auth_middleware

- **System:** webapp
- **Container:** api_server
- **Role:** JWT validation middleware
- **File:** `/project/api/src/middleware/auth.ts`
- **Depends on:** `token_issuer`
- **Depended on by (direct):** `user_controller`, `order_controller`, `api_client`
- **Transitive impact:** `user_controller`, `order_controller`, `api_client`, `app_shell`, `auth_ui`, `dashboard`

`auth_middleware` is a cross-cutting concern -- it lives in `api_server` but is consumed by the `frontend` container via `api_client`. Any behavioral change (such as returning 429 responses) will propagate to all 6 downstream components.

### cache_layer

- **System:** webapp
- **Container:** api_server
- **Role:** Redis caching abstraction
- **File:** `/project/api/src/cache/redis.ts`
- **Depends on:** `db_pool`
- **Depended on by (direct):** `order_controller`
- **Transitive impact:** `order_controller`

`cache_layer` has a narrower blast radius. Changes here primarily affect `order_controller`, but since we are *consuming* `cache_layer` (not modifying its interface), the risk is lower -- we need to understand its API, not change it.

---

## New Dependency

This change introduces a new dependency edge:

```
depends_on(auth_middleware, cache_layer).
```

This is safe from a topological ordering perspective: `cache_layer` (position 5) already precedes `auth_middleware` (position 6) in the implementation order, so no cycle is introduced.

---

## Implementation Order

Based on the topological sort, implement in this sequence:

### Phase 1: Understand prerequisites (read-only)

1. **`/infra/auth/issuer.go`** (`token_issuer`) -- Understand JWT token structure. Rate limiting keys may need to extract identity claims from tokens, so understanding token format is essential.

2. **`/project/api/src/db/pool.ts`** (`db_pool`) -- Understand the connection pool since `cache_layer` depends on it. Confirm Redis connections are managed separately from database connections.

3. **`/project/api/src/cache/redis.ts`** (`cache_layer`) -- Study the existing Redis abstraction API. Identify available operations (GET, SET, INCR, EXPIRE, or higher-level patterns). The rate limiter will call into this layer rather than talking to Redis directly.

### Phase 2: Implement the rate limiter

4. **`/project/api/src/middleware/auth.ts`** (`auth_middleware`) -- This is the primary modification target.

   - Import `cache_layer` to gain Redis access
   - Implement a sliding window or token bucket rate limiter:
     - **Key format:** e.g., `rate:<client_ip>` or `rate:<user_id>` (prefer user ID when JWT is valid, fall back to IP for unauthenticated requests)
     - **Algorithm:** Use Redis `INCR` + `EXPIRE` for a fixed window, or sorted sets for a sliding window
     - **Limits:** Configure via environment variables (e.g., `RATE_LIMIT_MAX=100`, `RATE_LIMIT_WINDOW_SEC=60`)
   - On limit exceeded: return HTTP 429 with `Retry-After` header
   - On Redis failure: fail open (allow the request) to avoid cascading outages

### Phase 3: Update downstream consumers for 429 handling

5. **`/project/frontend/src/lib/api.ts`** (`api_client`) -- Add 429 response handling. Implement exponential backoff or honor the `Retry-After` header.

6. **`/project/frontend/src/components/Auth.tsx`** (`auth_ui`) -- Surface rate-limit errors in login/signup flows with a user-facing message ("Too many attempts, please wait").

### Phase 4: Verify unaffected downstream components

7. **`/project/api/src/controllers/user.ts`** (`user_controller`) -- No code changes expected. Verify that rate limiting at the middleware layer does not require controller-level changes.

8. **`/project/api/src/controllers/order.ts`** (`order_controller`) -- No code changes expected. Verify behavior. This component already depends on both `auth_middleware` and `cache_layer`, so confirm no Redis key collisions between caching and rate limiting.

9. **`/project/frontend/src/components/Dashboard.tsx`** (`dashboard`) -- Verify renders correctly when `api_client` retries on 429.

10. **`/project/frontend/src/App.tsx`** (`app_shell`) -- Verify routing/layout handles transient 429 states gracefully.

---

## Cross-Cutting Concerns

Two components span container boundaries:

| Component | Home container | External consumers |
|---|---|---|
| `auth_middleware` | api_server | frontend |
| `token_issuer` | auth_service | api_server |

**Implication:** The `auth_middleware` change affects the `frontend` container. The `api_client` must be updated to handle 429 responses, or all frontend components will break on rate-limited requests.

## Container Coupling

| Edge | Weight |
|---|---|
| api_server -> auth_service | 1 component edge |
| frontend -> api_server | 1 component edge |

The rate limiting change does not introduce new cross-container coupling. The new `auth_middleware -> cache_layer` dependency is intra-container (both in `api_server`).

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Redis outage blocks all auth | Fail open: if Redis is unreachable, skip rate check and allow request |
| Rate limit keys collide with cache keys | Use a distinct key prefix (`ratelimit:`) in the rate limiter |
| Shared Redis connection pool exhaustion | Audit `cache_layer` connection pool size; consider dedicated pool for rate limiting if load warrants it |
| Frontend does not handle 429 | Phase 3 addresses this -- `api_client` must retry with backoff |
| Legitimate users hit limits (false positives) | Use per-user-ID limits (not per-IP) when authenticated; tune thresholds via env vars |

---

## Files to Review (Complete List)

From the Prolog `files_to_review` output:

```
/infra/auth/issuer.go
/project/api/src/cache/redis.ts
/project/api/src/controllers/order.ts
/project/api/src/controllers/user.ts
/project/api/src/db/pool.ts
/project/api/src/middleware/auth.ts
/project/frontend/src/App.tsx
/project/frontend/src/components/Auth.tsx
/project/frontend/src/components/Dashboard.tsx
/project/frontend/src/lib/api.ts
```

---

## Ontology Update

After implementation, update the facts file to reflect the new dependency:

```prolog
depends_on(auth_middleware, cache_layer).
```

This keeps the ontology accurate for future analyses.
