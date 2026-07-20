# Architecture

This directory holds the **diagrams-as-code** for Infrastructure Lab: the single source of truth for each architectural view. The [README](../README.md) and [docs/](../docs/) embed (render) these `.mmd` files inline; the `.mmd` sources are diffable and reviewable like any other code.

## Views

| File | View | Shows |
| --- | --- | --- |
| [`diagrams/system-overview.mmd`](diagrams/system-overview.mmd) | System overview | all components, the request path, observability, and delivery |
| [`diagrams/request-flow.mmd`](diagrams/request-flow.mmd) | Request flow | an end-to-end request with ports and routing rules |
| [`diagrams/cicd-flow.mmd`](diagrams/cicd-flow.mmd) | CI/CD flow | lint → test → build → scan → registry → deploy gate |
| [`diagrams/observability-flow.mmd`](diagrams/observability-flow.mmd) | Observability flow | scrape targets → Prometheus → dashboards & alerts |

## Rendering

The `.mmd` files are raw Mermaid graph definitions (no fences). Render to SVG/PNG with the Mermaid CLI for slides or static docs:

```bash
npx -y @mermaid-js/mermaid-cli -i diagrams/system-overview.mmd -o diagrams/system-overview.svg
```

In prose (`README.md`, documents under `docs/`), the same graph is wrapped in a ` ```mermaid ` fence so GitHub renders it inline. The `.mmd` source wins when the two drift.

## How this relates to the rest of the repo

Keep these three intents separate:

- **This directory** — what the system *is* (graph sources).
- [`docs/architecture/`](../docs/architecture/) — the *prose* that explains the graphs and the contracts behind them.
- [`docs/adr/`](../docs/adr/) — the *decisions* that produced this architecture.

## Conventions

- Node names and ports here must match the [locked conventions](../README.md) used by `compose/`, `.env.example`, and `docs/architecture/environment-variables.md`.
- Styling uses `classDef` blocks with a small, consistent palette (edge = blue, app = green, stateful = orange, observability = purple, delivery = teal). Reuse it across views so the four diagrams read as one system.

## See also

- [README — Architecture](../README.md#architecture)
- [docs/architecture/overview.md](../docs/architecture/overview.md)
- [docs/architecture/networking.md](../docs/architecture/networking.md)
