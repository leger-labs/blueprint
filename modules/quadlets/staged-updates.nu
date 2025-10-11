#!/usr/libexec/bluebuild/nu/nu

# Staged Updates Manager
# Handles downloading, staging, previewing, and applying quadlet updates

const configPath = "/usr/share/bluebuild/quadlets/configuration.yaml"
const stagedPath = "/var/lib/bluebuild/quadlets/staged"
const backupPath = "/var/lib/bluebuild/quadlets/backups"
const manifestPath = "/var/lib/bluebuild/quadlets/manifests"

def main [action: string, ...args] {
    match $action {
        "stage" => { stageUpdates ...$args }
        "apply" => { applyStaged ...$args }
        "discard" => { discardStaged ...$args }
        "diff" => { showDiff ...$args }
        "list" => { listStaged }
        "backup" => { createBackup ...$args }
        "restore" => { restoreBackup ...$args }
        "list-backups" => { listBackups ...$args }
        _ => { showHelp }
    }
}

def showHelp [] {
    print "Staged Updates Manager - Safe quadlet update workflow"
    print ""
    print "Usage: staged-updates.nu <action> [options]"
    print ""
    print "Actions:"
    print "  stage <name|all>        - Download and validate updates without applying"
    print "  apply <name|all>        - Apply previously staged updates"
    print "  discard <name|all>      - Discard staged updates"
    print "  diff <n>             - Show differences between current and staged"
    print "  list                    - List all staged updates"
    print "  backup <name|all>       - Create backup of current quadlet(s)"
    print "  restore <n> [id]     - Restore from backup"
    print "  list-backups [name]     - List available backups"
}

def stageUpdates [...names: string] {
    if not ($configPath | path exists) {
        print $"(ansi red)No configuration found(ansi reset)"
        exit 1
    }
    
    let config = (open $configPath)
    let scope = (if (isUserScope) { "user" } else { "system" })
    let quadlets = ($config.configurations | where scope == $scope)
    
    let toStage = if ($names | is-empty) or (($names | first) == "all") {
        $quadlets
    } else {
        $quadlets | where name in $names
    }
    
    if ($toStage | is-empty) {
        print $"(ansi yellow)No quadlets to stage(ansi reset)"
        exit 0
    }
    
    print $"Staging ($toStage | length) quadlet\(s\)..."
    
    mkdir $stagedPath
    mkdir $manifestPath
    
    for quadlet in $toStage {
        if $quadlet.managed-externally {
            print $"  (ansi blue)ℹ(ansi reset) Skipping externally-managed: ($quadlet.name)"
            continue
        }
        
        if not ($quadlet.source | str starts-with "http") {
            print $"  (ansi blue)ℹ(ansi reset) Skipping non-Git source: ($quadlet.name)"
            continue
        }
        
        print $"  Staging ($quadlet.name)..."
        
        let stagingDir = $"($stagedPath)/($quadlet.name)"
        mkdir $stagingDir
        
        # Download to staging area
        let result = (do {
            nu /usr/share/bluebuild/quadlets/git-source-parser.nu ($quadlet.source) ($quadlet.branch) ($quadlet.name)
        } | complete)
        
        if $result.exit_code != 0 {
            print $"    (ansi red)✗(ansi reset) Failed to download"
            rm -rf $stagingDir
            continue
        }
        
        # Move to staging
        let downloadedPath = $"/tmp/bluebuild-quadlets/($quadlet.name)"
        if ($downloadedPath | path exists) {
            rm -rf $stagingDir
            mv $downloadedPath $stagingDir
        }
        
        # Validate staged update
        print $"    Validating..."
        let validationResult = (do {
            nu /usr/share/bluebuild/quadlets/quadlet-validator.nu ($quadlet.name) --staging --check-conflicts
        } | complete)
        
        if $validationResult.exit_code != 0 {
            print $"    (ansi red)✗(ansi reset) Validation failed"
            rm -rf $stagingDir
            continue
        }
        
        # Create manifest
        let manifest = {
            name: $quadlet.name
            source: $quadlet.source
            branch: $quadlet.branch
            staged_at: (date now | format date "%Y-%m-%d %H:%M:%S")
            files: (ls $stagingDir | get name | each {|f| $f | path basename })
        }
        
        $manifest | to yaml | save -f $"($manifestPath)/($quadlet.name).yaml"
        
        print $"    (ansi green)✓(ansi reset) Staged successfully"
    }
    
    print ""
    print $"(ansi green)Staging complete!(ansi reset)"
    print $"Review with: (ansi cyan)staged-updates.nu diff <n>(ansi reset)"
    print $"Apply with: (ansi cyan)staged-updates.nu apply <name|all>(ansi reset)"
}

def applyStaged [...names: string] {
    let scope = (if (isUserScope) { "user" } else { "system" })
    let destPath = (getDestPath $scope)
    
    if not ($stagedPath | path exists) {
        print $"(ansi yellow)No staged updates found(ansi reset)"
        exit 0
    }
    
    let stagedQuadlets = (ls $stagedPath | where type == dir | get name | each {|p| $p | path basename})
    
    let toApply = if ($names | is-empty) or (($names | first) == "all") {
        $stagedQuadlets
    } else {
        $stagedQuadlets | where {|q| $q in $names}
    }
    
    if ($toApply | is-empty) {
        print $"(ansi yellow)No staged updates to apply(ansi reset)"
        exit 0
    }
    
    print $"Applying ($toApply | length) staged update\(s\)..."
    
    for quadlet in $toApply {
        print $"  Applying ($quadlet)..."
        
        let stagedDir = $"($stagedPath)/($quadlet)"
        let currentPath = $"($destPath)/($quadlet)"
        
        # Create backup before applying
        if ($currentPath | path exists) {
            print $"    Creating backup..."
            createBackupInternal $quadlet $scope
        }
        
        # Stop services
        if ($currentPath | path exists) {
            print $"    Stopping services..."
            stopQuadletServices $currentPath $scope
        }
        
        # Apply update
        rm -rf $currentPath
        mkdir $currentPath
        cp -r $"($stagedDir)/*" $currentPath
        
        # Reload and restart
        print $"    Reloading systemd..."
        reloadSystemd $scope
        
        print $"    Starting services..."
        startQuadletServices $currentPath $scope
        
        # Clean up staging
        rm -rf $stagedDir
        rm -f $"($manifestPath)/($quadlet).yaml"
        
        print $"    (ansi green)✓(ansi reset) Applied successfully"
    }
    
    print ""
    print $"(ansi green)Updates applied!(ansi reset)"
}

def discardStaged [...names: string] {
    if not ($stagedPath | path exists) {
        print $"(ansi yellow)No staged updates found(ansi reset)"
        exit 0
    }
    
    let stagedQuadlets = (ls $stagedPath | where type == dir | get name | each {|p| $p | path basename})
    
    let toDiscard = if ($names | is-empty) or (($names | first) == "all") {
        $stagedQuadlets
    } else {
        $stagedQuadlets | where {|q| $q in $names}
    }
    
    if ($toDiscard | is-empty) {
        print $"(ansi yellow)No staged updates to discard(ansi reset)"
        exit 0
    }
    
    print $"Discarding ($toDiscard | length) staged update\(s\)..."
    
    for quadlet in $toDiscard {
        rm -rf $"($stagedPath)/($quadlet)"
        rm -f $"($manifestPath)/($quadlet).yaml"
        print $"  (ansi green)✓(ansi reset) Discarded ($quadlet)"
    }
    
    print ""
    print $"(ansi green)Staged updates discarded(ansi reset)"
}

def showDiff [name: string] {
    let scope = (if (isUserScope) { "user" } else { "system" })
    let destPath = (getDestPath $scope)
    
    let stagedDir = $"($stagedPath)/($name)"
    let currentPath = $"($destPath)/($name)"
    
    if not ($stagedDir | path exists) {
        print $"(ansi red)No staged update found for ($name)(ansi reset)"
        exit 1
    }
    
    if not ($currentPath | path exists) {
        print $"(ansi yellow)Quadlet not currently installed(ansi reset)"
        print $"Staged files:"
        ls $stagedDir | get name | each {|f| print $"  + ($f | path basename)"}
        exit 0
    }
    
    print $"(ansi cyan_bold)Differences for ($name):(ansi reset)"
    print ""
    
    # Use diff to show changes
    let diffResult = (do -i {
        diff -ur --color=always $currentPath $stagedDir
    } | complete)
    
    if $diffResult.exit_code == 0 {
        print $"  (ansi green)No differences found(ansi reset)"
    } else {
        print $diffResult.stdout
    }
}

def listStaged [] {
    if not ($stagedPath | path exists) {
        print $"(ansi yellow)No staged updates(ansi reset)"
        exit 0
    }
    
    let stagedQuadlets = (ls $stagedPath | where type == dir)
    
    if ($stagedQuadlets | is-empty) {
        print $"(ansi yellow)No staged updates(ansi reset)"
        exit 0
    }
    
    print $"(ansi cyan_bold)Staged Updates:(ansi reset)"
    print ""
    
    for quadlet in $stagedQuadlets {
        let name = ($quadlet.name | path basename)
        let manifestFile = $"($manifestPath)/($name).yaml"
        
        if ($manifestFile | path exists) {
            let manifest = (open $manifestFile)
            print $"  (ansi bold)($name)(ansi reset)"
            print $"    Source: ($manifest.source)"
            print $"    Staged: ($manifest.staged_at)"
            print $"    Files: ($manifest.files | length)"
        } else {
            print $"  (ansi bold)($name)(ansi reset)"
        }
        print ""
    }
}

def createBackup [...names: string] {
    let scope = (if (isUserScope) { "user" } else { "system" })
    let destPath = (getDestPath $scope)
    
    if not ($destPath | path exists) {
        print $"(ansi yellow)No quadlets installed(ansi reset)"
        exit 0
    }
    
    let installedQuadlets = (ls $destPath | where type == dir | get name | each {|p| $p | path basename})
    
    let toBackup = if ($names | is-empty) or (($names | first) == "all") {
        $installedQuadlets
    } else {
        $installedQuadlets | where {|q| $q in $names}
    }
    
    if ($toBackup | is-empty) {
        print $"(ansi yellow)No quadlets to backup(ansi reset)"
        exit 0
    }
    
    mkdir $backupPath
    
    print $"Creating backup of ($toBackup | length) quadlet\(s\)..."
    
    for quadlet in $toBackup {
        createBackupInternal $quadlet $scope
    }
    
    print ""
    print $"(ansi green)Backup complete!(ansi reset)"
}

def createBackupInternal [name: string, scope: string] {
    let destPath = (getDestPath $scope)
    let quadletPath = $"($destPath)/($name)"
    
    if not ($quadletPath | path exists) {
        return
    }
    
    mkdir $"($backupPath)/($name)"
    
    let timestamp = (date now | format date "%Y%m%d-%H%M%S")
    let backupDir = $"($backupPath)/($name)/($timestamp)"
    
    mkdir $backupDir
    cp -r $"($quadletPath)/*" $backupDir
    
    # Backup volumes if they exist
    let volumeBackupDir = $"($backupDir)/volumes"
    mkdir $volumeBackupDir
    
    let containerFiles = (ls $quadletPath | where name =~ "\.container$")
    for file in $containerFiles {
        let content = (open $file.name)
        let volumeLines = ($content | lines | where {|line| $line | str contains "Volume="})
        
        for line in $volumeLines {
            let volumeName = ($line | str replace "Volume=" "" | str trim | split row ":" | first)
            
            # Check if volume exists
            let volumeExists = (do -i {
                podman volume exists $volumeName
            } | complete | get exit_code) == 0
            
            if $volumeExists {
                print $"      Backing up volume: ($volumeName)"
                podman volume export $volumeName -o $"($volumeBackupDir)/($volumeName).tar"
            }
        }
    }
    
    # Create backup manifest
    let manifest = {
        name: $name
        scope: $scope
        backed_up_at: (date now | format date "%Y-%m-%d %H:%M:%S")
        timestamp: $timestamp
        files: (ls $backupDir | where type == file | get name | each {|f| $f | path basename})
    }
    
    $manifest | to yaml | save -f $"($backupDir)/manifest.yaml"
    
    print $"    (ansi green)✓(ansi reset) Backed up ($name) to ($timestamp)"
}

def restoreBackup [name: string, timestamp: string = ""] {
    let scope = (if (isUserScope) { "user" } else { "system" })
    let quadletBackupPath = $"($backupPath)/($name)"
    
    if not ($quadletBackupPath | path exists) {
        print $"(ansi red)No backups found for ($name)(ansi reset)"
        exit 1
    }
    
    let backups = (ls $quadletBackupPath | where type == dir | get name | each {|p| $p | path basename} | sort --reverse)
    
    let backupToRestore = if ($timestamp | is-empty) {
        $backups | first
    } else {
        if $timestamp in $backups {
            $timestamp
        } else {
            print $"(ansi red)Backup ($timestamp) not found(ansi reset)"
            exit 1
        }
    }
    
    let backupDir = $"($quadletBackupPath)/($backupToRestore)"
    let destPath = (getDestPath $scope)
    let quadletPath = $"($destPath)/($name)"
    
    print $"Restoring ($name) from backup ($backupToRestore)..."
    
    # Stop services
    if ($quadletPath | path exists) {
        print $"  Stopping services..."
        stopQuadletServices $quadletPath $scope
    }
    
    # Restore files
    rm -rf $quadletPath
    mkdir $quadletPath
    cp -r $"($backupDir)/*" $quadletPath
    rm -rf $"($quadletPath)/volumes"  # Don't copy volume backups to config dir
    
    # Restore volumes
    let volumeBackupDir = $"($backupDir)/volumes"
    if ($volumeBackupDir | path exists) {
        print $"  Restoring volumes..."
        let volumeBackups = (ls $volumeBackupDir | where name =~ "\.tar$")
        
        for backup in $volumeBackups {
            let volumeName = ($backup.name | path basename | str replace ".tar" "")
            print $"    Restoring volume: ($volumeName)"
            
            # Remove existing volume if it exists
            do -i { podman volume rm $volumeName }
            
            # Create and import
            podman volume create $volumeName
            podman volume import $volumeName $backup.name
        }
    }
    
    # Reload and restart
    print $"  Reloading systemd..."
    reloadSystemd $scope
    
    print $"  Starting services..."
    startQuadletServices $quadletPath $scope
    
    print ""
    print $"(ansi green)✓(ansi reset) Restored ($name) from ($backupToRestore)"
}

def listBackups [name: string = ""] {
    if not ($backupPath | path exists) {
        print $"(ansi yellow)No backups found(ansi reset)"
        exit 0
    }
    
    let quadletsWithBackups = if ($name | is-empty) {
        ls $backupPath | where type == dir | get name | each {|p| $p | path basename}
    } else {
        if ($"($backupPath)/($name)" | path exists) {
            [$name]
        } else {
            print $"(ansi yellow)No backups found for ($name)(ansi reset)"
            exit 0
        }
    }
    
    if ($quadletsWithBackups | is-empty) {
        print $"(ansi yellow)No backups found(ansi reset)"
        exit 0
    }
    
    print $"(ansi cyan_bold)Available Backups:(ansi reset)"
    print ""
    
    for quadlet in $quadletsWithBackups {
        let backups = (ls $"($backupPath)/($quadlet)" | where type == dir | sort-by modified --reverse)
        
        print $"  (ansi bold)($quadlet)(ansi reset) - ($backups | length) backup\(s\)"
        
        for backup in $backups {
            let timestamp = ($backup.name | path basename)
            let manifestFile = $"($backup.name)/manifest.yaml"
            
            if ($manifestFile | path exists) {
                let manifest = (open $manifestFile)
                print $"    ($timestamp) - ($manifest.backed_up_at)"
            } else {
                print $"    ($timestamp)"
            }
        }
        print ""
    }
}

# Helper functions

def isUserScope [] {
    (id -u) != 0
}

def getDestPath [scope: string] {
    if $scope == "user" {
        $"($env.HOME)/.config/containers/systemd"
    } else {
        "/etc/containers/systemd"
    }
}

def reloadSystemd [scope: string] {
    if $scope == "user" {
        systemctl --user daemon-reload
    } else {
        systemctl daemon-reload
    }
}

def stopQuadletServices [quadletPath: string, scope: string] {
    let containerFiles = (ls $quadletPath | where name =~ "\.container$")
    
    for file in $containerFiles {
        let fileName = ($file.name | path basename)
        let serviceName = ($fileName | str replace ".container" ".service")
        
        if $scope == "user" {
            do -i { systemctl --user stop $serviceName }
        } else {
            do -i { systemctl stop $serviceName }
        }
    }
}

def startQuadletServices [quadletPath: string, scope: string] {
    let containerFiles = (ls $quadletPath | where name =~ "\.container$")
    
    for file in $containerFiles {
        let fileName = ($file.name | path basename)
        let serviceName = ($fileName | str replace ".container" ".service")
        
        if $scope == "user" {
            systemctl --user start $serviceName
        } else {
            systemctl start $serviceName
        }
    }
}
