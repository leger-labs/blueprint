#!/usr/libexec/bluebuild/nu/nu

# Quadlet Validator with dependency analysis and conflict detection
# Usage: quadlet-validator.nu <quadlet-name> [--check-conflicts]

const validExtensions = [".container" ".pod" ".network" ".volume" ".kube" ".image"]

def main [quadletName: string, --check-conflicts: bool = false, --staging: bool = false] {
    let quadletPath = if $staging {
        $"/var/lib/bluebuild/quadlets/staged/($quadletName)"
    } else {
        $"/tmp/bluebuild-quadlets/($quadletName)"
    }
    
    if not ($quadletPath | path exists) {
        print $"(ansi red_bold)Error(ansi reset): Quadlet directory not found: ($quadletPath)"
        exit 1
    }
    
    let files = (ls $quadletPath | where type == file)
    
    if ($files | is-empty) {
        print $"(ansi red_bold)Error(ansi reset): No files found in quadlet directory"
        exit 1
    }
    
    mut hasQuadletFile = false
    mut errors = []
    mut warnings = []
    mut dependencies = {}
    mut publishedPorts = []
    mut volumes = []
    mut networks = []
    
    # First pass: collect all quadlet files and their metadata
    for file in $files {
        let fileName = ($file.name | path basename)
        let ext = ($fileName | path parse | get extension)
        
        if $ext in $validExtensions {
            $hasQuadletFile = true
            let content = (open $file.name)
            
            # Parse dependencies from Unit section
            let unitDeps = (parseUnitDependencies $content)
            if not ($unitDeps | is-empty) {
                $dependencies = ($dependencies | insert $fileName $unitDeps)
            }
            
            # Validate by type and collect metadata
            match $ext {
                ".container" => {
                    let validation = (validateContainer $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                    
                    # Collect published ports
                    let ports = (extractPublishedPorts $content)
                    $publishedPorts = ($publishedPorts | append $ports)
                    
                    # Collect volumes
                    let vols = (extractVolumes $content)
                    $volumes = ($volumes | append $vols)
                    
                    # Collect networks
                    let nets = (extractNetworks $content)
                    $networks = ($networks | append $nets)
                }
                ".pod" => {
                    let validation = (validatePod $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                    
                    let ports = (extractPublishedPorts $content)
                    $publishedPorts = ($publishedPorts | append $ports)
                }
                ".network" => {
                    let validation = (validateNetwork $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                }
                ".volume" => {
                    let validation = (validateVolume $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                }
                ".kube" => {
                    let validation = (validateKube $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                }
                ".image" => {
                    let validation = (validateImage $file.name $content)
                    $errors = ($errors | append $validation.errors)
                    $warnings = ($warnings | append $validation.warnings)
                }
            }
            
            print $"    (ansi green)✓(ansi reset) ($fileName)"
        } else if ($fileName | str ends-with ".service") or ($fileName | str ends-with ".timer") {
            print $"    (ansi blue)ℹ(ansi reset) ($fileName) (systemd unit)"
        } else {
            print $"    (ansi yellow)⚠(ansi reset) ($fileName) (non-quadlet file, will be copied)"
        }
    }
    
    # Check for at least one quadlet file
    if not $hasQuadletFile {
        print $"(ansi red_bold)Error(ansi reset): No valid quadlet files found"
        print $"  Valid extensions: ($validExtensions | str join ', ')"
        exit 1
    }
    
    # Dependency analysis
    print ""
    print $"(ansi cyan_bold)Dependency Analysis:(ansi reset)"
    if ($dependencies | is-empty) {
        print "  No explicit dependencies found"
    } else {
        for dep in ($dependencies | transpose key value) {
            print $"  ($dep.key):"
            for requirement in $dep.value {
                print $"    → ($requirement.type): ($requirement.unit)"
            }
        }
        
        # Check for circular dependencies
        let circular = (detectCircularDependencies $dependencies)
        if not ($circular | is-empty) {
            $errors = ($errors | append {
                type: "circular_dependency"
                message: $"Circular dependency detected: ($circular | str join ' → ')"
            })
        }
    }
    
    # Conflict detection
    if $check_conflicts {
        print ""
        print $"(ansi cyan_bold)Conflict Detection:(ansi reset)"
        
        # Check for port conflicts
        let portConflicts = (checkPortConflicts $publishedPorts)
        if not ($portConflicts | is-empty) {
            for conflict in $portConflicts {
                $warnings = ($warnings | append {
                    type: "port_conflict"
                    message: $"Port ($conflict.port) may conflict with existing services"
                })
            }
        }
        
        # Check for volume conflicts
        let volumeConflicts = (checkVolumeConflicts $volumes)
        if not ($volumeConflicts | is-empty) {
            for conflict in $volumeConflicts {
                $warnings = ($warnings | append {
                    type: "volume_conflict"
                    message: $"Volume ($conflict) may already be in use"
                })
            }
        }
    }
    
    # Report errors
    if not ($errors | is-empty) {
        print ""
        print $"(ansi red_bold)Validation Errors:(ansi reset)"
        for error in $errors {
            if ($error | describe) == "record" {
                print $"  • ($error.message)"
            } else {
                print $"  • ($error)"
            }
        }
        exit 1
    }
    
    # Report warnings
    if not ($warnings | is-empty) {
        print ""
        print $"(ansi yellow_bold)Warnings:(ansi reset)"
        for warning in $warnings {
            if ($warning | describe) == "record" {
                print $"  • ($warning.message)"
            } else {
                print $"  • ($warning)"
            }
        }
    }
    
    print ""
    print $"(ansi green)✓(ansi reset) Validation passed"
    
    # Return summary for programmatic use
    {
        valid: true
        dependencies: $dependencies
        ports: $publishedPorts
        volumes: $volumes
        networks: $networks
        warnings: ($warnings | length)
        errors: ($errors | length)
    }
}

def validateContainer [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "Image=") {
        $errors = ($errors | append $"($fileName): Container must specify Image=")
    }
    
    if not ($content | str contains "[Container]") {
        $errors = ($errors | append $"($fileName): Missing [Container] section")
    }
    
    # Check for deprecated options
    if ($content | str contains "Exec=") {
        $warnings = ($warnings | append $"($fileName): 'Exec=' is deprecated, use 'Command=' instead")
    }
    
    # Check for security contexts
    if not ($content | str contains "SecurityLabelType=") {
        $warnings = ($warnings | append $"($fileName): Consider setting SecurityLabelType= for better security")
    }
    
    { errors: $errors, warnings: $warnings }
}

def validatePod [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "[Pod]") {
        $errors = ($errors | append $"($fileName): Missing [Pod] section")
    }
    
    if not ($content | str contains "PodName=") {
        $warnings = ($warnings | append $"($fileName): Pod should specify PodName=")
    }
    
    { errors: $errors, warnings: $warnings }
}

def validateNetwork [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "[Network]") {
        $errors = ($errors | append $"($fileName): Missing [Network] section")
    }
    
    { errors: $errors, warnings: $warnings }
}

def validateVolume [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "[Volume]") {
        $errors = ($errors | append $"($fileName): Missing [Volume] section")
    }
    
    { errors: $errors, warnings: $warnings }
}

def validateKube [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "Yaml=") {
        $errors = ($errors | append $"($fileName): Kube file must specify Yaml=")
    }
    
    { errors: $errors, warnings: $warnings }
}

def validateImage [fileName: string, content: string] {
    mut errors = []
    mut warnings = []
    
    if not ($content | str contains "Image=") {
        $errors = ($errors | append $"($fileName): Image file must specify Image=")
    }
    
    { errors: $errors, warnings: $warnings }
}

def parseUnitDependencies [content: string] {
    mut deps = []
    
    let dependencyTypes = ["Requires" "Requisite" "Wants" "BindsTo" "PartOf" "After" "Before"]
    
    for depType in $dependencyTypes {
        let pattern = $"($depType)="
        let lines = ($content | lines | where {|line| $line | str contains $pattern })
        
        for line in $lines {
            let units = ($line | str replace $pattern "" | str trim | split row " ")
            for unit in $units {
                $deps = ($deps | append {
                    type: $depType
                    unit: $unit
                })
            }
        }
    }
    
    $deps
}

def extractPublishedPorts [content: string] {
    let lines = ($content | lines | where {|line| $line | str contains "PublishPort=" })
    
    $lines | each {|line|
        let port = ($line | str replace "PublishPort=" "" | str trim)
        let parts = ($port | split row ":")
        
        if ($parts | length) >= 2 {
            {
                host: ($parts | first)
                container: ($parts | get 1 | split row "/" | first)
                protocol: (if ($parts | get 1 | str contains "/") { 
                    $parts | get 1 | split row "/" | get 1 
                } else { 
                    "tcp" 
                })
            }
        } else {
            null
        }
    } | where {|item| $item != null}
}

def extractVolumes [content: string] {
    let lines = ($content | lines | where {|line| $line | str contains "Volume=" })
    
    $lines | each {|line|
        let vol = ($line | str replace "Volume=" "" | str trim)
        $vol | split row ":" | first
    }
}

def extractNetworks [content: string] {
    let lines = ($content | lines | where {|line| $line | str contains "Network=" })
    
    $lines | each {|line|
        $line | str replace "Network=" "" | str trim
    }
}

def detectCircularDependencies [dependencies: record] {
    # Simple circular dependency detection
    # Would need more sophisticated algorithm for complex cases
    mut visited = []
    
    # This is a placeholder - would need proper graph traversal
    []
}

def checkPortConflicts [ports: list] {
    let systemPorts = (do -i { ss -tlnp } | complete | get stdout | lines)
    
    $ports | each {|port|
        let hostPort = $port.host
        let inUse = ($systemPorts | any {|line| $line | str contains $":($hostPort)" })
        
        if $inUse {
            { port: $hostPort, protocol: $port.protocol }
        } else {
            null
        }
    } | where {|item| $item != null}
}

def checkVolumeConflicts [volumes: list] {
    let existingVolumes = (podman volume ls --format "{{.Name}}" | lines)
    
    $volumes | where {|vol| $vol in $existingVolumes}
}
