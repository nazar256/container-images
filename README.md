# container-images

Monorepo for building and publishing multiple Docker images to GitHub Container Registry (GHCR), with optional mirror push to Docker Hub.

## What is in this repository

- Docker images live under `images/<image_name>/`.
- Each image has its own GitHub Actions workflow in `.github/workflows/build-<image_name>.yml`.
- Every per-image workflow runs only on `push` to `master` and only when files for that image changed.
- A reusable workflow handles shared GHCR build/push logic.

## Quick start

Build one image locally:

```bash
docker build -t my-image:local -f images/<image_name>/Dockerfile images/<image_name>
```

Run locally:

```bash
docker run --rm my-image:local
```

Example image in this repository:

```bash
docker build -t example:local -f images/example/Dockerfile images/example
docker run --rm example:local
```

## CI and publishing

- Trigger: `push` to `master`.
- Scope: per-image `paths` filters (`images/<image_name>/**`).
- Publishing target format (GHCR):

  `ghcr.io/<owner>/<repo>-<image_name>`

- Optional Docker Hub target format:

  `<dockerhub-username>/<repo>-<image_name>`

- Tags:
  - `latest` (only on default branch `master`)
  - `sha-<short>`

- Docker Hub push is enabled only when repository secrets are set:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

See details in `docs/workflows.md` and `docs/registry-ghcr.md`.

## Images

<!-- IMAGES-LIST:START -->
| Image | Path | Build locally | Pull from GHCR | Pull from Docker Hub | Run |
| --- | --- | --- | --- | --- | --- |
| `example` | `images/example` | `docker build -t example:local -f images/example/Dockerfile images/example` | `docker pull ghcr.io/<owner>/<repo>-example:latest` | `docker pull <dockerhub-username>/<repo>-example:latest` | `docker run --rm ghcr.io/<owner>/<repo>-example:latest` |
<!-- IMAGES-LIST:END -->
