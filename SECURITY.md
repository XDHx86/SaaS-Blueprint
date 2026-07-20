# Security Policy

## Supported versions

| Version | Supported | Notes |
| --- | --- | --- |
| 0.x | best-effort | This is a reference architecture, not a production product. |

See [CHANGELOG.md](CHANGELOG.md) for the current release.

## Reporting a vulnerability

**Do not open a public issue for a security report.**

Email a report to **security@example.com** (replace with your contact when adopting this blueprint) including:

- A description of the issue and its impact.
- Minimal steps to reproduce (or a proof of concept).
- The affected file(s) / overlay / commit.
- Any suggested remediation.

We aim to:

1. Acknowledge receipt within **2 business days**.
2. Provide an initial assessment within **5 business days**.
3. Coordinate a fix and disclosure timeline with you.

## Scope

This repository is a **reference architecture**, not a production deployment. Reports are valuable when they concern:

- Insecure **defaults in a template** that a reader may copy into production (e.g., an open port, a permissive setting left in the base compose file).
- Broken **hardening** in the production overlay (`docker-compose.prod.yml`).
- A script or ADR that documents a practice which is actively unsafe.

Not in scope:

- Vulnerabilities in **upstream images** (nginx, node, caddy, postgres, redis, prometheus, grafana, alpine). Report those to the respective project.
- Issues arising from a reader's **own customization** that contradicts the documented posture (see [docs/security/](docs/security/)).

## Coordinated disclosure

Once a fix is available, we coordinate publication of the report and the fix so users can patch before details become public. Credit is given to reporters who request it.

## Security posture

The intended posture — least privilege, TLS at the edge, secrets from the environment, container hardening — is documented in [docs/security/](docs/security/), and the production overlay is the reference implementation of it: read-only root filesystems, dropped capabilities, no-new-privileges, non-root users, and no host-published datastores.
