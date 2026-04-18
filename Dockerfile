FROM ghcr.io/astral-sh/uv:0.11.6-python3.13-trixie@sha256:b3c543b6c4f23a5f2df22866bd7857e5d304b67a564f4feab6ac22044dde719b AS uv_source
FROM tianon/gosu:1.19-trixie@sha256:3b176695959c71e123eb390d427efc665eeb561b1540e82679c15e992006b8b9 AS gosu_source
FROM debian:13.4

ENV PYTHONUNBUFFERED=1

COPY --chmod=0755 --from=gosu_source /gosu /usr/local/bin/
COPY --chmod=0755 --from=uv_source /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/

# Install system deps + build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential nodejs npm python3 ripgrep gcc python3-dev libffi-dev procps git && \
    rm -rf /var/lib/apt/lists/*

# Non-root user
RUN useradd -u 10000 -m -d /opt/data hermes

COPY . /opt/hermes
WORKDIR /opt/hermes

# Install Node deps + Claude Code CLI
RUN npm install --prefer-offline --no-audit && \
    npm cache clean --force
RUN npm install -g @anthropic-ai/claude-code

# Install Python deps then purge build tools to save space
RUN chown -R hermes:hermes /opt/hermes
USER hermes
RUN uv venv && \
    uv pip install --no-cache-dir -e ".[messaging,cron,cli,pty,mcp,acp,web]"

USER root
RUN apt-get purge -y build-essential gcc python3-dev libffi-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /opt/hermes/docker/entrypoint.sh

ENV HERMES_HOME=/opt/data
ENTRYPOINT [ "/opt/hermes/docker/entrypoint.sh" ]
