<!--
Thanks for opening a PR to Infrastructure Lab. Reviewers spend ~90 seconds here
too: keep this short and concrete.
-->

## Summary

<!-- One or two sentences: what changed and why. -->

## Motivation

<!-- The problem this solves. Link an issue if one exists. -->

## Type of change

- [ ] Bug fix / correctness — no behavior change for end users
- [ ] Architecture / docs / ADR — reference content
- [ ] Operational — scripts, compose, health, observability
- [ ] CI/CD — workflows and templates
- [ ] Breaking change — changes the documented contract (names, ports, env vars)

## Checklist

- [ ] `make lint` passes (shellcheck + `compose config` for all overlays)
- [ ] `make test` passes (backend suite)
- [ ] Stack boots: `make up && make ps` shows all services `(healthy)`
- [ ] Cross-links resolve and the [README file tree](../README.md#repository-structure) still matches reality
- [ ] If a setting was added/changed, it appears in `.env.example` **and** `docs/architecture/environment-variables.md`
- [ ] If a decision changed, the relevant ADR is added/updated and referenced

## Notes for reviewers

<!-- Anything non-obvious: trade-offs made, alternatives rejected, what NOT to review yet. -->
