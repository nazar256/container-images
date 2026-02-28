# Adding a new image

## 1) Generate scaffolding

```bash
./scripts/new-image.sh <image_name>
```

This creates:

- `images/<image_name>/Dockerfile`
- `images/<image_name>/README.md`
- `.github/workflows/build-<image_name>.yml`
- updated Images list in root `README.md`

The generated workflow always pushes to GHCR.
It also pushes to Docker Hub when these repository secrets are configured:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## 2) Implement the image

Edit `images/<image_name>/Dockerfile` for your runtime and packages.

## 3) Validate locally

```bash
docker build -t <image_name>:local -f images/<image_name>/Dockerfile images/<image_name>
docker run --rm <image_name>:local
```

## 4) Commit and push

On `push` to `master`, only the matching image workflow should run because of `paths` filters.

## 5) Verify published image names

- GHCR: `ghcr.io/<owner>/<image_name>`
- Docker Hub (optional): `<dockerhub-username>/<image_name>`
