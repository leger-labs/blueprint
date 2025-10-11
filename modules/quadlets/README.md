# `quadlets`

The quadlets module manages Podman Quadlet deployments with staged updates, backup/restore capabilities, and advanced validation features.

## Features

- **Staged Updates**: Download and preview quadlet updates before applying them
- **Backup & Restore**: Automatic backups with full volume support and point-in-time restore
- **Enhanced Validation**: Dependency analysis, conflict detection, and security warnings
- **Git-Based Sources**: Install quadlets from Git repositories (GitHub, GitLab, etc.)
- **External Management**: Support for locally-managed quadlets (chezmoi, manual editing)
- **Automatic Updates**: Configurable auto-updates for both quadlet definitions and container images
- **CLI Management**: Comprehensive command-line tool with 20+ commands

## How It Works

### Build-Time

The module downloads quadlets from specified Git sources and prepares them for installation:

1. Clones Git repositories and extracts quadlet directories
2. Validates quadlet file syntax, dependencies, and detects conflicts
3. Generates configuration file at `/usr/share/bluebuild/quadlets/configuration.yaml`
4. Sets up systemd services and timers for auto-updates
5. Installs enhanced scripts for staged updates and backup/restore

### Run-Time

On first boot and periodically thereafter:

1. **Initial Setup**: Copies quadlets from build-time locations to runtime directories
   - User scope: `~/.config/containers/systemd/`
   - System scope: `/etc/containers/systemd/`
2. **Discovery**: Finds externally-managed quadlets (e.g., from chezmoi)
3. **Systemd Integration**: Reloads daemon and starts quadlet services
4. **Auto-Updates**: Periodically checks Git sources for updates and pulls new container images

## Quick Start

### 1. Add to Your Recipe

```yaml
modules:
  - type: quadlets
    configurations:
      - name: ai-stack
        source: https://github.com/rgolangh/podman-quadlets/tree/main/ai-stack
        scope: user
        notify: true
```

### 2. Build Your Image

```bash
bluebuild build -r recipe.yml
```

### 3. Install/Rebase

```bash
# For Silverblue/Kinoite
rpm-ostree rebase ostree-unverified-registry:ghcr.io/username/image:latest
systemctl reboot
```

### 4. Use Enhanced Features

After reboot, use the staged update workflow for safer updates:

```bash
# Stage updates for preview
bluebuild-quadlets-manager stage all

# Review what changed
bluebuild-quadlets-manager diff ai-stack

# Apply the update
bluebuild-quadlets-manager apply ai-stack

# Or discard if not ready
bluebuild-quadlets-manager discard ai-stack
```

## Configuration

### Basic Example

```yaml
type: quadlets
configurations:
  - name: ai-stack
    source: https://github.com/rgolangh/podman-quadlets/tree/main/ai-stack
    scope: user
    notify: true
```

### Externally-Managed (Chezmoi/Secrets)

```yaml
type: quadlets
configurations:
  - name: openwebui
    source: ~/.config/containers/systemd/openwebui
    scope: user
    managed-externally: true
    setup-delay: 10m  # Wait for manual secret decryption
```

### Full Configuration Options

```yaml
type: quadlets

configurations:
  - name: my-app
    source: https://github.com/org/repo/tree/branch/path
    scope: user              # "user" or "system" (default: user)
    branch: main             # Git branch (default: main)
    notify: true             # Desktop notifications (default: true)
    managed-externally: false # Don't copy, only discover (default: false)
    setup-delay: 5m          # Delay before discovery (default: 5m)

# Quadlet definition updates
auto-update:
  enabled: true              # Enable auto-updates (default: true)
  interval: 7d               # Update check interval (default: 7d)
  wait-after-boot: 5m        # Delay after boot (default: 5m)

# Container image updates (Podman auto-update)
container-auto-update:
  enabled: true              # Enable container updates (default: true)
  interval: daily            # Update interval: daily, weekly, monthly (default: daily)
```

## Enhanced Features

### Staged Updates

Download and validate updates without applying them immediately:

```bash
# Stage updates
bluebuild-quadlets-manager stage all

# List staged updates
bluebuild-quadlets-manager staged

# Preview changes
bluebuild-quadlets-manager diff ai-stack

# Apply or discard
bluebuild-quadlets-manager apply ai-stack
bluebuild-quadlets-manager discard ai-stack
```

**Benefits:**
- See exactly what will change before applying
- Test updates in a safe preview environment
- Discard unwanted updates easily
- No impact on running services until you apply

### Backup & Restore

Automatic backups before applying updates, with full volume support:

```bash
# Manual backup
bluebuild-quadlets-manager backup ai-stack

# List backups
bluebuild-quadlets-manager backups ai-stack

# Restore from backup
bluebuild-quadlets-manager restore ai-stack
bluebuild-quadlets-manager restore ai-stack 20241010-120000  # Specific backup
```

**Features:**
- Automatic backup before apply
- Volume data included in backups
- Point-in-time restore capability
- Multiple backup retention

### Enhanced Validation

Advanced validation with dependency analysis and conflict detection:

```bash
# Validate a quadlet
bluebuild-quadlets-manager validate ai-stack

# Check for conflicts
bluebuild-quadlets-manager check-conflicts ai-stack
```

**Checks performed:**
- Syntax validation for all quadlet types
- Dependency parsing and circular dependency detection
- Port conflict detection (checks running services)
- Volume conflict detection
- Security context warnings
- Deprecated option warnings

### Detailed Inspection

Get comprehensive information about your quadlets:

```bash
# Inspect a quadlet
bluebuild-quadlets-manager inspect ai-stack
```

**Shows:**
- All services and their status
- Published ports
- Mounted volumes
- Networks
- Dependencies
- Resource usage

## CLI Management

The module installs `bluebuild-quadlets-manager` with comprehensive commands:

### Information Commands

```bash
bluebuild-quadlets-manager show              # Show configured quadlets
bluebuild-quadlets-manager list              # List installed quadlets
bluebuild-quadlets-manager status <name>     # Service status
bluebuild-quadlets-manager logs <name>       # View logs
bluebuild-quadlets-manager inspect <name>    # Detailed analysis
```

### Update Commands

```bash
# Staged updates (recommended)
bluebuild-quadlets-manager stage [name|all]     # Stage updates
bluebuild-quadlets-manager staged               # List staged
bluebuild-quadlets-manager diff <name>          # Preview changes
bluebuild-quadlets-manager apply [name|all]     # Apply staged
bluebuild-quadlets-manager discard [name|all]   # Discard staged

# Direct updates (legacy)
bluebuild-quadlets-manager update [name|all]    # Direct update
```

### Backup & Restore

```bash
bluebuild-quadlets-manager backup [name|all]    # Create backup
bluebuild-quadlets-manager backups [name]       # List backups
bluebuild-quadlets-manager restore <name> [id]  # Restore from backup
```

### Management

```bash
bluebuild-quadlets-manager discover                 # Find external quadlets
bluebuild-quadlets-manager validate <name>          # Validate config
bluebuild-quadlets-manager check-conflicts [name]   # Check conflicts
bluebuild-quadlets-manager enable updates           # Enable auto-updates
bluebuild-quadlets-manager disable updates          # Disable auto-updates
```

## Workflows

### Production Update Workflow (Recommended)

```bash
# 1. Stage updates
bluebuild-quadlets-manager stage all

# 2. Review what's staged
bluebuild-quadlets-manager staged

# 3. Preview changes
bluebuild-quadlets-manager diff ai-stack

# 4. Backup before applying (optional, but recommended)
bluebuild-quadlets-manager backup ai-stack

# 5. Apply the update
bluebuild-quadlets-manager apply ai-stack

# 6. Verify it's working
bluebuild-quadlets-manager status ai-stack

# If something went wrong, restore
bluebuild-quadlets-manager restore ai-stack
```

### Development Update Workflow (Fast)

```bash
# Direct update
bluebuild-quadlets-manager update ai-stack

# Check status
bluebuild-quadlets-manager status ai-stack
```

### Batch Update Workflow

```bash
# Stage everything
bluebuild-quadlets-manager stage all

# Review each service
for service in ai-stack monitoring nextcloud; do
    bluebuild-quadlets-manager diff $service
done

# Apply selectively
bluebuild-quadlets-manager apply ai-stack
bluebuild-quadlets-manager apply monitoring
bluebuild-quadlets-manager discard nextcloud  # Not ready yet
```

## Scope: User vs System

### User Scope (`scope: user`)
- Installs to `~/.config/containers/systemd/`
- Runs as the user
- Services start on user login
- No root privileges required for management
- Ideal for personal services and development

### System Scope (`scope: system`)
- Installs to `/etc/containers/systemd/`
- Runs as root
- Services start at system boot
- Requires root for management
- Ideal for system-wide services and multi-user setups

## Integration with Secrets Management

For quadlets that require secrets (API keys, passwords, etc.), see the [Secrets Management Guide](./examples/secrets-management.md) and [Chezmoi Integration Guide](./examples/chezmoi-integration.md).

The `managed-externally` flag allows you to:
1. Manage quadlet files with your secrets workflow (chezmoi, ansible, etc.)
2. Have the module discover and manage the systemd integration
3. Still receive updates if you specify a Git source for reference

## Directory Structure

```
# Build-time locations
/usr/share/bluebuild/quadlets/
├── configuration.yaml              # Module configuration
├── quadlet-validator.nu            # Enhanced validator
├── staged-updates.nu               # Staged updates manager
└── git-source-parser.nu            # Git download helper

/usr/libexec/bluebuild/quadlets/
├── user-quadlets-setup             # Setup scripts
├── user-quadlets-update
├── system-quadlets-setup
└── system-quadlets-update

# Runtime locations
/var/lib/bluebuild/quadlets/
├── staged/                         # Staged updates preview area
├── backups/                        # Full backups with volumes
└── manifests/                      # Staging metadata

# User scope (runtime)
~/.config/containers/systemd/
└── <quadlet-name>/
    ├── *.container
    └── *.volume

# System scope (runtime)
/etc/containers/systemd/
└── <quadlet-name>/
    ├── *.container
    └── *.volume
```

## Troubleshooting

### Quadlets not starting

```bash
# Check systemd status
systemctl --user status quadlet-name.service

# View logs
journalctl --user -u quadlet-name.service

# Validate quadlet syntax
bluebuild-quadlets-manager validate quadlet-name
```

### Updates not working

```bash
# Check timer status
systemctl --user status user-quadlets-update.timer

# Manually trigger update
bluebuild-quadlets-manager update all

# Check update logs
journalctl --user -u user-quadlets-update.service
```

### Port conflicts

```bash
# Check for conflicts
bluebuild-quadlets-manager check-conflicts ai-stack

# Find what's using a port
ss -tlnp | grep <port>
```

### Staged updates not showing

```bash
# List staged updates
bluebuild-quadlets-manager staged

# Check staging directory
ls -la /var/lib/bluebuild/quadlets/staged/
```

### Restore fails

```bash
# List available backups
bluebuild-quadlets-manager backups ai-stack

# Check backup directory
ls -la /var/lib/bluebuild/quadlets/backups/ai-stack/
```

## Resources

- [Podman Quadlet Documentation](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Podman Auto-Update](https://docs.podman.io/en/latest/markdown/podman-auto-update.1.html)
- [Quadlet Examples Repository](https://github.com/rgolangh/podman-quadlets)
- [Chezmoi Integration Guide](./examples/chezmoi-integration.md)
- [Secrets Management Guide](./examples/secrets-management.md)
- [Testing Guide](./TESTING.md)
- [Quick Reference](./QUICK-REFERENCE.md)

## Getting Help

- **Examples**: Check [examples/](./examples/) directory
- **Testing**: See [TESTING.md](./TESTING.md) to verify installation
- **Issues**: Report bugs on GitHub
- **Community**: Ask questions on BlueBuild Discord
