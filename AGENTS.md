# AGENTS

Rules for automation agents working in this repository.

## Repository conventions

- Keep the monorepo layout: each image in `images/<image_name>/`.
- Use one workflow per image in `.github/workflows/build-<image_name>.yml`.
- Keep the reusable workflow in `.github/workflows/_reusable-build-and-push.yml`.

## Adding or changing images

- Prefer `./scripts/new-image.sh <image_name>` for new image scaffolding.
- If adding files manually, mirror the same generated structure and naming.
- Do not introduce nested GHCR names; keep image names as `<repo>-<image_name>`.

## CI safety rules

- Do not change branch trigger from `master` in per-image workflows.
- Do not remove `paths` filters from per-image workflows.
- Always include these paths in each per-image workflow:
  - `images/<image_name>/**`
  - `.github/workflows/build-<image_name>.yml`
  - `.github/workflows/_reusable-build-and-push.yml`
- If reusable workflow changes, ensure every image workflow still references it in `paths`.

## Local validation (mandatory)

- Use only Podman for local image validation in this repository.
- After changing image code, Dockerfiles, scripts, or workflows, run local tests before finishing work.
- Preferred command: `make local-test` (or `make local-test IMAGE=<image_name>` for targeted checks).
- Treat local test failures as blocking and fix them before finalizing changes.

## Commit style

- Make small, logical commits.
- Use clear conventional prefixes (`chore:`, `docs:`, `ci:`, `feat:`).
- Keep repository buildable and understandable after every commit.
