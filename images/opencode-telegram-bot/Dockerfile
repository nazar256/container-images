# syntax=docker/dockerfile:1

FROM node:20-alpine

# Pin package version at build time; do not use floating latest.
ARG BOT_VERSION=0.9.2

ENV HOME=/home/node \
    XDG_CONFIG_HOME=/home/node/.config \
    NODE_ENV=production

WORKDIR /home/node

RUN apk add --no-cache ca-certificates \
    && npm install -g --no-audit --no-fund @grinev/opencode-telegram-bot@${BOT_VERSION} \
    && opencode-telegram --help >/dev/null \
    && mkdir -p /home/node/.config/opencode-telegram-bot \
    && chown -R node:node /home/node

USER node

# In Docker Swarm run replicas=1 to avoid duplicate long-polling updates.
CMD ["opencode-telegram", "start"]
