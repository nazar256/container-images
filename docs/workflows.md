# Workflows

This repository uses a reusable workflow and one per-image workflow.

## Reusable workflow

File: `.github/workflows/_reusable-build-and-push.yml`

- Triggered by `workflow_call`.
- Inputs:
  - `image_name`
  - `context`
  - `dockerfile`
  - `platforms` (default: `linux/amd64,linux/arm64`)
- Steps:
  1. Checkout
  2. Login to `ghcr.io` using `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`
  3. Setup QEMU and Buildx
  4. Generate tags/labels with `docker/metadata-action`
  5. Build and push with `docker/build-push-action`

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

## Tags and labels

- `latest` for default branch (`master`).
- `sha-<short>` for immutable traceability.
- OCI labels include source and revision metadata.

## Job permissions

Workflows use:

- `contents: read`
- `packages: write`

This is required to push images with `GITHUB_TOKEN`.
