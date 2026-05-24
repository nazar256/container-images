FROM ubuntu:24.04

ARG DEV_UID=1000
ARG DEV_GID=1000

ENV HOME=/home/dev \
    WORKDIR=/workspace

RUN bash -o pipefail -ceu '\
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      wget \
      git \
      openssh-client \
      gnupg \
      unzip \
      zip \
      tar \
      xz-utils \
      jq \
      ripgrep \
      fd-find \
      less \
      vim-tiny \
      tmux \
      procps \
      htop \
      tini \
      supervisor \
      build-essential \
      pkg-config \
      cmake \
      make \
      clang \
      python3 \
      python3-venv \
      python3-pip \
      pipx \
      libssl-dev \
      libsqlite3-dev \
      zlib1g-dev; \
    rm -rf /var/lib/apt/lists/*; \
  '

RUN bash -o pipefail -ceu '\
    if [ "${DEV_UID}" = "0" ] || [ "${DEV_GID}" = "0" ]; then echo "DEV_UID/DEV_GID must be non-root" >&2; exit 1; fi; \
    if getent group "${DEV_GID}" >/dev/null; then :; else groupadd --gid "${DEV_GID}" dev; fi; \
    existing_by_uid="$(getent passwd "${DEV_UID}" | cut -d: -f1 || true)"; \
    existing_dev_uid="$(getent passwd dev | cut -d: -f3 || true)"; \
    if [ -n "${existing_dev_uid}" ] && [ "${existing_dev_uid}" != "${DEV_UID}" ]; then echo "User dev already exists with uid ${existing_dev_uid}, expected ${DEV_UID}" >&2; exit 1; fi; \
    if [ -n "${existing_by_uid}" ] && [ "${existing_by_uid}" != "dev" ]; then usermod -l dev "${existing_by_uid}"; fi; \
    if id dev >/dev/null 2>&1; then \
      usermod --uid "${DEV_UID}" --gid "${DEV_GID}" --home /home/dev --move-home --shell /bin/bash dev; \
    else \
      useradd --uid "${DEV_UID}" --gid "${DEV_GID}" --create-home --home-dir /home/dev --shell /bin/bash dev; \
    fi; \
    mkdir -p /workspace; \
    chown -R "${DEV_UID}:${DEV_GID}" /home/dev /workspace; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
  '

COPY --chown=root:root rootfs/ /

RUN bash -o pipefail -ceu '\
    chmod 0755 /usr/local/bin/start-devbox /usr/local/bin/ensure-mise; \
  '

WORKDIR /workspace
USER dev

CMD ["tini","--","/usr/local/bin/start-devbox"]
