# hydr4-agent Roadmap & Deferred Work

Этот файл фиксирует архитектурные улучшения, которые мы осознанно отложили.

## 🚀 Upcoming & Deferred Work

### 1. Migrate Gateway to LiteLLM
- **Status:** In Progress
- **Context:** FreeLLMAPI handles 429 errors poorly. LiteLLM supports `Retry-After` and fallbacks.
- **Goal:** Replace FreeLLMAPI image with LiteLLM + Postgres. Update `.env` and contracts accordingly.

### 2. Implement Agent Seam (AGENT_BACKEND)
- **Status:** Pending
- **Context:** Currently, OpenCode is baked into the Dockerfile.
- **Goal:** Follow `contracts/agent-seam.md`. Create `/configs/backends/opencode/` and generic `entrypoint.sh`.

### 3. Harden Agent Filesystem (`read_only: true`)
- **Status:** Pending
- **Context:** The container's root FS is currently writable.
- **Goal:** Add `read_only: true` in `compose/agents.yaml`, mount `tmpfs` for `/tmp`.

### 4. Add DSH as an Alternative Agent
- **Status:** Pending
- **Context:** Our architecture allows running different agents.
- **Goal:** Implement `dsh` backend following the agent seam contract.

### 5. Monitoring and Observability
- **Status:** Pending
- **Context:** We only have Docker logs and the gateway dashboard.
- **Goal:** Deploy Prometheus + Grafana for LLM latency and token metrics.