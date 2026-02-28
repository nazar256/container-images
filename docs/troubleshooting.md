# Troubleshooting

## `denied: permission` when pushing to GHCR

- Confirm workflow job has `permissions: packages: write`.
- Confirm package/repository permissions are not restricted.

## Docker Hub login fails in workflow

- Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are present in repository secrets.
- Ensure the token is a Docker Hub access token (not account password).
- Recreate token if it was revoked.

## Authentication fails locally

- Re-run `docker login ghcr.io` with a valid token.
- For PAT, ensure scopes include `read:packages` (and `write:packages` if pushing).

## Wrong tags published

- Check `docker/metadata-action` tag rules in reusable workflow.
- Confirm branch is `master` for `latest` tag behavior.

## Docker Hub images are not pushed

- Docker Hub push is conditional. If secrets are missing, workflow will publish only to GHCR.
- Confirm expected target naming: `<dockerhub-username>/<repo>-<image_name>`.

## Multi-arch build errors

- Ensure QEMU and Buildx steps exist and run before build step.
- Some base images do not support both `amd64` and `arm64`; verify upstream support.

## Workflow did not run

- Verify the commit touched files allowed by workflow `paths`.
- Verify push target branch is exactly `master`.
