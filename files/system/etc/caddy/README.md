# Caddy Configuration Directory

This directory contains system-wide Caddy configurations that are part of the BluePrint Linux image.

## Configuration Hierarchy

```
/etc/caddy/
├── Caddyfile                    # Base config (imports from both dirs)
└── conf.d/                      # System configs (this directory)
    ├── README.md                # This file
    └── *.caddy                  # System service configs (if any)

~/.config/caddy/                 # User configs (from dotfiles)
└── *.caddy                      # User service configs (templated by chezmoi)
```

## How It Works

1. **Base Caddyfile** (`/etc/caddy/Caddyfile`) imports from:
   - `/etc/caddy/conf.d/*.caddy` - System configs (immutable, from image)
   - `~/.config/caddy/*.caddy` - User configs (mutable, from dotfiles)

2. **User Path Detection**:
   - `caddy-setup.service` runs at boot
   - Detects primary user (UID 1000)
   - Writes `CADDY_USER_CONFIG` to `/etc/default/caddy`
   - Caddy service reads this environment variable

3. **Service Ordering**:
   ```
   boot → enable-linger.service
        ↓
        caddy-setup.service (detects user, writes config path)
        ↓
        tailscaled.service (network ready)
        ↓
        caddy.service (starts with user config path)
   ```

## Managing Configurations

### System Configs (This Directory)
- Immutable (part of image)
- Rarely used - most configs belong in user space
- Requires image rebuild to modify

### User Configs (~/.config/caddy/)
- Mutable (from dotfiles)
- Templated by chezmoi from `.chezmoi.yaml.tmpl`
- Each service gets its own `.caddy` file
- Reload: `sudo systemctl reload caddy`

## Example User Config

```caddy
# ~/.config/caddy/cockpit.caddy
cockpit.blueprint.tail8dd1.ts.net {
    reverse_proxy 127.0.0.1:9090 {
        header_up Connection {>Connection}
        header_up Upgrade {>Upgrade}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
}
```

## Tailscale Integration

Caddy is configured to:
- Start **after** Tailscale is ready
- Listen on Tailscale interface (100.x.x.x)
- Use MagicDNS hostnames (*.tail8dd1.ts.net)
- No public internet exposure

## Logs

- Access logs: `/var/log/caddy/access.log`
- System logs: `journalctl -u caddy.service`

## Manual Reload

After modifying configs in `~/.config/caddy/`:
```bash
sudo systemctl reload caddy
```

Caddy performs zero-downtime config reloads.
