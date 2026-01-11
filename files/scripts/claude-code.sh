#!/usr/bin/env bash
#
# Install Claude Code CLI system-wide for BlueBuild (x86_64 only)

set -euo pipefail

# Fetch official installer and extract GCS bucket URL
INSTALLER=$(curl -fsSL https://claude.ai/install.sh)
GCS_BUCKET=$(echo "$INSTALLER" | grep 'GCS_BUCKET=' | cut -d'"' -f2)

if [[ -z "$GCS_BUCKET" ]]; then
  echo "Error: Could not extract GCS bucket URL from installer" >&2
  exit 1
fi

VERSION=$(curl -fsSL "$GCS_BUCKET/latest")

curl -fsSL -o /usr/local/bin/claude "$GCS_BUCKET/$VERSION/linux-x64/claude"
chmod +x /usr/local/bin/claude

echo "Claude Code $VERSION installed"
