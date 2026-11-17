FROM node:22-slim

# Install tools: Python, Git, and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    ripgrep \
    less \
    python3 \
    python-is-python3 \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd (web terminal)
RUN ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64) TTYD_ARCH="x86_64" ;; \
         arm64) TTYD_ARCH="aarch64" ;; \
         *) echo "Unsupported arch"; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}" -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# GitHub SSH host keys are supplied read-only at runtime via /home/agent/.ssh/known_hosts.
# Do not ssh-keyscan at build time: that is TOFU and not reproducible.

# Install OpenCode and DeepSeek Harness (CLI)
RUN npm install -g @opencode/cli dsh

# Create the user
RUN userdel -r node || true

RUN useradd -u 1000 -U -m -s /bin/bash agent

# Create the config and SSH directories, and give the agent user ownership (for volumes)
RUN mkdir -p /home/agent/.local/share/opencode /home/agent/.config /home/agent/.ssh \
    && chmod 700 /home/agent/.ssh \
    && chown -R agent:agent /home/agent

USER agent

WORKDIR /workspace

# Copy the entrypoint script

COPY --chown=agent:agent entrypoint.sh /home/agent/entrypoint.sh
RUN chmod +x /home/agent/entrypoint.sh

COPY --chown=agent:agent backends /agent/backends
RUN chmod +x /agent/backends/*.sh

ENTRYPOINT ["/home/agent/entrypoint.sh"]
