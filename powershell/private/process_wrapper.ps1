#!/usr/bin/env pwsh
# process_wrapper.ps1
# Configures the PowerShell module environment and executes the main script.

<#
.SYNOPSIS
    Process wrapper for rules_powershell executables.

.DESCRIPTION
    This script configures the PowerShell module environment by:
    - Constructing a runfiles tree if necessary
    - Setting up PSModulePath with module imports
    - Executing the main script with proper argument passing
#>

# Error handling: exit on any error
$ErrorActionPreference = "Stop"

# Function to create a symlink or copy based on OS
function Install-File {
    param(
        [Parameter(Mandatory)]
        [string]$Source,
        
        [Parameter(Mandatory)]
        [string]$Destination
    )
    
    # Ensure destination directory exists
    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    # On Windows, copy files. On Unix, use symlinks for better performance
    if ($IsWindows) {
        Copy-Item -Path $Source -Destination $Destination -Force
    } else {
        # Use symlinks on Unix
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -Force | Out-Null
    }
}

# Function to construct a runfiles tree from a manifest
function New-RunfilesTree {
    param(
        [Parameter(Mandatory)]
        $FileManifest,
        
        [Parameter(Mandatory)]
        [string]$OutputDir
    )
    
    # Convert PSCustomObject to hashtable if needed
    if ($FileManifest -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $FileManifest.PSObject.Properties) {
            $hashtable[$property.Name] = $property.Value
        }
        $FileManifest = $hashtable
    }
    
    # Create the output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Read the runfiles manifest if it exists
    $runfilesMap = @{}
    if ($env:RUNFILES_MANIFEST_FILE -and (Test-Path $env:RUNFILES_MANIFEST_FILE)) {
        $lines = Get-Content $env:RUNFILES_MANIFEST_FILE
        foreach ($line in $lines) {
            if ($line -match '^(.+?)\s+(.+)$') {
                # Handle escaped spaces in rlocation paths
                $rlocation = $matches[1] -replace '\\s', ' '
                $realPath = $matches[2]
                $runfilesMap[$rlocation] = $realPath
            }
        }
    }
    
    # Install each file from the manifest
    foreach ($entry in $FileManifest.GetEnumerator()) {
        $rlocationPath = $entry.Value
        $destPath = Join-Path $OutputDir $rlocationPath
        
        # Resolve the source file
        $sourcePath = $null
        if ($runfilesMap.ContainsKey($rlocationPath)) {
            # Use the manifest mapping
            $sourcePath = $runfilesMap[$rlocationPath]
        } elseif ($env:RUNFILES_DIR) {
            # Try RUNFILES_DIR
            $candidatePath = Join-Path $env:RUNFILES_DIR $rlocationPath
            if (Test-Path $candidatePath) {
                $sourcePath = $candidatePath
            }
        }
        
        # Install the file if we found it
        if ($sourcePath -and (Test-Path $sourcePath)) {
            Install-File -Source $sourcePath -Destination $destPath
        }
    }
}

# Function to resolve runfiles paths to absolute paths
function Resolve-Runfile {
    param(
        [Parameter(Mandatory)]
        [string]$RunfilePath
    )
    
    # Try RUNFILES_DIR first (more efficient)
    if ($env:RUNFILES_DIR) {
        $resolved = Join-Path $env:RUNFILES_DIR $RunfilePath
        if (Test-Path $resolved) {
            return $resolved
        }
    }
    
    # Fall back to RUNFILES_MANIFEST_FILE
    if ($env:RUNFILES_MANIFEST_FILE) {
        if (Test-Path $env:RUNFILES_MANIFEST_FILE) {
            $lines = Get-Content $env:RUNFILES_MANIFEST_FILE
            foreach ($line in $lines) {
                if ($line -match "^$([regex]::Escape($RunfilePath))\s+(.+)$") {
                    return $matches[1]
                }
            }
        }
    }
    
    # If not found, return the path as-is (might be absolute already)
    return $RunfilePath
}

# Main entrypoint function for the process wrapper
function Invoke-ProcessWrapper {
    # Note: We don't use param() here because we need to pass through
    # arbitrary arguments to the user's script, which may include named
    # parameters. We'll use $args directly instead.
    
    # Configure the runfiles environment from RULES_POWERSHELL_CONFIG
    if (-not $env:RULES_POWERSHELL_CONFIG) {
        Write-Error "RULES_POWERSHELL_CONFIG environment variable is not set"
        exit 1
    }

    if (-not $env:RULES_POWERSHELL_MAIN) {
        Write-Error "RULES_POWERSHELL_MAIN environment variable is not set"
        exit 1
    }

    # Resolve the config and main file paths
    $configPath = Resolve-Runfile $env:RULES_POWERSHELL_CONFIG
    $mainPath = Resolve-Runfile $env:RULES_POWERSHELL_MAIN

    # Read and parse the config file
    if (-not (Test-Path $configPath)) {
        Write-Error "Config file not found: $configPath"
        exit 1
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json

    # Construct runfiles tree if necessary
    # This is needed when runfiles don't already exist in a directory structure
    $constructedRunfiles = $false
    if ($config.runfiles -and $config.runfiles.PSObject.Properties.Count -gt 0) {
        # Check if we need to construct a runfiles tree
        # We need it if RUNFILES_DIR doesn't exist or isn't accessible
        $needsRunfilesTree = $false
        
        if (-not $env:RUNFILES_DIR) {
            $needsRunfilesTree = $true
        } elseif (-not (Test-Path $env:RUNFILES_DIR)) {
            $needsRunfilesTree = $true
        }
        
        if ($needsRunfilesTree) {
            # Determine the temporary directory location
            # For tests, use TEST_TMPDIR if available
            $tempBase = if ($env:TEST_TMPDIR) { $env:TEST_TMPDIR } else { [System.IO.Path]::GetTempPath() }
            
            # Create a unique temporary directory for runfiles
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $processId = $PID
            $runfilesDir = Join-Path $tempBase "pwsh-runfiles-${timestamp}-${processId}"
            
            # Construct the runfiles tree
            Write-Verbose "Constructing runfiles tree at: $runfilesDir"
            New-RunfilesTree -FileManifest $config.runfiles -OutputDir $runfilesDir
            
            # Update RUNFILES_DIR to point to the constructed tree
            $env:RUNFILES_DIR = $runfilesDir
            $constructedRunfiles = $true
            
            Write-Verbose "Runfiles tree constructed successfully"
        }
    }

    # Set up PSModulePath with module imports
    if ($config.imports -and $config.imports.Count -gt 0) {
        $moduleDirs = [System.Collections.Generic.HashSet[string]]::new()
        
        foreach ($importPath in $config.imports) {
            # Resolve the module file path
            $moduleFile = Resolve-Runfile $importPath
            
            if (Test-Path $moduleFile) {
                # Get the module directory (parent of the module file)
                # For example: MathFunctions/MathFunctions.psm1 -> MathFunctions/
                $moduleDir = Split-Path -Parent $moduleFile
                
                # Get the parent directory that should be in PSModulePath
                # For example: .../tests/module/MathFunctions -> .../tests/module
                $parentDir = Split-Path -Parent $moduleDir
                
                # Add to the set (avoids duplicates)
                if ($parentDir) {
                    [void]$moduleDirs.Add($parentDir)
                }
            }
        }
        
        # Prepend the module directories to PSModulePath
        if ($moduleDirs.Count -gt 0) {
            $separator = if ($IsWindows) { ';' } else { ':' }
            $existingPath = $env:PSModulePath
            $newPaths = $moduleDirs -join $separator
            
            if ($existingPath) {
                $env:PSModulePath = "${newPaths}${separator}${existingPath}"
            } else {
                $env:PSModulePath = $newPaths
            }
        }
    }

    # Verify the main script exists
    if (-not (Test-Path $mainPath)) {
        Write-Error "Main script not found: $mainPath"
        exit 1
    }

    # Read the script content to check if it defines a main function
    $scriptContent = Get-Content $mainPath -Raw

    try {
        # Check if the script defines a main function (case-insensitive)
        $hasMainFunction = $scriptContent -match '\bfunction\s+main\b'
        
        if ($hasMainFunction) {
            # Script has a main function - dot-source it with arguments to handle param() blocks
            . $mainPath @args
            
            # The main function will be called automatically if the script invokes it
            # (e.g., "Main -Output $Output" at the end of the script)
            # If not automatically called, we could call it here, but that would duplicate execution
        } else {
            # Script doesn't have a main function - execute it directly with arguments
            # This handles scripts with param() blocks and top-level code
            & $mainPath @args
        }
    } finally {
        # Clean up constructed runfiles tree
        # Skip cleanup if running under bazel test (TEST_TMPDIR is set, Bazel will clean it up)
        # or if user explicitly requests to keep it
        if ($constructedRunfiles -and $env:RUNFILES_DIR) {
            $skipCleanup = $false
            
            # Skip if running under bazel test
            if ($env:TEST_TMPDIR) {
                $skipCleanup = $true
            }
            
            # Allow users to explicitly prevent cleanup for debugging
            if ($env:RULES_POWERSHELL_LEAK_RUNFILES) {
                $skipCleanup = $true
            }
            
            if (-not $skipCleanup) {
                try {
                    Write-Verbose "Cleaning up runfiles tree: $($env:RUNFILES_DIR)"
                    Remove-Item -Path $env:RUNFILES_DIR -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Warning "Failed to clean up runfiles tree at $($env:RUNFILES_DIR): $_"
                }
            } else {
                Write-Verbose "Skipping cleanup of runfiles tree: $($env:RUNFILES_DIR)"
            }
        }
    }
}

# Invoke the process wrapper with all script arguments
Invoke-ProcessWrapper @args
