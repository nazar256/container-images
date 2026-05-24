# devbox image

Personal isolated remote development box base image.

Goals:

- Provide a stable Ubuntu userspace substrate.
- Keep mutable dev tooling in a persistent `/home/dev` (installed without root).
- Provide a simple in-container service manager via `supervisord`.

## Build locally

```bash
docker build -t devbox:local -f images/devbox/Dockerfile images/devbox
```

## Run with persistent home and workspace

```bash
docker run --rm -it \
  -v "$PWD/devbox-home:/home/dev" \
  -v "$PWD/projects:/workspace" \
  devbox:local
```

## Install tools (persist in /home/dev)

```bash
mise use -g node@22
mise use -g terraform@1
pipx install yamllint
npm install -g wrangler
```

Fast-moving tools (Node/Go/Terraform/Wrangler/etc.) are intentionally installed later into the persistent home via `mise`, `pipx`, `npm`, or one-line install scripts, rather than baked into the immutable image.

## Supervisord usage

The default container command starts `supervisord` in the foreground.
Add user-managed programs under:

- `/home/dev/.config/supervisor/conf.d/*.conf`

Then use:

```bash
supervisorctl status
supervisorctl reread
supervisorctl update
```

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/devbox:latest
```

## Pull from Docker Hub (optional)

```bash
docker pull <dockerhub-username>/devbox:latest
```

