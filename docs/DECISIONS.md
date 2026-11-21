# Decisions (Architectural Decision Records)

## ADR-001 — Gateway runs in Docker (Variant A)

**Status:** Accepted.

**Context:** Two options were proposed — Docker (A) or native systemd via a Nix module (B).

**Decision:** Variant A.

**Rationale:**
- `l3rn4-nix` explicitly does not want ownership of the gateway.
- Swapping gateways must not require `nix-rebuild`.
- Gateway is application logic, not infrastructure.
- Agents and gateway share one Docker network; no host-loopback ambiguity.
- Secrets live in `.env` (gitignored) for development, with a clear path to Docker secrets later.

**Consequences:**
- mihomo must accept connections from the Docker bridge (see prerequisites in README). It does so via `bind-address: "*"` + `allow-lan: true` in `l3rn4-nix/mihomo-config.yaml`.
- Gateway image pinning becomes part of the repo.

---

## ADR-002 — Resolving WSL2 Mirrored Network Issues

**Status:** Accepted.

**Context:** 
In WSL2 with `networkingMode=mirrored`, Docker's default `userland-proxy` conflicted with the host's NAT rules. This caused external POST requests (like those to the gateway) to be silently dropped or time out.

**Decision:**
Change the Docker daemon settings inside `l3rn4-nix`:

- keep `userland-proxy = true`, so port publishing does not rely on `iptables` DNAT alone;
- disable Docker's `iptables` management (`iptables = false`), so Docker does not install NAT/filter rules that clash with WSL2 mirrored mode.

This is what the host currently runs (`l3rn4-nix/modules/docker.nix`). It also means Docker does **not** firewall or rewrite traffic between bridge networks — containers can reach any address the host owns, as described in ADR-003.

**Consequences:**
- Host-to-container networking works reliably in mirrored mode.
- Docker does not manage `iptables`. Any packet filtering is the host's (Windows/`nftables`) responsibility.
- Network routing is documented in `l3rn4-nix` configuration.

---

## ADR-003 — Agent Network Access & Egress Proxy Address

**Status:** Accepted.

**Context:**
The code reviewer flagged two things: `agent-net` is not `internal: true`, and the egress proxy address is environment-specific.

Both have to be read together with how the host actually runs Docker (`l3rn4-nix/modules/docker.nix`):

- `iptables = false` — Docker does not manage `iptables` rules. This is required by WSL2 `networkingMode=mirrored`, whose NAT rules clash with Docker's.
- `userland-proxy = true` — the userland proxy is kept for port publishing.

With `iptables = false`, Docker does not filter or rewrite traffic between bridge networks and the host. A container can therefore reach any address the host owns, whichever Docker network that address belongs to. That is why "the address is the host and it must be the right network" is not a problem here.

**Decision:**

1. We keep standard bridge networking, so agents can run `git clone`, `npm install`, and web search.
2. The egress proxy address is **not hardcoded in this repository**. It is a host-specific value set in the root `.env` and passed to the gateway only:
   ```ini
   UPSTREAM_PROXY=http://172.17.0.1:7890
   ```
3. `172.17.0.1` is the `docker0` bridge address on this host. It is an example, not a requirement. Any host address that mihomo listens on works, because mihomo uses `bind-address: "*"` with `allow-lan: true`.
4. The agent never receives the proxy. It uses the host's mirrored network directly.

**Consequences:**
- Agents have full egress to the internet (bypassing mihomo for raw traffic).
- The setup is WSL2-specific. To mitigate key leakage, agents only receive `HYDRA_API_KEY` (gateway key), not the raw provider keys.
- Moving to a different host, or changing `docker0`'s subnet, requires editing `UPSTREAM_PROXY` in `.env` — nothing else changes.
- If mihomo ever stops binding `*`, `UPSTREAM_PROXY` must point at the interface mihomo actually binds.

---

## ADR-004 — UID/GID Alignment for Universal Agent Image

**Status:** Resolved.

**Context:**
The base image `node:22-slim` comes with a pre-existing `node` user that occupies UID 1000. Our Dockerfile originally created an `agent` user, which received UID 1001. However, the `compose.yaml` runs the container as `user: "1000:1000"`. This UID mismatch caused `Permission denied` errors when trying to write to volumes or bind mounts.

**Decision:**
Modify `docker/universal-agent/Dockerfile` to explicitly align the internal UID with the host:
1. Remove the default user: `RUN userdel -r node || true`
2. Create the `agent` user with explicit UID 1000: `RUN useradd -u 1000 -U -m -s /bin/bash agent`
3. Set ownership of home directories before switching users.

**Consequences:**
- Manual `chown` workarounds are no longer needed.
- Volumes and bind mounts created by Docker automatically inherit the correct UID 1000, matching the host user.
- The image is fully portable and works out-of-the-box on WSL2.

---

## ADR-005 — Centralized Data Storage (Bind Mounts instead of Named Volumes)

**Status:** Accepted.

**Context:**
Initially, the project used Docker Named Volumes (`agent-data`, `opencode-data`, etc.) for persistent storage. While convenient, it makes backups and data inspection difficult because the data is hidden inside Docker's system directories (`/var/lib/docker/volumes/`).

**Decision:**
Migrate all persistent storage to explicit **Bind Mounts** located in a centralized directory outside the Git repository: `~/hydr4-data/`.

**Structure:**
- `~/hydr4-data/gateway/` — FreeLLMAPI database.
- `~/hydr4-data/agent/config/` — Agent configurations (`.config`).
- `~/hydr4-data/agent/local-share/` — OpenCode chat history and sessions.
- `~/hydr4-data/secrets/` — (Future) SSH keys and sensitive tokens.

**Consequences:**
- **Pros:** Easy backups (just copy the folder), transparent data access, strict separation of code (Git) and state (Disk).
- **Cons:** Users must manually ensure the directory exists and has the correct UID/GID permissions (`1000:1000`).

## ADR-006 — External Traefik Gateway on l3rn4-nix

**Status:** Accepted. Amended 2026-11 (file provider, no Docker provider).

**Context:**
Initially, `hydr4-agent` ran its own Traefik instance to provide local domains. However, Traefik is an infrastructure gateway, not application logic.

**Decision:**
Migrate Traefik to the `l3rn4-nix` infrastructure layer. `hydr4-agent` joins the external `traefik-net` network and is reachable through it.

**Correction (2026-11):** The wording above used to say the services are declared via Docker labels. That is no longer true and was never true after the migration:

- `l3rn4-nix/modules/traefik.nix` disables the Docker provider entirely;
- Traefik uses the **file provider** only, with `--providers.file.directory=/etc/traefik/dynamic`;
- routes are declared by hand in `l3rn4-nix/traefik-dynamic/routes.yaml`, against container names and internal ports;
- Traefik has no access to `/var/run/docker.sock`, and there is no `docker-socket-proxy` container;
- `mihomo` is a **native host service** (systemd), not a container. Its dashboard is published through `host.docker.internal:9090` from `routes.yaml`.

Consequences for `hydr4-agent`:

- `traefik.*` labels in `compose/*.yaml` are inert. They document intent, nothing more.
- A new container is unreachable until an entry is added to `routes.yaml`.
- Renaming a service or a container requires a matching edit in `routes.yaml`. Otherwise ingress returns `502` while containers stay healthy.
- The `traefik-net` network itself is created by `l3rn4-nix` (`systemd.services.traefik-network`).

---

## ADR-007 — Gateway-native OpenCode configuration and role-based agents

**Status:** Accepted.

**Context:**
The first OpenCode setup only exposed one gateway model and left built-in
OpenAI/DeepSeek providers active through `OPENAI_API_KEY` and
`DEEPSEEK_API_KEY`. That mixed the gateway catalog with provider-catalog models
the gateway cannot serve, and it gave no project instructions, role separation,
or review/verification workflow. The result was a capable agent with a weak
operating contract.

**Decision:**
Configure OpenCode around the gateway contract rather than around a single
upstream provider:

1. Define one custom OpenAI-compatible provider, `hydr4`, at
   `http://gateway:3001/v1`, using `HYDRA_API_KEY`.
2. Hard-deny every other provider with `policies`, so the model picker only
   lists models the gateway can actually serve.
3. Do not export `OPENAI_API_KEY` or `DEEPSEEK_API_KEY` from the OpenCode
   backend. Only `HYDRA_API_KEY` reaches the agent.
4. Assign models by role: DeepSeek Flash for build/plan/explore/verification,
   Nemotron 3 Ultra 550B for independent review, and Fusion for a deliberate
   second opinion. `auto` remains a manual fallback; `fusion` is reserved for
   the oracle.
5. Add read-only `reviewer`, `verifier`, and `oracle` subagents, plus `/review`,
   `/review-fast`, `/verify`, `/oracle`, and `/handoff` commands.
6. Keep global instructions, skills, and the provider/model catalog with the
   mounted config in `configs/backends/opencode/`; keep repo-specific rules in
   the root `AGENTS.md`.

**Rationale:**
- The gateway is the stable interface; upstream provider IDs and keys are not.
- Hiding catalog models prevents confusing `Model unavailable` failures.
- A different model family for review reduces correlated blind spots.
- Read-only specialists make review and verification safe to run frequently.
- Project instructions are part of the configuration, not tribal knowledge.

**Consequences:**
- Gateway model IDs become part of the agent configuration. Re-check
  `GET /v1/models` when the gateway or its providers change.
- `auto` and `fusion` routing can change; do not depend on their exact upstream
  model in critical workflows.
- The agent has no direct-provider fallback. If the gateway is down, the agent
  is down; that is the intended failure mode, not a reason to add raw keys.
- Existing sessions keep their selected model after a config change; a new
  session is required to pick up the new default.
