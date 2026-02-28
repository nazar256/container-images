# GHCR notes

GitHub Container Registry (GHCR) stores OCI-compatible container images under `ghcr.io`.

## Naming used in this repository

Images are published as:

`ghcr.io/<owner>/<repo>-<image_name>`

Example:

`ghcr.io/ynazarenko/container-images-example`

## Where to find packages in GitHub UI

1. Open your repository on GitHub.
2. In the right sidebar, open **Packages**.
3. Click the package name (for example, `container-images-example`).

You can also open the owner-level packages page:

`https://github.com/users/<owner>/packages`

## Public vs private visibility

- By default, package visibility can be private.
- Open package settings and change visibility to public if needed.
- Ensure repository/package permissions allow pull access as intended.

## Authentication

For local pulls from private packages, authenticate Docker.

Option 1 (GitHub CLI):

```bash
gh auth token | docker login ghcr.io -u <github-username> --password-stdin
```

Option 2 (PAT with `read:packages`):

```bash
echo "<pat>" | docker login ghcr.io -u <github-username> --password-stdin
```

## Optional Docker Hub mirror

This repository can also push the same image tags to Docker Hub.

Configure repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

When these secrets are absent, workflows publish only to GHCR.
