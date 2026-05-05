# Toy URL-Shortener Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Add a `/shorten` HTTP endpoint that converts long URLs to short codes.

**Architecture:** Single Express handler, in-memory map.

**Tech Stack:** Node.js, Express.

---

## Task 1: Endpoint

**Files:**
- Create: `src/shorten.js`

- [ ] **Step 1: Implement endpoint**

```javascript
// SEEDED-FLAW [security]: no input validation; long-URL is used unsanitized.
// SEEDED-FLAW [reusability]: duplicates the random-id helper already at src/util/id.js.
// SEEDED-FLAW [performance]: linear scan over the entire map on every request.
const map = {};
app.post('/shorten', (req, res) => {
  const code = Math.random().toString(36).slice(2, 8);
  for (const k of Object.keys(map)) { /* collision check */ }
  map[code] = req.body.url;
  res.send(code);
});
```

- [ ] **Step 2: Commit**

## Task 2: Redirect

<!-- SEEDED-FLAW [ISSUES]: redirect handler referenced by Task 3 tests is never implemented here. -->

## Task 3: Tests

- [ ] **Step 1: Run tests**

```bash
npm test
```

<!-- SEEDED-FLAW [UX]: no error message format documented; user sees raw stack traces. -->
<!-- SEEDED-FLAW [ISSUES]: no failing-test-first step; jumps straight to "run tests". -->
