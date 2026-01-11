#!/usr/bin/env bash
#
# Install Claude Code CLI system-wide for BlueBuild (x86_64 only)

set -euo pipefail

GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

VERSION=$(curl -fsSL "$GCS_BUCKET/latest")

curl -fsSL -o /usr/local/bin/claude "$GCS_BUCKET/$VERSION/linux-x64/claude"
chmod +x /usr/local/bin/claude

echo "Claude Code $VERSION installed"
