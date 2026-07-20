# syntax=docker/dockerfile:1
# =============================================================================
# Frontend — static assets served by nginx (single stage).
# No build step: assets in `public/` are copied directly into the image.
#
# Listens on :80 (a privileged port). Non-root hardening is layered on by the
# prod overlay (docker-compose.prod.yml), which either rewrites the listen
# port to 8080 or grants CAP_NET_BIND_SERVICE — and mounts the tmpfs nginx
# needs because its root filesystem becomes read-only in prod. See
# docs/security/container-security.md.
# =============================================================================
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public /usr/share/nginx/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ || exit 1
