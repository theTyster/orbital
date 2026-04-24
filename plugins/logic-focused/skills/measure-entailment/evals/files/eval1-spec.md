# Payment API Specification

## Endpoints

- `POST /payments/charge` — Initiates a payment charge. Requires authentication.
- `GET /payments/{id}` — Retrieves payment status. Requires authentication.
- `POST /payments/refund` — Issues a refund. Requires authentication and admin role.
- `GET /payments/history` — Lists payment history for authenticated user.

## Authentication

All endpoints require a valid JWT token in the `Authorization: Bearer` header.
The `/payments/refund` endpoint additionally requires the `admin` role claim in the token.

## Response Format

All responses are JSON. Successful responses use HTTP 200. Errors use standard HTTP status codes:
- 401 for missing or invalid token
- 403 for insufficient permissions
- 422 for validation errors

## Rate Limiting

- Standard endpoints: 100 requests per minute per user
- Refund endpoint: 10 requests per minute per user

## Data Retention

Payment records are retained for 7 years per financial regulation requirements.
