FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie@sha256:b3c543b6c4f23a5f2df22866bd7857e5d304b67a564f4feab6ac22044dde719b AS uv_source
FROM tianon/gosu:1.19-trixie@sha256:3b176695959c71e123eb390d427efc665eeb561b1540e82679c15e992006b8b9 AS gosu_source
FROM debian:13.4

ENV PYTHONUNBUFFERED=1

COPY --chmod=0755 --from=gosu_source /gosu /usr/local/bin/
COPY --chmod=0755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential nodejs npm python3 ripgrep gcc python3-dev libffi-dev procps git && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -u 10000 -m -d /opt/data hermes

COPY . /opt/hermes
WORKDIR /opt/hermes

# Install Claude Code CLI globally (for Claude Max OAuth)
RUN npm install -g @anthropic-ai/claude-code && \
    npm cache clean --force && \
    rm -rf /root/.npm

# Install Python deps — telegram only, skip discord[voice]/slack/web
RUN chown -R hermes:hermes /opt/hermes
USER hermes
RUN uv venv && \
    uv pip install --no-cache-dir -e ".[cron,cli,pty,mcp,acp]" \
        "python-telegram-bot[webhooks]>=22.6,<23" \
        "aiohttp>=3.13.3,<4"

# Aggressive cleanup: purge build tools, clear caches
USER root
RUN apt-get purge -y build-essential gcc python3-dev libffi-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /root/.cache && \
    find /opt/hermes/.venv -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/hermes/.venv -name "*.pyc" -delete 2>/dev/null || true

RUN chmod +x /opt/hermes/docker/entrypoint.sh

ENV HERMES_HOME=/opt/data
ENV PATH="/opt/hermes/.venv/bin:${PATH}"
ENTRYPOINT [ "/opt/hermes/docker/entrypoint.sh" ]
CMD [ "gateway" ]
