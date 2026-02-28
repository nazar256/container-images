# Troubleshooting

## `denied: permission` when pushing to GHCR

- Confirm workflow job has `permissions: packages: write`.
- Confirm package/repository permissions are not restricted.

## Authentication fails locally

- Re-run `docker login ghcr.io` with a valid token.
- For PAT, ensure scopes include `read:packages` (and `write:packages` if pushing).

## Wrong tags published

- Check `docker/metadata-action` tag rules in reusable workflow.
- Confirm branch is `master` for `latest` tag behavior.

## Multi-arch build errors

- Ensure QEMU and Buildx steps exist and run before build step.
- Some base images do not support both `amd64` and `arm64`; verify upstream support.

## Workflow did not run

- Verify the commit touched files allowed by workflow `paths`.
- Verify push target branch is exactly `master`.
