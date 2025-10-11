#!/usr/libexec/bluebuild/nu/nu

const usrSharePath = "/usr/share/bluebuild/quadlets"
const libExecPath = "/usr/libexec/bluebuild/quadlets"
const configPath = $"($usrSharePath)/configuration.yaml"

const defaultConfiguration = {
    scope: user
    branch: "main"
    notify: true
    managed-externally: false
    setup-delay: "5m"
}

const defaultAutoUpdate = {
    enabled: true
    interval: "7d"
    wait-after-boot: "5m"
}

const defaultContainerAutoUpdate = {
    enabled: true
    interval: "daily"
}

def main [configStr: string] {
    let config = $configStr | from yaml
    
    # Validate configurations exist
    if not ('configurations' in $config) {
        print $"(ansi red_bold)CONFIGURATION ERROR(ansi reset)"
        print "The quadlets module requires at least one configuration."
        print "Example:"
        print "  type: quadlets"
        print "  configurations:"
        print "    - name: ai-stack"
        print "      source: https://github.com/rgolangh/podman-quadlets/tree/main/ai-stack"
        exit 1
    }

    print ""
    print $"(ansi cyan_bold)═══════════════════════════════════════════════════════════════(ansi reset)"
    print $"(ansi cyan_bold)  BlueBuild Quadlets Module - Setup(ansi reset)"
    print $"(ansi cyan_bold)═══════════════════════════════════════════════════════════════(ansi reset)"
    print ""

    # Merge with defaults
    let configurations = $config.configurations | each {|configuration|
        mut merged = $defaultConfiguration | merge $configuration
        
        print $"(ansi green_bold)▶(ansi reset) Processing quadlet: (ansi default_italic)($merged.name)(ansi reset)"
        
        # Validate required fields
        if ($merged.name | is-empty) {
            print $"(ansi red_bold)Configuration Error(ansi reset): 'name' is required"
            exit 1
        }
        if ($merged.source | is-empty) {
            print $"(ansi red_bold)Configuration Error(ansi reset): 'source' is required for ($merged.name)"
            exit 1
        }
        
        # Validate scope
        if not ($merged.scope == "system" or $merged.scope == "user") {
            print $"(ansi red_bold)Scope must be either(ansi reset) (ansi blue_italic)system(ansi reset) (ansi red_bold)or(ansi reset) (ansi blue_italic)user(ansi reset)"
            print $"(ansi blue)Your input:(ansi reset) ($merged.scope)"
            exit 1
        }
        
        # Process based on source type
        if ($merged.source | str starts-with "http") {
            # Git source
            if ($merged.managed-externally) {
                print $"(ansi yellow_bold)  ⚠ Warning(ansi reset): Git source with managed-externally flag for ($merged.name)"
                print "    Git sources are automatically managed. The managed-externally flag will be ignored."
            }
            
            print $"  📦 Downloading from Git: ($merged.source)"
            let result = (do {
                nu $"($env.MODULE_DIRECTORY)/quadlets/git-source-parser.nu" ($merged.source) ($merged.branch) ($merged.name)
            } | complete)
            
            if $result.exit_code != 0 {
                print $"(ansi red_bold)  ✗ Error downloading quadlet(ansi reset): ($merged.name)"
                print $result.stderr
                exit 1
            }
            
            # Validation with dependency analysis
            print $"  🔍 Validating quadlet files (with dependency analysis)"
            let validateResult = (do {
                nu $"($env.MODULE_DIRECTORY)/quadlets/quadlet-validator.nu" ($merged.name) --check-conflicts
            } | complete)
            
            if $validateResult.exit_code != 0 {
                print $"(ansi red_bold)  ✗ Validation failed(ansi reset): ($merged.name)"
                print $validateResult.stderr
                exit 1
            }
            
        } else if ($merged.managed-externally) {
            # Externally managed - just record configuration
            print $"  🔐 Externally managed quadlet - will be discovered at runtime"
            print $"  📍 Expected location: ($merged.source)"
            
        } else {
            print $"(ansi red_bold)Configuration Error(ansi reset): Local paths require managed-externally flag"
            print $"  For quadlet '($merged.name)' with source '($merged.source)'"
            print $"  Either use a Git URL or set managed-externally: true"
            exit 1
        }
        
        print $"  (ansi green)✓(ansi reset) Configuration complete"
        print ""
        $merged
    }

    # Merge auto-update configuration
    let autoUpdate = if ('auto-update' in $config) {
        $defaultAutoUpdate | merge $config.auto-update
    } else {
        $defaultAutoUpdate
    }

    # Merge container-auto-update configuration
    let containerAutoUpdate = if ('container-auto-update' in $config) {
        $defaultContainerAutoUpdate | merge $config.container-auto-update
    } else {
        $defaultContainerAutoUpdate
    }

    # Validate container-auto-update interval
    if not ($containerAutoUpdate.interval in ["daily", "weekly", "monthly"]) {
        print $"(ansi red_bold)Error(ansi reset): container-auto-update interval must be daily, weekly, or monthly"
        print $"(ansi blue)Your input:(ansi reset) ($containerAutoUpdate.interval)"
        exit 1
    }

    # Save configuration
    mkdir ($configPath | path dirname)
    {
        configurations: $configurations,
        auto-update: $autoUpdate,
        container-auto-update: $containerAutoUpdate
    } | to yaml | save -f $configPath

    print $"(ansi green_bold)✓ Successfully configured ($configurations | length) quadlet\(s\)(ansi reset)"
    
    # Set up systemd services and scripts
    print ""
    print $"(ansi cyan_bold)Setting up systemd services and  features...(ansi reset)"
    
    # Create required directories
    mkdir /usr/lib/systemd/system/
    mkdir /usr/lib/systemd/user/
    mkdir ($libExecPath)
    mkdir ($usrSharePath)
    
    # Create staging and backup directories
    mkdir /var/lib/bluebuild/quadlets/staged
    mkdir /var/lib/bluebuild/quadlets/backups
    mkdir /var/lib/bluebuild/quadlets/manifests
    
    # Copy service files
    print "  📝 Installing systemd unit files..."
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/system-quadlets-setup" $"($libExecPath)/system-quadlets-setup"
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/system-quadlets-setup.service" /usr/lib/systemd/system/
    
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-setup" $"($libExecPath)/user-quadlets-setup"
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-setup.service" /usr/lib/systemd/user/
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-setup.timer" /usr/lib/systemd/user/
    
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/system-quadlets-update" $"($libExecPath)/system-quadlets-update"
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/system-quadlets-update.service" /usr/lib/systemd/system/
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/system-quadlets-update.timer" /usr/lib/systemd/system/
    
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-update" $"($libExecPath)/user-quadlets-update"
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-update.service" /usr/lib/systemd/user/
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/user-quadlets-update.timer" /usr/lib/systemd/user/
    
    # Copy scripts
    print "  ✨ Installing module features..."
    
    # Validator
    cp $"($env.MODULE_DIRECTORY)/quadlets/quadlet-validator.nu" $"($usrSharePath)/quadlet-validator.nu"
    chmod +x $"($usrSharePath)/quadlet-validator.nu"
    
    # Staged updates manager
    cp $"($env.MODULE_DIRECTORY)/quadlets/staged-updates.nu" $"($usrSharePath)/staged-updates.nu"
    chmod +x $"($usrSharePath)/staged-updates.nu"
    
    # CLI manager
    cp $"($env.MODULE_DIRECTORY)/quadlets/post-boot/bluebuild-quadlets-manager" "/usr/bin/bluebuild-quadlets-manager"
    chmod +x "/usr/bin/bluebuild-quadlets-manager"
    
    # Git source parser (also needed by staged updates)
    cp $"($env.MODULE_DIRECTORY)/quadlets/git-source-parser.nu" $"($usrSharePath)/git-source-parser.nu"
    chmod +x $"($usrSharePath)/git-source-parser.nu"
    
    # Make all scripts executable
    chmod +x $"($libExecPath)/system-quadlets-setup"
    chmod +x $"($libExecPath)/user-quadlets-setup"
    chmod +x $"($libExecPath)/system-quadlets-update"
    chmod +x $"($libExecPath)/user-quadlets-update"
    
    # Enable timers
    let hasSystemQuadlets = ($configurations | any {|c| $c.scope == "system"})
    let hasUserQuadlets = ($configurations | any {|c| $c.scope == "user"})
    
    if $hasSystemQuadlets {
        systemctl enable system-quadlets-setup.service
        if $autoUpdate.enabled {
            systemctl enable system-quadlets-update.timer
        }
    }
    
    if $hasUserQuadlets {
        systemctl enable --global user-quadlets-setup.timer
        if $autoUpdate.enabled {
            systemctl enable --global user-quadlets-update.timer
        }
    }
    
    # Enable Podman auto-update if requested
    if $containerAutoUpdate.enabled {
        # Convert interval to systemd timer format
        let onCalendar = match $containerAutoUpdate.interval {
            "daily" => "daily",
            "weekly" => "weekly",
            "monthly" => "monthly"
        }
        
        # Update podman-auto-update timer for system
        if $hasSystemQuadlets {
            mkdir /usr/lib/systemd/system/podman-auto-update.timer.d/
            $"[Timer]\nOnCalendar=($onCalendar)\n" | save -f /usr/lib/systemd/system/podman-auto-update.timer.d/bluebuild-quadlets.conf
            systemctl enable podman-auto-update.timer
        }
        
        # Update podman-auto-update timer for user
        if $hasUserQuadlets {
            mkdir /usr/lib/systemd/user/podman-auto-update.timer.d/
            $"[Timer]\nOnCalendar=($onCalendar)\n" | save -f /usr/lib/systemd/user/podman-auto-update.timer.d/bluebuild-quadlets.conf
            systemctl enable --global podman-auto-update.timer
        }
    }
    
    print $"  (ansi green)✓(ansi reset) Systemd services configured"
    print $"  (ansi green)✓(ansi reset) Module features enabled"
    
    print ""
    print $"(ansi cyan_bold)═══════════════════════════════════════════════════════════════(ansi reset)"
    print $"(ansi green_bold)✓ Quadlets Module  Setup Complete!(ansi reset)"
    print $"(ansi cyan_bold)═══════════════════════════════════════════════════════════════(ansi reset)"
    print ""
    print $"(antml:bold)New  Features Available:(ansi reset)"
    print "  • Staged Updates - Safe preview before applying"
    print "  • Backup & Restore - Automatic backups with volume support"
    print "  • Validation - Dependency analysis & conflict detection"
    print "  • Improved Inspection - Detailed quadlet analysis"
    print ""
    print $"(antml:bold)Quick Start:(ansi reset)"
    print $"  (ansi cyan)bluebuild-quadlets-manager show(ansi reset)         - View configuration"
    print $"  (ansi cyan)bluebuild-quadlets-manager stage all(ansi reset)    - Stage updates (safe)"
    print $"  (ansi cyan)bluebuild-quadlets-manager diff <n>(ansi reset)  - Preview changes"
    print $"  (ansi cyan)bluebuild-quadlets-manager apply <n>(ansi reset) - Apply updates"
    print ""
    print $"For full documentation, see: (ansi default_italic)README.md(ansi reset)"
}
