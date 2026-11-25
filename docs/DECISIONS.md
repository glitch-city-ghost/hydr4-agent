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
- `~/hydr4-data/secrets/` — mounted credentials (SSH keys, tokens, and the like). Which ones exist is operator configuration; see ADR-007.

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

## ADR-007 — Git and GitHub access are operator configuration

**Status:** Accepted. Supersedes the credential and Git-workflow claims previously made in README § Zero-Trust Security Model, `docs/contracts/host.md`, and `docs/contracts/agent-seam.md`.

**Context:**
The earlier docs prescribed one deployment shape: a dedicated bot account, an SSH-only key, no PAT, pushes only to the bot's fork, and a human opening every pull request. That is a valid shape, but it is not a property of the container. It became wrong as soon as the agent worked in a clone of the primary repository, used its own GitHub account as a collaborator with branch-protection limits, or needed `gh` to open PRs. Writing a policy into the architecture docs makes the docs lie about what the image enforces and prevents operators from choosing a stricter or looser workflow.

**Decision:**
The repository owns the mechanism, not the Git workflow:

- the image carries tools, not credentials;
- credentials are supplied by the host as read-only mounts or environment variables;
- the operator decides which account, which key or token, which permissions, which remotes, and whether the agent may push, open PRs, or merge;
- docs may show the currently wired mounts as examples, with the blast radius, but must not claim that the image guarantees a fork-only, SSH-only, or PAT-free workflow;
- enforcement belongs to GitHub (account permissions, collaborator role, branch protection) and to the agent configuration (permissions, skills), not to prose.

**Consequences:**
- "No PAT in the container" is no longer an invariant. "No credential in the image or the repository" is.
- The operator must scope mounted credentials, protect `~/hydr4-data/secrets/`, and rotate them. `./hydra check` cannot verify GitHub permissions.
- Permission rules and prompt rules are guardrails, not a sandbox: the real boundary is what the credential can do.
- Changes to Git/GitHub integration do not require editing the architecture contract; they are configuration plus, at most, a tool mounted in the image.

---

## ADR-008 — GitHub CLI in the agent image

**Status:** Accepted.

**Context:**
Opening a pull request is a GitHub API operation, not a git operation. `git push` uploads refs; the
PR, its body, reviews, and CI results live on the platform. The agent already has an SSH key for the
data plane. Adding pull requests means adding a separate client for the control plane.

Alternatives considered:

- **GitHub MCP server.** Same API plus a large tool surface, another process, and a second auth path.
  Rejected for this scope.
- **Hand-written `curl` calls to the REST API.** More parsing and error handling in the model, less
  deterministic. Rejected.
- **Host-side `gh` only.** The agent has no access to the host. Rejected.
- **GitHub App installation tokens.** Correct for multi-tenant or short-lived credentials, but adds
  a private key, JWT signing, and a token-refresh helper. Kept as a future option if PAT policy or
  rotation becomes a problem.

**Decision:**
Ship the official GitHub CLI (`gh`) in `docker/universal-agent`, pinned by `ARG GH_VERSION` and
verified against the release checksum. Authenticate it only from an optional read-only token file
mounted at `/home/agent/.secrets/github/token` and exported as `GH_TOKEN` by `entrypoint.sh`.

- No token is baked into the image or written to the repository.
- `gh` is a GitHub API client. Git commit and push remain on the SSH key; `gh auth setup-git` is not
  called, and the existing removal of `credential.helper` stays.
- The token's scope is operator configuration, not an image invariant (ADR-007). The repository
  documents a minimal scope, but does not enforce account model, remotes, or review policy.
- Merge stays a human action. Tool permissions deny `gh pr merge` and `gh pr review`; GitHub branch
  protection is the actual boundary.
- A missing or rejected token must not prevent the container from starting. It disables gh operations
  and logs a warning.

**Consequences:**
- The agent can create and update PRs directly, without a human writing the title or body.
- Two credentials live in the same container: an SSH key with git write access and a GitHub token with
  API access. Compromise of the agent exposes both; scope and lifetime limit the token, branch
  protection limits the repository.
- Fine-grained PATs do not expose a `Checks` permission. `gh pr checks` may be unable to read check
  runs with such a token; classic `repo` or `public_repo` works. The skill must verify this per token
  and fall back to `gh run` output.
- Token rotation is manual: replace the file and recreate the container. Expiry is deliberate.
