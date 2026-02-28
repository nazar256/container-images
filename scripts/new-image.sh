#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <image_name>" >&2
  exit 1
fi

image_name="$1"

case "$image_name" in
  ""|*/*|.*)
    echo "Invalid image name: $image_name" >&2
    exit 1
    ;;
esac

image_dir="images/$image_name"
workflow_file=".github/workflows/build-$image_name.yml"
readme_file="README.md"

if [ -e "$image_dir" ] || [ -e "$workflow_file" ]; then
  echo "Image or workflow already exists for '$image_name'" >&2
  exit 1
fi

mkdir -p "$image_dir"
mkdir -p ".github/workflows"

cat > "$image_dir/Dockerfile" <<EOF
FROM alpine:3.20

CMD ["sh", "-c", "echo container-images $image_name"]
EOF

cat > "$image_dir/README.md" <<EOF
# $image_name image

Scaffolded image. Replace this content with real image documentation.

## Build locally

\`\`\`bash
docker build -t $image_name:local -f images/$image_name/Dockerfile images/$image_name
\`\`\`

## Run locally

\`\`\`bash
docker run --rm $image_name:local
\`\`\`

## Pull from GHCR

\`\`\`bash
docker pull ghcr.io/<owner>/$image_name:latest
\`\`\`

## Pull from Docker Hub

\`\`\`bash
docker pull <dockerhub-username>/<repo>-$image_name:latest
\`\`\`
EOF

cat > "$workflow_file" <<EOF
name: build $image_name

on:
  push:
    branches:
      - master
    paths:
      - images/$image_name/**
      - .github/workflows/build-$image_name.yml
      - .github/workflows/_reusable-build-and-push.yml

jobs:
  build:
    permissions:
      contents: read
      packages: write
    uses: ./.github/workflows/_reusable-build-and-push.yml
    secrets:
      DOCKERHUB_USERNAME: \${{ secrets.DOCKERHUB_USERNAME }}
      DOCKERHUB_TOKEN: \${{ secrets.DOCKERHUB_TOKEN }}
    with:
      image_name: $image_name
      context: images/$image_name
      dockerfile: images/$image_name/Dockerfile
EOF

if [ ! -f "$readme_file" ]; then
  echo "README.md not found; skipping image list update" >&2
  exit 0
fi

row="| \`$image_name\` | \`images/$image_name\` | \`docker build -t $image_name:local -f images/$image_name/Dockerfile images/$image_name\` | \`docker pull ghcr.io/<owner>/$image_name:latest\` | \`docker pull <dockerhub-username>/<repo>-$image_name:latest\` | \`docker run --rm ghcr.io/<owner>/$image_name:latest\` |"

if grep -Fq "$row" "$readme_file"; then
  echo "Scaffolded $image_name"
  exit 0
fi

tmp_file=$(mktemp)

awk -v row="$row" '
  /<!-- IMAGES-LIST:END -->/ && !inserted {
    print row
    inserted=1
  }
  { print }
' "$readme_file" > "$tmp_file"

mv "$tmp_file" "$readme_file"

echo "Scaffolded $image_name"
