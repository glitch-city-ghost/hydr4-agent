# Architecture

## Topology
Windows host
└── NixOS WSL2 (l3rn4-nix)
    ├── mihomo (native, 127.0.0.1:7890)
    ├── Traefik (native/docker, external `traefik-net`)
    └── Docker network `agent-net`
        ├── gateway (FreeLLMAPI -> LiteLLM)
        └── agent (OpenCode)

## Traffic & Network
- **agent-net**: Standard bridge network (NOT internal). Agents need outbound internet for `git`, `npm`, and web search.
- **Gateway**: Routes LLM traffic through `mihomo` proxy. Because of WSL2 quirks, it uses `http://172.17.0.1:7890` (Tech Debt, see ADR-0003).
- **Agents**: Connect to the gateway via `http://gateway:3001/v1` using the OpenAI-compatible contract.
- **Traefik**: Handles ingress for `agent.localhost` (port 4096) and `api.localhost` (port 3001).

## Components
- **l3rn4-nix**: OS, Docker, mihomo, Traefik. Unaware of hydr4 internals.
- **gateway**: OpenAI-compatible proxy, provider failover. Must adhere to `docs/contracts/model-gateway.md`.
- **agent**: Interchangeable container. Must adhere to `docs/contracts/agent-seam.md`.

## Contracts
All interfaces between these components are strictly defined in the `docs/contracts/` directory.