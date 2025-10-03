# vim: set ft=make :
# Post-install setup commands for blueprint homeserver
# Copyright 2025 Thomas Mecattaf

# Decrypt age key from USB drive
decrypt-key:
    #!/usr/bin/bash
    echo "TODO: Implement age key decryption from USB"
    # USB_MOUNT="/run/media/$USER"
    # KEY_FILE=$(find "$USB_MOUNT" -name "age-key.encrypted" 2>/dev/null | head -n 1)
    # if [ -z "$KEY_FILE" ]; then
    #     echo "❌ Error: Encrypted age key not found on USB"
    #     exit 1
    # fi
    # TODO: Decrypt and place in ~/.config/chezmoi/key.txt

# Setup Tailscale using OAuth credentials from config file
setup-tailscale:
    #!/usr/bin/bash
    set -e
    
    CONFIG_FILE="$HOME/.config/tailscale/tailscale-oauth.conf"
    
    echo "=== Tailscale Auto-Setup with OAuth ==="
    echo
    
    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: Config file not found at $CONFIG_FILE"
        echo "Expected file to be created by chezmoi"
        exit 1
    fi
    
    echo "✓ Found config at: $CONFIG_FILE"
    
    # Source the OAuth credentials
    source "$CONFIG_FILE"
    
    if [ -z "$TAILSCALE_OAUTH_CLIENT_ID" ] || [ -z "$TAILSCALE_OAUTH_CLIENT_SECRET" ]; then
        echo "❌ Error: OAuth credentials not found in config file"
        echo "Make sure the file contains both TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET"
        exit 1
    fi
    
    echo "✓ OAuth credentials loaded"
    
    # Enable and start Tailscale service
    echo
    echo "Enabling Tailscale service..."
    sudo systemctl enable --now tailscaled
    echo "✓ Tailscale service started"
    
    # Generate fresh auth key using OAuth
    echo
    echo "Generating fresh auth key from OAuth credentials..."
    AUTH_KEY_RESPONSE=$(curl -s -X POST \
        "https://api.tailscale.com/api/v2/tailnet/-/keys" \
        -u "${TAILSCALE_OAUTH_CLIENT_ID}:${TAILSCALE_OAUTH_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{
            "capabilities": {
                "devices": {
                    "create": {
                        "reusable": false,
                        "ephemeral": false,
                        "preauthorized": true,
                        "tags": ["tag:blueprint"]
                    }
                }
            },
            "expirySeconds": 900
        }')
    
    # Extract the auth key from response
    AUTH_KEY=$(echo "$AUTH_KEY_RESPONSE" | jq -r '.key')
    
    if [ -z "$AUTH_KEY" ] || [ "$AUTH_KEY" = "null" ]; then
        echo "❌ Error: Failed to generate auth key"
        echo "Response: $AUTH_KEY_RESPONSE"
        exit 1
    fi
    
    echo "✓ Auth key generated successfully"
    
    # Authenticate with Tailscale
    echo
    echo "Authenticating with Tailscale..."
    sudo tailscale up --authkey="$AUTH_KEY" --accept-routes --accept-dns
    
    echo
    echo "=== Setup Complete! ==="
    echo
    tailscale status

# Setup GitHub CLI (interactive authentication)
setup-github:
    #!/usr/bin/bash
    echo "TODO: Implement GitHub CLI login"
    # gh auth login

# Run complete post-install setup (all steps)
setup-all:
    #!/usr/bin/bash
    set -e
    
    echo "=== Running Complete Post-Install Setup ==="
    echo
    
    # Step 1: Decrypt age key (if needed)
    # just decrypt-key
    
    # Step 2: Setup Tailscale
    echo "Step 1: Setting up Tailscale..."
    just setup-tailscale
    echo
    
    # Step 3: Setup GitHub CLI (if needed)
    # echo "Step 2: Setting up GitHub CLI..."
    # just setup-github
    # echo
    
    echo "=== All Setup Steps Complete! ==="
