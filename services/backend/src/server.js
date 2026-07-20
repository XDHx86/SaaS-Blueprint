'use strict';

/**
 * Infrastructure Lab — backend reference service (Fastify).
 *
 * Endpoints:
 *   GET /healthz    — liveness  (the process answered)
 *   GET /readyz     — readiness (Postgres + Redis reachable)
 *   GET /api/status — JSON status rendered by the frontend
 *   GET /metrics    — Prometheus exposition (text/plain)
 *
 * Signals: traps SIGTERM/SIGINT, drains in-flight requests, closes the DB
 * pool and Redis client, and exits within SHUTDOWN_TIMEOUT_MS — the contract
 * that makes rolling updates safe. See docs/operations/health-checks.md for
 * the liveness/readiness distinction.
 *
 * Testable: `build()` returns an unbOLTered app (no listeners, no signal
 * handlers) so `node --test` can spin it up on an ephemeral port. `start()`
 * is the entrypoint for `npm start`.
 */

const Fastify = require('fastify');
const pg = require('pg');
const redis = require('redis');

// --- Configuration (12-factor: from the environment) ----------------------
const config = {
  port: parseInt(process.env.BACKEND_PORT || '8080', 10),
  shutdownTimeoutMs: parseInt(process.env.SHUTDOWN_TIMEOUT_MS || '10000', 10),
  postgres: {
    host: process.env.POSTGRES_HOST || 'postgres',
    port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
    user: process.env.POSTGRES_USER || 'infra',
    password: process.env.POSTGRES_PASSWORD || '',
    database: process.env.POSTGRES_DB || 'appdb',
  },
  redis: {
    host: process.env.REDIS_HOST || 'redis',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
  },
};

/**
 * Construct the Fastify app — routes, hooks, and an onClose handler that
 * tears down the Postgres pool and Redis client. Pure: does NOT listen and
 * does NOT register signal handlers (those belong to `start()`).
 */
function build() {
  const startedAt = Date.now();
  let requestCount = 0;

  const server = Fastify({
    logger: { level: process.env.LOG_LEVEL || 'info' },
  });

  // --- Clients -----------------------------------------------------------
  const pgPool = new pg.Pool({
    host: config.postgres.host,
    port: config.postgres.port,
    user: config.postgres.user,
    password: config.postgres.password,
    database: config.postgres.database,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  const redisClient = redis.createClient({
    socket: {
      host: config.redis.host,
      port: config.redis.port,
      // Recover automatically once the dependency comes back; readiness
      // reports the live state on each scrape rather than chasing it.
      reconnectStrategy: (retries) => Math.min(retries * 50, 1000),
    },
    password: config.redis.password,
  });
  redisClient.on('error', (err) => {
    // Cache errors must not take down the API; readiness reports the state.
    server.log.warn({ err: err.message }, 'redis client error');
  });

  // Light request counter for /metrics — no metrics client library required.
  server.addHook('onRequest', async () => { requestCount += 1; });

  // --- Liveness: the process answered. ----------------------------------
  server.get('/healthz', async () => ({
    status: 'ok',
    uptime_s: (Date.now() - startedAt) / 1000,
  }));

  // --- Readiness: alive AND dependencies are reachable. -----------------
  server.get('/readyz', async (_req, reply) => {
    const checks = { postgres: false, redis: false };

    try {
      await pgPool.query('SELECT 1');
      checks.postgres = true;
    } catch { checks.postgres = false; }

    if (redisClient.isOpen) {
      try { checks.redis = (await redisClient.ping()) === 'PONG'; }
      catch { checks.redis = false; }
    }

    const ready = checks.postgres && checks.redis;
    reply.code(ready ? 200 : 503);
    return { ready, checks };
  });

  // --- Application status, rendered by the frontend. -------------------
  server.get('/api/status', async () => ({
    service: 'infra-lab-backend',
    commit: process.env.COMMIT_SHA || 'dev',
    uptime_s: (Date.now() - startedAt) / 1000,
    requests: requestCount,
    dependencies: {
      postgres: { host: config.postgres.host, port: config.postgres.port },
      redis: { host: config.redis.host, port: config.redis.port },
    },
  }));

  // --- Minimal Prometheus exposition (pull model). ---------------------
  server.get('/metrics', async (_req, reply) => {
    reply.type('text/plain; version=0.0.4; charset=utf-8');
    const uptime = (Date.now() - startedAt) / 1000;
    const commit = process.env.COMMIT_SHA || 'dev';
    return [
      '# HELP infra_lab_backend_uptime_seconds Process uptime in seconds.',
      '# TYPE infra_lab_backend_uptime_seconds gauge',
      `infra_lab_backend_uptime_seconds ${uptime.toFixed(3)}`,
      '# HELP infra_lab_backend_requests_total Total HTTP requests received.',
      '# TYPE infra_lab_backend_requests_total counter',
      `infra_lab_backend_requests_total ${requestCount}`,
      '# HELP infra_lab_backend_info Backend build metadata.',
      '# TYPE infra_lab_backend_info gauge',
      `infra_lab_backend_info{commit="${commit}"} 1`,
      '',
    ].join('\n');
  });

  // --- Graceful teardown, invoked by app.close() -----------------------
  server.addHook('onClose', async () => {
    try { if (redisClient.isOpen) await redisClient.quit(); } catch { /* best effort */ }
    try { await pgPool.end(); } catch { /* best effort */ }
  });

  server.decorate('pgPool', pgPool);
  server.decorate('redisClient', redisClient);

  return server;
}

/**
 * Entry point for `npm start`: listen immediately, then connect Redis in the
 * background (non-blocking) so a slow cache never blocks the health endpoint.
 */
async function start() {
  const server = build();

  try {
    await server.listen({ port: config.port, host: '0.0.0.0' });
    server.log.info({ port: config.port }, 'backend listening');
  } catch (err) {
    server.log.error({ err: err.message }, 'startup failed');
    process.exit(1);
  }

  // Background connect — readiness reflects it; never blocks serving.
  server.redisClient.connect().catch((err) => {
    server.log.warn({ err: err.message }, 'redis connect failed (readiness will report down)');
  });

  const shutdown = async (signal) => {
    server.log.info({ signal }, 'received termination signal, draining in-flight requests');
    const hardExit = setTimeout(() => {
      server.log.error('graceful shutdown timed out, forcing exit');
      process.exit(1);
    }, config.shutdownTimeoutMs).unref();

    try {
      await server.close(); // drains in-flight, runs onClose (ends pools)
    } catch (e) {
      server.log.error({ err: e.message }, 'error during shutdown');
    }
    clearTimeout(hardExit);
    server.log.info('shutdown complete');
    process.exit(0);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

// Direct invocation (`npm start`). Tests import `build()` instead.
if (require.main === module) {
  start();
}

module.exports = { build, config };
