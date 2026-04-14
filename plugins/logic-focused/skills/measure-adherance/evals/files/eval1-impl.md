# Payment Service Implementation

## Implemented Endpoints

- `POST /payments/charge` — Processes a charge via Stripe. Auth required.
- `GET /payments/{id}` — Fetches payment record from database. Auth required.
- `POST /payments/refund` — Processes refund via Stripe. Requires admin role.
- `DELETE /payments/{id}` — Soft-deletes a payment record. Internal use only.

## Authentication

JWT authentication is enforced via middleware on all routes.
The refund endpoint checks for the `admin` role claim.
The delete endpoint is restricted by IP allowlist instead of role-based auth.

## Response Format

All endpoints return XML responses. Error codes follow the spec:
- 401 for auth failures
- 403 for permission failures
- 422 for bad input

## Rate Limiting

- Standard endpoints: 100 requests per minute per user
- Refund endpoint: 5 requests per minute per user (tighter than spec)

## Data Storage

Payment records stored in PostgreSQL. Retention policy: 3 years.
Records older than 3 years are archived to cold storage, not deleted.
