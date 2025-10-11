# Quadlets Module - Quick Reference Card

## 🚀 Quick Start

```bash
# View configured quadlets
bluebuild-quadlets-manager show

# Safe update workflow (RECOMMENDED)
bluebuild-quadlets-manager stage all         # Download updates
bluebuild-quadlets-manager diff ai-stack     # Preview changes
bluebuild-quadlets-manager apply ai-stack    # Apply if good

# Or discard if not ready
bluebuild-quadlets-manager discard ai-stack
```

## 📖 Command Reference

### Information Commands

| Command | Description | Example |
|---------|-------------|---------|
| `show` | Show all configured quadlets | `bluebuild-quadlets-manager show` |
| `list` | List installed with status | `bluebuild-quadlets-manager list` |
| `inspect <n>` | Detailed analysis | `bluebuild-quadlets-manager inspect ai-stack` |
| `status <n>` | Service status | `bluebuild-quadlets-manager status ai-stack` |
| `logs <n>` | View logs | `bluebuild-quadlets-manager logs ai-stack --lines 100` |

### Staged Updates (New Feature)

| Command | Description | Example |
|---------|-------------|---------|
| `stage [name\|all]` | Download without applying | `bluebuild-quadlets-manager stage all` |
| `staged` | List staged updates | `bluebuild-quadlets-manager staged` |
| `diff <n>` | Preview changes | `bluebuild-quadlets-manager diff ai-stack` |
| `apply [name\|all]` | Apply staged updates | `bluebuild-quadlets-manager apply ai-stack` |
| `discard [name\|all]` | Discard staged | `bluebuild-quadlets-manager discard all` |

### Backup & Restore (New Feature)

| Command | Description | Example |
|---------|-------------|---------|
| `backup [name\|all]` | Create backup | `bluebuild-quadlets-manager backup all` |
| `backups [name]` | List backups | `bluebuild-quadlets-manager backups ai-stack` |
| `restore <n> [id]` | Restore from backup | `bluebuild-quadlets-manager restore ai-stack` |

### Management

| Command | Description | Example |
|---------|-------------|---------|
| `discover` | Find external quadlets | `bluebuild-quadlets-manager discover` |
| `validate <n>` | Validate config | `bluebuild-quadlets-manager validate ai-stack` |
| `check-conflicts [name]` | Check conflicts | `bluebuild-quadlets-manager check-conflicts` |
| `enable updates` | Enable auto-updates | `bluebuild-quadlets-manager enable updates` |
| `disable updates` | Disable auto-updates | `bluebuild-quadlets-manager disable updates` |
| `update [name\|all]` | Direct update (legacy) | `bluebuild-quadlets-manager update all` |

## 📊 Workflows

### Workflow 1: Safe Production Update

```
┌─────────┐
│  Stage  │  Download and validate updates
└────┬────┘
     │
     ▼
┌─────────┐
│  List   │  See what's staged
└────┬────┘
     │
     ▼
┌─────────┐
│  Diff   │  Preview exact changes
└────┬────┘
     │
     ├─→ Not good? ──→ Discard ──→ Done
     │
     ▼ Looks good
┌─────────┐
│ Backup  │  Create safety net
└────┬────┘
     │
     ▼
┌─────────┐
│  Apply  │  Apply changes (auto-backs up again)
└────┬────┘
     │
     ├─→ Works? ──→ Done! 🎉
     │
     ▼ Broken?
┌─────────┐
│ Restore │  Roll back to previous version
└─────────┘
```

### Workflow 2: Quick Development Update

```
┌─────────┐
│ Update  │  Direct update
└────┬────┘
     │
     ▼
┌─────────┐
│ Status  │  Check if working
└─────────┘
```

### Workflow 3: Disaster Recovery

```
┌─────────┐
│ Backups │  List available backups
└────┬────┘
     │
     ▼
┌─────────┐
│ Restore │  Restore to previous state
└────┬────┘
     │
     ▼
┌─────────┐
│ Status  │  Verify services running
└─────────┘
```

## 🎯 Use Cases

### Use Case: Stage All Updates Weekly

```bash
# Monday morning routine
bluebuild-quadlets-manager stage all
bluebuild-quadlets-manager staged  # Review what's available
```

### Use Case: Careful Production Update

```bash
# For critical service
bluebuild-quadlets-manager stage openwebui
bluebuild-quadlets-manager diff openwebui      # Review changes
bluebuild-quadlets-manager backup openwebui    # Safety first
bluebuild-quadlets-manager apply openwebui     # Apply
bluebuild-quadlets-manager status openwebui    # Verify
```

### Use Case: Bulk Update with Review

```bash
# Stage everything
bluebuild-quadlets-manager stage all

# Review each one
bluebuild-quadlets-manager diff ai-stack
bluebuild-quadlets-manager diff monitoring
bluebuild-quadlets-manager diff nextcloud

# Apply selectively
bluebuild-quadlets-manager apply ai-stack
bluebuild-quadlets-manager apply monitoring
bluebuild-quadlets-manager discard nextcloud  # Not ready
```

### Use Case: Emergency Rollback

```bash
# Service broken after update
bluebuild-quadlets-manager backups ai-stack
bluebuild-quadlets-manager restore ai-stack 20241010-120000
```

## 🔧 Configuration Snippets

### Git-Sourced Quadlet

```yaml
- name: ai-stack
  source: https://github.com/org/repo/tree/main/ai-stack
  scope: user
  branch: main
  notify: true
```

### Externally-Managed (Secrets)

```yaml
- name: openwebui
  source: ~/.config/containers/systemd/openwebui
  scope: user
  managed-externally: true
  setup-delay: 10m
```

### System-Wide Service

```yaml
- name: monitoring
  source: https://github.com/org/repo/tree/main/monitoring
  scope: system
  notify: false
```

## 📁 Important Paths

### Configuration
- `/usr/share/bluebuild/quadlets/configuration.yaml` - Module config
- `/usr/bin/bluebuild-quadlets-manager` - CLI tool

### Runtime (User)
- `~/.config/containers/systemd/<n>/` - Active quadlets

### Runtime (System)
- `/etc/containers/systemd/<n>/` - Active quadlets

### Enhanced Features
- `/var/lib/bluebuild/quadlets/staged/` - Staged updates
- `/var/lib/bluebuild/quadlets/backups/` - Backups with volumes
- `/var/lib/bluebuild/quadlets/manifests/` - Metadata

## 🚨 Troubleshooting Quick Fixes

### Problem: Service won't start

```bash
bluebuild-quadlets-manager status <n>
bluebuild-quadlets-manager logs <n>
bluebuild-quadlets-manager validate <n>
```

### Problem: Port conflict

```bash
bluebuild-quadlets-manager check-conflicts <n>
ss -tlnp | grep <port>  # Find what's using it
```

### Problem: Update broke something

```bash
bluebuild-quadlets-manager backups <n>
bluebuild-quadlets-manager restore <n>
```

### Problem: Want to undo staged update

```bash
bluebuild-quadlets-manager discard <n>
```

## 💡 Pro Tips

### Tip 1: Always Stage First
```bash
# Don't do this in production
bluebuild-quadlets-manager update all  # RISKY

# Do this instead
bluebuild-quadlets-manager stage all
bluebuild-quadlets-manager apply all   # SAFE
```

### Tip 2: Regular Backups
```bash
# Weekly backup routine
bluebuild-quadlets-manager backup all

# Or add to crontab
0 0 * * 0 bluebuild-quadlets-manager backup all
```

### Tip 3: Check Before Applying
```bash
# Always diff before apply
bluebuild-quadlets-manager diff <n>

# Look for:
# - New ports (conflicts?)
# - Changed images (breaking changes?)
# - New volumes (migration needed?)
```

### Tip 4: Test in User Scope First
```yaml
# Test with scope: user
- name: test-service
  scope: user

# Then promote to system if good
- name: prod-service
  scope: system
```

### Tip 5: Keep Backups for 7+ Days
```bash
# Backups are cheap, disasters are expensive
# Keep at least a week of backups

# Cleanup old backups manually
ls -lt /var/lib/bluebuild/quadlets/backups/*/
```

## 📚 Learning Resources

- **Full Documentation**: README.md
- **Implementation Details**: IMPLEMENTATION-GUIDE.md
- **Examples**: examples/ directory

## 📊 Cheat Sheet

### Most Common Commands

```bash
# Daily checks
bluebuild-quadlets-manager list

# Weekly updates
bluebuild-quadlets-manager stage all
bluebuild-quadlets-manager apply all

# Monthly backup
bluebuild-quadlets-manager backup all

# When things break
bluebuild-quadlets-manager restore <n>
```

### Key Features

| Feature | Legacy | Enhanced |
|---------|--------|----------|
| Update | `update all` | `stage all` → `apply all` |
| Preview | ❌ | `diff <n>` |
| Backup | ❌ | `backup <n>` |
| Restore | ❌ | `restore <n>` |
| Validate | Basic | Enhanced with conflicts |

---

**Remember**: 
- 🟢 **Stage First** - Safer than direct update
- 🟢 **Backup Often** - Before major changes
- 🟢 **Diff Always** - Know what's changing
- 🟢 **Test in User** - Before system-wide deployment
