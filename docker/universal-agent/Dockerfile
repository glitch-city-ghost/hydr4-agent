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

# Install the GitHub CLI (gh).
# gh is a GitHub API client, not a replacement for git: pushes still go over SSH.
# The image contains no credentials. A token is mounted at runtime and exported by
# entrypoint.sh, or gh runs unauthenticated.
ARG GH_VERSION=2.105.0
RUN ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64|arm64) ;; \
         *) echo "Unsupported arch"; exit 1 ;; \
       esac \
    && TARBALL="gh_${GH_VERSION}_linux_${ARCH}.tar.gz" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${TARBALL}" -o "/tmp/${TARBALL}" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" -o /tmp/gh-checksums.txt \
    && (cd /tmp && grep " ${TARBALL}$" gh-checksums.txt | sha256sum -c -) \
    && tar -xzf "/tmp/${TARBALL}" -C /tmp \
    && install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/gh \
    && gh --version \
    && rm -rf "/tmp/gh_${GH_VERSION}_linux_${ARCH}" "/tmp/${TARBALL}" /tmp/gh-checksums.txt

# GitHub SSH host keys are supplied read-only at runtime via /home/agent/.ssh/known_hosts.
# Do not ssh-keyscan at build time: that is TOFU and not reproducible.

# Install OpenCode, DeepSeek Harness (CLI), and dynamic workflows plugin
# The postinstall verifies the binary by running `opencode --version` as root,
# which leaves root-owned scratch files in /tmp. Drop them in the same layer.
RUN npm install -g @opencode/cli dsh opencode-dynamic-workflows \
    && rm -rf /tmp/opencode /tmp/.bun-* /tmp/node-compile-cache

# Create the user
RUN userdel -r node || true

RUN useradd -u 1000 -U -m -s /bin/bash agent

# OpenCode prefers /tmp/opencode for scratch files; create it for the runtime user.
RUN install -d -o agent -g agent -m 755 /tmp/opencode

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
