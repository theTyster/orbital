// =============================================================================
// Decision-trail emitter (D-5 ; §9 crit 11).
//
// Every control event — stage visit, cursor move, loopback, gap merge, disprove
// attempt, and halt — is appended to an auditable, typed trail. The trail is the
// run's side-effect of record; it is deterministic (C-1) and ordered.
//
// Each entry carries a non-empty string `kind`. Entries are plain data so two
// runs with different injected clock/RNG produce IDENTICAL trails (C-1).
// =============================================================================

"use strict";

/** Construct a fresh trail recorder. */
function createTrail() {
  const entries = [];
  return {
    /** Append a typed entry; returns it for convenience. */
    record(kind, fields = {}) {
      const entry = { kind, ...fields };
      entries.push(entry);
      return entry;
    },
    /** The accumulated entries (live array; treat as append-only). */
    get entries() {
      return entries;
    },
  };
}

module.exports = { createTrail };
