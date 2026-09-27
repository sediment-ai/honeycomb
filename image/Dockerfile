# Fleet agent image: pi harness (pi + pi-acp), sediment capture stack,
# git/gh/uv toolchain.
FROM ghcr.io/block/buzz-sprig:main AS sprig

FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      git python3 python3-venv curl ca-certificates procps \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @earendil-works/pi-coding-agent@0.84.1 pi-acp@0.0.33 \
    && npm cache clean --force
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.97.0/gh_2.97.0_linux_arm64.tar.gz \
    | tar -xz -C /usr/local --strip-components=1 gh_2.97.0_linux_arm64/bin/gh
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
COPY --from=sprig /usr/local/bin/sprig /usr/local/bin/sprig
RUN for n in buzz-acp buzz-agent buzz-dev-mcp rg tree buzz git-credential-nostr git-sign-nostr; do \
      ln -sf sprig "/usr/local/bin/$n"; done \
    && git config --system gpg.format x509 \
    && git config --system gpg.x509.program /usr/local/bin/git-sign-nostr \
    && git config --system commit.gpgSign true \
    && git config --system credential."https://github.com".helper /usr/local/bin/git-credential-github-env \
    && mkdir -p /home/agent && chown -R 10001:10001 /home/agent
COPY sediment_attribution.py sediment_transcript.py config.json derive_pubkey.py /opt/sediment/
COPY shims/pi/ /opt/sediment/shims/pi/
# Header injection: the shim's lazy pi-ai import resolves through this
# symlink to pi's OWN vendored copy — same instance, same api registry, no
# duplicate install. If upstream ever unvendors it, the shim degrades
# gracefully (unstamped requests + console trail), it does not break.
RUN mkdir -p /opt/sediment/shims/pi/node_modules/@earendil-works \
    && ln -s /usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai \
      /opt/sediment/shims/pi/node_modules/@earendil-works/pi-ai
COPY --chmod=0755 entrypoint.sh /usr/local/bin/agent-entrypoint
COPY --chmod=0755 git-credential-github-env /usr/local/bin/git-credential-github-env
RUN chmod -R a+rX /opt/sediment
ENV HOME=/home/agent
# The capture scripts ride HOME (EmptyDir seed in the entrypoint), so the
# shim's script lookup and the stamper's shim registration both resolve
# against HOME: SEDIMENT_SCRIPT_DIR for the shim → $HOME/.sediment, and
# _pi_extension_dir() from $HOME/.sediment/... → $HOME/shims/pi (seeded).
ENV SEDIMENT_SCRIPT_DIR=/home/agent/.sediment
WORKDIR /home/agent
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/agent-entrypoint"]
