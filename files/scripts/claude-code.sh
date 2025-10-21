#!/bin/bash
#
# Non-interactive script to download and install Claude Code CLI
# using the official installer from https://claude.ai/install.sh

set -e

# --- Configuration ---
INSTALL_URL="https://claude.ai/install.sh"

# --- Dependency Check ---
if ! command -v curl &>/dev/null; then
  echo "Error: This script requires 'curl' to be installed." >&2
  exit 1
fi

# --- Main Logic ---
echo "Installing Claude Code CLI..."

curl -fsSL "$INSTALL_URL" | bash

echo "Claude Code CLI has been installed successfully"

# Verify installation
if command -v claude &>/dev/null; then
  echo "Verification: $(claude --version)"
else
  echo "Warning: 'claude' command not found in PATH. You may need to restart your shell." >&2
fi
