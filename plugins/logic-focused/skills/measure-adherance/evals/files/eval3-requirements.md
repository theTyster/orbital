# Notification System Requirements

## Core Features

1. **Multi-channel delivery** — System must support email, SMS, and in-app notifications.
2. **User preferences** — Users can opt out of each channel independently.
3. **Delivery guarantees** — Email and SMS notifications must be delivered at least once.
4. **Retry logic** — Failed deliveries must be retried up to 3 times with exponential backoff.
5. **Templating** — All notification content must use versioned templates.
6. **Audit log** — Every delivery attempt must be recorded with timestamp, channel, and status.

## Non-Functional Requirements

- Maximum delivery latency for in-app: 500ms
- Maximum delivery latency for email/SMS: 30 seconds
- System must handle 10,000 notifications per second at peak load
- Templates must support localization (i18n)

## Compliance

- No PII may be stored in notification logs beyond 90 days
- SMS content must comply with carrier regulations (max 160 chars per segment)
