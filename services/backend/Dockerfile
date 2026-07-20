# syntax=docker/dockerfile:1
# =============================================================================
# Backend API — Node.js / Fastify
# Multi-stage: install dependencies in a builder, run from a slim image.
# Reference priorities: small attack surface, non-root user, writable tmp
# via tmpfs (the prod overlay sets read_only: true), healthcheck, graceful
# shutdown handled in app code (SIGTERM-aware).
# =============================================================================

# --- Builder: install production dependencies -------------------------------
FROM node:20-alpine AS builder
WORKDIR /app

# Copy the manifest first for layer caching.
COPY package.json ./
# NOTE: no package-lock.json is committed in this reference. `npm install`
# resolves versions here. For real use, commit a lockfile and switch to
# `npm ci` for reproducible, verified installs.
RUN npm install --omit=dev --no-audit --no-fund

# --- Runtime: slim image, non-root ------------------------------------------
FROM node:20-alpine AS runtime
ENV NODE_ENV=production

WORKDIR /app

# Non-root user; /app/tmp is the only writable path needed (prod overlay
# mounts a tmpfs there when read_only is enabled).
RUN addgroup -S app && adduser -S app -G app \
 && mkdir -p /app/tmp && chown -R app:app /app

COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY test ./test

USER app
EXPOSE 8080

# Healthcheck uses wget (busybox) against the configured listen port.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${BACKEND_PORT:-8080}/healthz" || exit 1

CMD ["node", "src/server.js"]
