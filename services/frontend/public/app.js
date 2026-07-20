'use strict';

/*
 * Infrastructure Lab — frontend status board.
 *
 * Fetches the backend endpoints through Caddy (same origin), proving the
 * proxy → backend wiring. Readiness returning 503 is a *valid* state — it
 * means a dependency is down — and is rendered distinctly from liveness.
 */

const set = (el, state, text) => {
  const pill = el.querySelector('.pill');
  pill.textContent = text;
  pill.dataset.state = state;
};

async function probe(path) {
  try {
    const r = await fetch(path, { cache: 'no-store' });
    return { ok: r.ok, status: r.status };
  } catch (e) {
    return { ok: false, status: 0, error: e.message };
  }
}

async function poll() {
  const live = document.getElementById('liveness');
  const ready = document.getElementById('readiness');
  const status = document.getElementById('status');
  const commit = document.getElementById('commit');

  const l = await probe('/healthz');
  set(live, l.ok ? 'ok' : 'down', l.ok ? 'ALIVE' : 'DOWN');

  const rd = await probe('/readyz');
  set(ready, rd.ok ? 'ok' : 'warn', rd.ok ? 'READY' : 'NOT READY');

  try {
    const r = await fetch('/api/status', { cache: 'no-store' });
    const body = await r.json();
    status.textContent = JSON.stringify(body, null, 2);
    commit.textContent = 'commit: ' + (body.commit || 'dev');
  } catch (e) {
    status.textContent = 'backend unreachable — ' + e.message;
    commit.textContent = 'commit: ?';
  }
}

poll();
setInterval(poll, 5000);
