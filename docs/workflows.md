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

## Job permissions

Workflows use:

- `contents: read`
- `packages: write`

This is required to push images with `GITHUB_TOKEN`.
