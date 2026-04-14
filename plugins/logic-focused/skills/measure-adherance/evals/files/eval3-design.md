# Notification System Design

## Architecture

The system uses an event-driven architecture with a central message queue (Kafka).

### Channels Supported
- Email (via SendGrid)
- In-app (via WebSocket push)

Note: SMS support is deferred to v2.

### Delivery Guarantees
Email and in-app notifications use at-least-once delivery semantics via Kafka consumer groups.

### Retry Policy
Failed deliveries are retried 3 times with exponential backoff starting at 1 second.

### Templates
Templates are stored in a versioned template registry. Localization supported via i18n keys.

### Performance
- In-app delivery target: 200ms (better than required)
- Email delivery target: 30 seconds

### Throughput
Target: 5,000 notifications/second. Horizontal scaling planned for v2.

## Audit Logging
Delivery attempts logged to append-only audit store with timestamp, channel, and outcome.
