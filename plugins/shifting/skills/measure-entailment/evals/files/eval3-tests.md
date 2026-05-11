# Notification System Test Plan

## Test Coverage

### Channel Tests
- [x] Email delivery end-to-end
- [x] In-app delivery via WebSocket
- [ ] SMS delivery — deferred, no implementation yet

### User Preference Tests
- [x] User can opt out of email
- [x] User can opt out of in-app
- [ ] User opt-out of SMS — not tested (no SMS)

### Retry Tests
- [x] Failed delivery triggers retry
- [x] Retry attempts: up to 3 retries verified
- [x] Exponential backoff timing verified

### Template Tests
- [x] Template versioning — old and new versions load correctly
- [x] i18n — English and Spanish locales tested

### Performance Tests
- [x] In-app latency: measured at 180ms average (passes 500ms requirement)
- [x] Email latency: measured at 25s average (passes 30s requirement)
- [ ] Load test at 10,000/sec — not yet run

### Audit Log Tests
- [x] Each delivery attempt creates an audit record
- [x] Audit records include timestamp and channel
- [ ] PII retention limit (90 days) not yet tested
