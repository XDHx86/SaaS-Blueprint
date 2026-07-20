'use strict';

/**
 * Backend smoke tests (Node built-in test runner; no test dependency).
 *
 * Runs in CI and via `make test` against the runtime image. No Postgres or
 * Redis is available in those environments, so /readyz is expected to report
 * 503 — which is itself the documented, correct behavior of readiness when
 * dependencies are unreachable.
 */

const test = require('node:test');
const assert = require('node:assert');
const { build } = require('../src/server');

async function withServer() {
  const app = build();
  await app.listen({ port: 0, host: '127.0.0.1' });
  const port = app.server.address().port;
  return { app, url: (p) => `http://127.0.0.1:${port}${p}` };
}

test('GET /healthz → 200 and status ok', async () => {
  const { app, url } = await withServer();
  try {
    const res = await fetch(url('/healthz'));
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.status, 'ok');
    assert.ok(typeof body.uptime_s === 'number');
  } finally {
    await app.close();
  }
});

test('GET /api/status → 200 with service contract', async () => {
  const { app, url } = await withServer();
  try {
    const res = await fetch(url('/api/status'));
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.service, 'infra-lab-backend');
    assert.ok(body.dependencies.postgres);
    assert.ok(body.dependencies.redis);
  } finally {
    await app.close();
  }
});

test('GET /metrics → Prometheus text exposure', async () => {
  const { app, url } = await withServer();
  try {
    const res = await fetch(url('/metrics'));
    assert.strictEqual(res.status, 200);
    assert.match(res.headers.get('content-type') || '', /text\/plain/);
    const text = await res.text();
    assert.match(text, /infra_lab_backend_uptime_seconds/);
    assert.match(text, /infra_lab_backend_requests_total/);
  } finally {
    await app.close();
  }
});

test('GET /readyz → 503 when dependencies are unreachable', async () => {
  const { app, url } = await withServer();
  try {
    const res = await fetch(url('/readyz'));
    assert.strictEqual(res.status, 503);
    const body = await res.json();
    assert.strictEqual(body.ready, false);
    assert.strictEqual(body.checks.postgres, false);
    assert.strictEqual(body.checks.redis, false);
  } finally {
    await app.close();
  }
});
