# Implementation Plan: Rate Limiting for auth_middleware via cache_layer (Redis)

## Task

Add rate limiting to the `auth_middleware` component, using Redis through the existing `cache_layer` component.

## Structural Analysis (Prolog-derived)

### Ontology Validation

The ontology passes validation with no warnings. The C4 model contains 2 contexts, 6 containers, 12 components, 20 file mappings, and 12 dependency edges.

### Target Components

| Component | Container | Role | File |
|---|---|---|---|
| `auth_middleware` | `api_server` | JWT validation middleware | `/project/api/src/middleware/auth.ts` |
| `cache_layer` | `api_server` | Redis caching abstraction | `/project/api/src/cache/redis.ts` |

### Dependency Chains

- `auth_middleware` -> `token_issuer` (terminus)
- `cache_layer` -> `db_pool` (terminus)

Currently, `auth_middleware` does **not** depend on `cache_layer`. This change introduces a new dependency edge: `depends_on(auth_middleware, cache_layer)`.

### Change Scope (from Prolog `change_scope/1`)

- **Targets**: `[auth_middleware, cache_layer]`
- **Upstream (must understand before changing)**: `[db_pool, token_issuer]`
  - `db_pool` -- backing store for `cache_layer`; must understand Redis connection lifecycle
  - `token_issuer` -- `auth_middleware` validates tokens issued by this component; rate limiting must not interfere with valid token validation
- **Downstream (may break)**: `[api_client, app_shell, auth_ui, dashboard, order_controller, user_controller]`
  - All six controllers and frontend components that depend on `auth_middleware` will see rate-limit rejections (HTTP 429) -- they must handle this gracefully
- **Total scope**: 10 components across 10 files

### Impact Analysis

**auth_middleware** (primary target):
- Depended on by: `user_controller`, `order_controller`, `api_client`
- Transitive impact: 6 components (`api_client`, `app_shell`, `auth_ui`, `dashboard`, `order_controller`, `user_controller`)
- This is a **cross-cutting concern**: used by the `frontend` container externally

**cache_layer** (supporting target):
- Depended on by: `order_controller`
- Transitive impact: 1 component (`order_controller`)
- Lower blast radius; changes here are contained within `api_server`

### Cross-Cutting Concerns

- `auth_middleware` is shared infrastructure -- used across the `api_server`/`frontend` container boundary. Any behavioral change (like returning 429s) propagates to the frontend.
- `token_issuer` is used cross-container (`auth_service` -> `api_server`). Rate limiting must not block the token validation path itself.

### Container Coupling

- `api_server` -> `auth_service` (1 edge): token validation
- `frontend` -> `api_server` (1 edge): API calls through `api_client`

Rate limiting adds no new cross-container coupling -- both targets are within `api_server`.

---

## Implementation Order

Based on the topological sort from Prolog, the relevant implementation sequence is:

1. **`db_pool`** (step 4 in global order) -- no changes needed, but must verify Redis connection config supports the additional load from rate-limit checks
2. **`cache_layer`** (step 5) -- extend with rate-limiting primitives
3. **`auth_middleware`** (step 6) -- integrate rate limiter using `cache_layer`
4. **`user_controller`** + **`order_controller`** (steps 7-8) -- add 429 handling/tests
5. **`api_client`** (step 9) -- add retry-after / 429 handling on the frontend side

This order respects the dependency graph: modify the Redis abstraction first, then consume it in the middleware, then update downstream consumers.

---

## Detailed Steps

### Step 1: Review Prerequisites (no code changes)

**Files to review:**
- `/project/api/src/db/pool.ts` -- understand connection pooling; confirm Redis client is accessible
- `/project/api/src/cache/redis.ts` -- understand current cache abstraction API
- `/project/api/src/middleware/auth.ts` -- understand middleware signature and request lifecycle
- `/infra/auth/issuer.go` -- understand token format for extracting rate-limit keys (user ID, client IP)

### Step 2: Extend cache_layer with Rate-Limiting Primitives

**File**: `/project/api/src/cache/redis.ts`

Add a sliding-window or token-bucket rate limiter backed by Redis:

- `checkRateLimit(key: string, limit: number, windowSec: number): Promise<{allowed: boolean, remaining: number, retryAfter?: number}>`
- Use Redis `INCR` + `EXPIRE` for a fixed-window counter, or `EVALSHA` with a Lua script for sliding-window accuracy
- The key should be parameterizable (e.g., by IP, user ID, or API key)
- Return `remaining` count and `retryAfter` seconds for downstream use

**Rationale**: Encapsulating rate-limit logic in `cache_layer` keeps the Redis protocol details in one place. `auth_middleware` consumes a clean async interface.

### Step 3: Integrate Rate Limiter into auth_middleware

**File**: `/project/api/src/middleware/auth.ts`

- Import and call `checkRateLimit` from `cache_layer` early in the middleware pipeline (before or after JWT validation, depending on desired behavior)
- **Before JWT validation** (recommended): rate-limit by client IP to prevent brute-force token guessing. This protects `token_issuer` from being overwhelmed.
- **After JWT validation** (alternative): rate-limit by authenticated user ID for per-user quotas
- On rate-limit exceeded: return HTTP 429 with `Retry-After` header and a JSON error body
- On Redis failure: **fail open** (allow request through) to avoid Redis outage causing total auth failure

**New dependency**: This creates `depends_on(auth_middleware, cache_layer)`. Update the facts file accordingly.

### Step 4: Update Downstream Consumers

**Files**:
- `/project/api/src/controllers/user.ts` -- add tests for 429 propagation
- `/project/api/src/controllers/order.ts` -- add tests for 429 propagation
- `/project/frontend/src/lib/api.ts` -- add 429 handling with exponential backoff and `Retry-After` header parsing
- `/project/frontend/src/components/Auth.tsx` -- display user-friendly rate-limit messages on login forms

### Step 5: Configuration and Redis Infrastructure

**File**: `/project/config/redis` (redis_cache container config)

- Add rate-limit key prefix/namespace to avoid collisions with existing cache keys
- Configure TTL defaults for rate-limit windows
- Consider a separate Redis database or keyspace if isolation is needed

---

## Updated Dependency (Facts File Delta)

After implementation, add to the facts file:

```prolog
depends_on(auth_middleware, cache_layer).
```

This does **not** introduce a circular dependency (verified: `auth_middleware` -> `cache_layer` -> `db_pool` is a clean chain). The topological sort remains valid since `cache_layer` already precedes `auth_middleware` in the implementation order.

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| Redis outage blocks all auth | Fail-open design: if Redis is unreachable, skip rate limiting |
| Rate-limit keys leak across tenants | Use composite keys: `ratelimit:{tenant}:{ip}:{endpoint}` |
| High cardinality keys exhaust Redis memory | Set TTL on all rate-limit keys; monitor key count |
| Frontend not handling 429 | Step 4 explicitly adds retry logic to `api_client` |
| `auth_middleware` is cross-cutting (impacts frontend) | All 6 downstream components identified; test each |

---

## Testing Strategy

1. **Unit tests** for `cache_layer` rate-limit primitives (mock Redis)
2. **Integration tests** for `auth_middleware` with real Redis (verify 429 response, headers, counter decrement)
3. **Downstream tests** for `user_controller` and `order_controller` (verify 429 passthrough)
4. **Frontend tests** for `api_client` retry behavior
5. **Chaos test**: kill Redis during load; confirm fail-open behavior

---

## Query Log

Full Prolog reasoning trace available at: `test_facts_queries.md` (in this directory).

Queries executed:
- `full auth_middleware,cache_layer` -- validation, summary, change scope, impact, implementation order, cross-cutting, coupling
- `chain auth_middleware` -- dependency chain trace
- `chain cache_layer` -- dependency chain trace
- `describe webapp` -- full C4 tree for the webapp system
