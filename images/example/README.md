# example image

Simple demonstration image for this repository.

## Build locally

```bash
docker build -t example:local -f images/example/Dockerfile images/example
```

## Run locally

```bash
docker run --rm example:local
```

## Pull from GHCR

```bash
docker pull ghcr.io/<owner>/<repo>-example:latest
```

## Run from GHCR

```bash
docker run --rm ghcr.io/<owner>/<repo>-example:latest
```
