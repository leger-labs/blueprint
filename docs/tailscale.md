## Step 0: Create Tailscale Account and Enable MagicDNS
First create a few tailscale account (recommend: using github account)
Then in Tailscale admin console:
- Go to DNS settings (usually the bottom of the admin console)
- Enable MagicDNS
- Enable HTTPS Certificates (this is key!)

Make note of your tailnet name; should look like `tail8dd1.ts.net`; you will need to set this in chezmoi dotfiles repo `.chezmoi.yaml.tmpl` in data/tailscale/tailnet.

## Step 1: Create a Tag in Your ACL

Go to [Tailscale Admin Console](https://login.tailscale.com/admin/acls/file) → **Access Controls**

Add this to your ACL:
```json
{
  "tagOwners": {
    "tag:blueprint": ["autogroup:admin"]
  }
}
```

Click **Save**.

---

## Step 2: Create an OAuth Client

1. Go to **Settings** → **OAuth clients** in the [admin console](https://login.tailscale.com/admin/settings/oauth)
2. Click **Generate OAuth client**
3. Configure:
   - **Description**: "Fedora Workstation Reinstalls"
   - **Scopes**: Select **"auth_keys"** (read & write)
   - **Tags**: Select `tag:blueprint`
4. Click **Generate**
5. **CRITICAL**: Copy both values immediately:
   - **OAuth Client ID**: `tskey-oauth-xxxxxx`
   - **OAuth Client Secret**: `tskey-api-xxxxxx`

---

## Step 3: Save Credentials to USB

Create a file on your USB:

```bash
# Save to USB as tailscale-oauth.conf
TAILSCALE_OAUTH_CLIENT_ID="tskey-oauth-xxxxxx"
TAILSCALE_OAUTH_CLIENT_SECRET="tskey-api-xxxxxx"
```

**This file never expires!**

---

## Step 4: Use This Enhanced Script

```
#!/bin/bash

# Tailscale Auto-Setup with OAuth (Never-Expiring Credentials)
# Save this on your USB drive along with tailscale-oauth.conf

set -e  # Exit on error

USB_MOUNT="/run/media/$USER"  # Adjust if your USB mounts elsewhere
OAUTH_CONFIG_FILE="tailscale-oauth.conf"

echo "=== Tailscale Auto-Setup with OAuth ==="
echo

# Find the OAuth config file on USB
echo "Looking for OAuth credentials on USB drive..."
CONFIG_PATH=$(find "$USB_MOUNT" -name "$OAUTH_CONFIG_FILE" 2>/dev/null | head -n 1)

if [ -z "$CONFIG_PATH" ]; then
    echo "❌ Error: Could not find $OAUTH_CONFIG_FILE on USB drive"
    echo "Please ensure your USB drive is mounted and contains the OAuth config file"
    exit 1
fi

echo "✓ Found OAuth config at: $CONFIG_PATH"

# Source the OAuth credentials
source "$CONFIG_PATH"

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

# Generate a fresh auth key using OAuth
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
```

## Step 5: Usage After Each Fresh Install

**What you keep on your USB:**
- `tailscale-oauth.conf` (never expires!)
- `tailscale-setup.sh` (the script above)

**After each fresh Fedora install:**

```bash
# Insert USB and run:
chmod +x /path/to/usb/tailscale-setup.sh
/path/to/usb/tailscale-setup.sh
```
