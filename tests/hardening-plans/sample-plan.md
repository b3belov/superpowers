<!-- ⚠️ FIXTURE ONLY — Do not execute. This is a deliberately-broken test plan used to verify the hardening-plans skill (see tests/hardening-plans/test.sh). It contains seeded bugs, an incomplete redirect handler, and a non-TDD test step. Treating this file as a real plan will produce broken software. -->

# Toy URL-Shortener Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development.

**Goal:** Add a `/shorten` HTTP endpoint that converts long URLs to short codes, plus a `/<code>` redirect handler.

**Architecture:** Two Express handlers, in-memory map.

**Tech Stack:** Node.js, Express.

---

## Task 1: Shorten endpoint

**Files:**
- Create: `src/shorten.js`

- [ ] **Step 1: Implement endpoint**

```javascript
// SEEDED-FLAW [security]: no input validation; long-URL is used unsanitized.
// SEEDED-FLAW [reusability]: duplicates the random-id helper already at src/util/id.js.
// SEEDED-FLAW [performance]: linear scan over the entire map on every request for collision check.
const map = {};
app.post('/shorten', (req, res) => {
  const code = Math.random().toString(36).slice(2, 8);
  for (const k of Object.keys(map)) { /* O(n) collision check */ }
  map[code] = req.body.url;
  res.send(code);
});
```

- [ ] **Step 2: Commit**

```bash
git add src/shorten.js && git commit -m "feat: add /shorten endpoint"
```

## Task 2: Redirect handler

**Files:**
- Modify: `src/shorten.js`

- [ ] **Step 1: Implement redirect**

```javascript
// SEEDED-FLAW [ISSUES]: stub — tests in Task 3 reference behaviour this stub does not implement.
app.get('/:code', (req, res) => {
  // TODO redirect to map[req.params.code]
  res.status(501).send('not implemented');
});
```

## Task 3: Tests

**Files:**
- Create: `tests/shorten.test.js`

- [ ] **Step 1: Write tests**

```javascript
// SEEDED-FLAW [UX]: assertion messages are absent; failures show only "expected 200 got 501".
// SEEDED-FLAW [ISSUES]: no failing-test-first step; jumps straight to "run tests".
const request = require('supertest');
const app = require('../src/shorten');

test('shorten then redirect', async () => {
  const r1 = await request(app).post('/shorten').send({ url: 'https://example.com' });
  const code = r1.text;
  const r2 = await request(app).get('/' + code);
  expect(r2.status).toBe(302);
});
```

- [ ] **Step 2: Run tests**

```bash
npm test
```
