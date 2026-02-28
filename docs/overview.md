# Repository overview

`container-images` is a monorepo for Docker image definitions and GHCR publishing automation.

## Layout

- `images/<image_name>/` — Dockerfile and docs for each image.
- `.github/workflows/_reusable-build-and-push.yml` — shared GHCR build/push job.
- `.github/workflows/build-<image_name>.yml` — image-specific trigger + reusable workflow call.
- `scripts/new-image.sh` — scaffold a new image and workflow.
- `scripts/list-images.sh` — list currently defined images.

## Core principles

1. One image per directory.
2. One workflow per image.
3. Workflow runs only when its image (or related workflow config) changes.
4. Publish to GHCR using the repository `GITHUB_TOKEN`.
