# System Design — Engineering Philosophy

> This is not documentation. It is a five-minute tour of *how I design systems* — the reasoning behind the choices in this repository, not a description of what's where. For structure, see the [README](README.md) and [docs/](docs/).

Each section answers a single "why." The answers are deliberately short and opinionated; the trade-offs they imply are made explicit in the [ADRs](docs/adr/).

---

## Why containerize?

Containers solve the *"works on my machine"* problem by making the *contract* between build and run explicit: a filesystem, a process, an environment, a port. That contract is the foundation every other practice in this repository depends on.

The deeper reason is **reproducibility of failure**. When a service behaves differently in staging than in production, the question should never be "is it the OS? the libraries? the config?" — because the answer is always "the image, or its inputs." Encoding the runtime into a versioned artifact collapses the search space. If it ran in CI, it runs on the host.

The cost is the abstraction itself: a layer of indirection between you and the kernel, and a packaging discipline you must actually maintain. The benefit — that the unit of deployment is identical across every environment — is worth it for anything more complex than a single script.

## Why a reverse proxy?

A reverse proxy is the *single point in the network where operational concerns live* — TLS, routing, rate limiting, gzip, timeouts, and access control — so that applications do not have to.

Without one, every service has to know how to terminate TLS, how to expire idle connections, how to shield itself from slow clients, and how to be discovered. With one, the service gets to be one thing: the thing that implements the business behavior. The proxy makes the application **dumber on purpose**, which means the application gets to be **smarter where it counts**.

Caddy, specifically, is chosen here because its defaults are honest: it issues and renews certificates without ceremony, and its configuration is short enough to read in one screen. A reverse proxy whose configuration you cannot hold in your head has already failed at its one job.

## Why health checks — and why two of them?

There are two questions, and they are not the same:

- **Liveness**: "Is this process alive at all?" If no, *restart me.*
- **Readiness**: "Am I currently able to serve traffic?" If no, *stop sending me traffic*, but don't necessarily restart me.

Conflating them is a classic, expensive mistake. A backend that can't reach its database is not *dead* — restarting it will not bring the database back, and a rolling restart can cascade into an outage as every replica restarts at once. Readiness removes the pod from the rotation; liveness restarts it. They describe different failure modes and demand different responses.

This is why the backend exposes `/healthz` (the process answered) and `/readyz` (the process answered *and* its dependencies are reachable). Deployment bring-up and rollback both hinge on the second, not the first. See [docs/operations/health-checks.md](docs/operations/health-checks.md).

## Why graceful shutdown?

When a process is told to stop, in-flight work should finish, the database connection pool should drain, and the port should close *before* the container exits. A forced kill mid-request yields half-written rows, dangling connections, and 502s that look, to the user, exactly like a real outage.

Graceful shutdown is the contract that makes rolling updates safe: the scheduler sends `SIGTERM`, the process stops accepting new work, finishes the old work within a deadline, and then exits. The implementation here is small — trap the signal, close the server, await the pool — but the effect is that a deployment does not drop traffic. It is the difference between a restart and an incident.

## Why observability?

You cannot operate what you cannot see, and "seeing" is not a single sense. *Metrics* tell you what is happening in aggregate; *logs* tell you what happened to a specific request; *traces* (out of scope here, but the obvious next step) tell you what happened *across* services for one request.

The non-negotiable idea is **instrumentation as code**: dashboards are provisioned, alert rules are versioned, scrape targets are declared. The moment a dashboard becomes a manual import, your monitoring drifts from your system. A few months in, nobody can tell whether the panel reflects the current architecture or the one from two services ago. Declaring it — and reviewing the declaration in pull requests — is the only way to keep observability honest.

The choice of Prometheus and Grafana is a consequence of the **pull model**: the system knows what to scrape; services don't have to know where to ship. Pair it with a recording-rule layer that pre-computes SLO indicators, and alerting becomes "this indicator crossed a threshold," not "this raw query feels alarming."

## Why configuration as environment?

Twelve-factor got this right: configuration varies by environment, code does not, so configuration belongs in the *environment*, not in the artifact. The same image runs in dev and prod; only the inputs differ.

`.env` files are the lowest-friction expression of this idea — and that's why they're used *here*, in a single-host reference. They are emphatically *not* the end of the road. The moment configuration contains real secrets at scale, `.env` gives way to SOPS, Vault, or a secrets manager, and the `.env` key becomes a pointer rather than the source of truth. The ADR names that upgrade explicitly; the repository is structured so the swap is local, not architectural. See [docs/security/secrets-management.md](docs/security/secrets-management.md).

## Why immutable deployments?

"Deploy" should mean *swap the artifact*, not *mutate the running system*. The alternative — reaching into a live machine and editing config — produces a state nobody can reproduce and an outage nobody can explain.

Immutability has three parts here. **Build once**: CI produces a tagged image; the host pulls that tag, it does not build. **Promote, don't rebuild**: the image that passed tests is the image that runs — there is no second build step between environments. **Replace, don't patch**: rolling out means starting new containers and stopping old ones, not `apt-get`'ing a production host. The consequence is that any running system is described exactly by a commit plus a tag; debugging becomes "what did that image contain," and the answer is in git.

## Why infrastructure as code?

Because the system's *desired state* should be reviewable, diffable, and reconstructable from a repository — not the tail memory of the last person to SSH in.

Compose is a deliberately lightweight expression of IaC, and that's the point of using it here: the entire system — services, volumes, networks, limits, health — is a few declarative files you can read end to end. The discipline those files install scales upward: the moment you outgrow a single host, the same mindset moves to Terraform for provisioning and Kubernetes for orchestration, and nothing about *how you think* has to change — only the tool. That continuity is the real value, and it's why this repository treats Compose as the first rung of a ladder rather than a destination. See [Future evolution](README.md#future-evolution).

---

## How these compose

Each of these ideas is cheap on its own and load-bearing in combination. Containers make the artifact portable; the reverse proxy makes the application dumb; liveness/readiness split makes traffic control honest; graceful shutdown makes rotation safe; observability makes the system legible; environment-based config makes one artifact run anywhere; immutability makes any running system reconstructable; IaC makes the whole thing reviewable. Remove any one and the rest get measurably harder.

This repository is what those beliefs look like when written down as a single, runnable blueprint.
