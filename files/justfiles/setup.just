# vim: set ft=make :
# Post-install setup commands for blueprint homeserver
# Copyright 2025 Thomas Mecattaf

# Decrypt age key from USB and apply chezmoi dotfiles
decrypt-and-apply:
    #!/usr/bin/bash
    set -e

    echo "🔑 Copying age key from USB and applying dotfiles..."

    USB_LABEL="SECRET-KEY"
    USB_MOUNT="/run/media/$USER/$USB_LABEL"
    KEY_SOURCE="$USB_MOUNT/age-key.txt"
    DEST_DIR="$HOME/.config/chezmoi"
    DEST_KEY="$DEST_DIR/key.txt"

    # Ensure destination directory exists
    mkdir -p "$DEST_DIR"

    # Check if USB is mounted
    if [ ! -d "$USB_MOUNT" ]; then
        echo "❌ USB drive '$USB_LABEL' not mounted at $USB_MOUNT"
        exit 1
    fi

    # Check if key file exists
    if [ ! -f "$KEY_SOURCE" ]; then
        echo "❌ No age-key.txt found on USB at $KEY_SOURCE"
        exit 1
    fi

    # Copy the key and set permissions
    cp "$KEY_SOURCE" "$DEST_KEY"
    chmod 600 "$DEST_KEY"
    echo "✅ Age key copied to $DEST_KEY"

    # Apply chezmoi dotfiles now that key is present
    if command -v chezmoi >/dev/null 2>&1; then
        echo "🗂 Applying chezmoi dotfiles..."
        chezmoi apply
        echo "✅ Dotfiles applied successfully"
    else
        echo "⚠️ chezmoi not installed — skipping dotfiles application"
    fi

# Setup GitHub CLI using GH_TOKEN from environment
setup-github:
    #!/usr/bin/bash
    set -e

    echo "=== GitHub CLI Setup ==="
    
    if ! command -v gh &> /dev/null; then
        echo "❌ GitHub CLI (gh) not installed"
        exit 1
    fi

    if [ -f "$HOME/.env" ]; then
        source "$HOME/.env"
    else
        echo "❌ Error: ~/.env not found"
        exit 1
    fi

    if [ -z "$GH_TOKEN" ]; then
        echo "❌ GH_TOKEN not set in environment"
        exit 1
    fi

    echo "$GH_TOKEN" | gh auth login --with-token
    gh auth status

    echo "=== GitHub CLI Setup Complete! ==="

# Run complete post-install setup (all steps)
setup-all:
    #!/usr/bin/bash
    set -e

    echo "=== Running Complete Post-Install Setup ==="
    
    echo "Step 1: Decrypting age key and applying dotfiles..."
    just decrypt-and-apply

    echo "Step 2: Setting up GitHub CLI..."
    just setup-github

    echo "=== All Setup Steps Complete! ==="
