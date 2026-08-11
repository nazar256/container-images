# Workflows

This repository uses a reusable workflow and one per-image workflow.

Publishing targets:

- GHCR (always)
- Docker Hub (optional, when secrets are configured)

## Reusable workflow

File: `.github/workflows/_reusable-build-and-push.yml`

- Triggered by `workflow_call`.
- Inputs:
  - `image_name`
  - `context`
  - `dockerfile`
  - `platforms` (default: `linux/amd64,linux/arm64`)
- Optional secrets:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`
- Steps:
  1. Checkout
  2. Login to `ghcr.io` using `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`
  3. Login to Docker Hub (only when Docker Hub secrets are present)
  4. Setup QEMU and Buildx
  5. Generate tags/labels with `docker/metadata-action`
  6. Build and push with `docker/build-push-action`

## Per-image workflow

File pattern: `.github/workflows/build-<image_name>.yml`

- Trigger:
  - `push`
  - `branches: [master]`
  - `paths` restricted to:
    - `images/<image_name>/**`
    - `.github/workflows/build-<image_name>.yml`
    - `.github/workflows/_reusable-build-and-push.yml`
- Job uses reusable workflow and passes image-specific input values.
- Job forwards optional Docker Hub secrets to reusable workflow.

## Tags and labels

- `latest` for default branch (`master`).
- `sha-<short>` for immutable traceability.
- OCI labels include source and revision metadata.

The same tag scheme is used for both GHCR and Docker Hub when Docker Hub is enabled.

## Upstream tool version policy

Builds deliberately float only dependencies whose compatibility risk is low
enough for this repository's smoke tests to manage:

- `mcpproxy-chatgpt` resolves the latest MCPProxy release for every CI build,
  and its Dockerfile does the same for local builds unless an exact
  `MCPPROXY_VERSION` is supplied.
- `chrome-devtools-mcp-proxy` selects the latest `mcp-proxy` 6.x and
  `chrome-devtools-mcp` 1.x releases. CI resolves each range once and reuses
  those exact versions for its smoke and publish builds.
- `openclaw-browser-node` tracks the latest Node.js 22 image. Remaining on the
  same LTS major version makes patch and minor runtime updates highly likely to
  remain compatible.

The following versions remain fixed because their backwards-compatibility
confidence is below the 85% threshold:

- `uv`, the OpenClaw CLI, and the opencode Telegram bot are pre-1.0 or do not
  offer a stable-major compatibility boundary suitable for unattended updates.
- The opencode Telegram bot image also replaces files inside the package's
  compiled `dist` tree, making an unattended package update especially risky.
- LinuxServer Chromium uses immutable, non-semver tags and the image relies on
  details of its launcher.
- The telegram transcription bot's Python packages are application runtime
  dependencies rather than interchangeable build tools; their major-version
  upgrades require source-level review.

## Job permissions

Workflows use:

- `contents: read`
- `packages: write`

This is required to push images with `GITHUB_TOKEN`.
