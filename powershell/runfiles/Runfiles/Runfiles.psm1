<#
.SYNOPSIS
    PowerShell runfiles library for Bazel.

.DESCRIPTION
    This module provides a runfiles library that allows PowerShell scripts
    to locate data dependencies at runtime using the Bazel runfiles mechanism.

    The runfiles library supports multiple methods of locating runfiles:
    - RUNFILES_DIR environment variable
    - RUNFILES_MANIFEST_FILE environment variable
    - {binary_name}.runfiles directory adjacent to the binary
    - {binary_name}.runfiles/MANIFEST file
#>

class Runfiles {
    [string]$RunfilesDir
    [hashtable]$ManifestMap

    # Private constructor - use [Runfiles]::Create() instead
    hidden Runfiles() {
        $this.RunfilesDir = $null
        $this.ManifestMap = @{}
    }

    <#
    .SYNOPSIS
        Creates a new Runfiles instance.

    .DESCRIPTION
        Initializes the runfiles library by detecting the runfiles location
        from environment variables or the binary's adjacent .runfiles directory.

    .PARAMETER ScriptPath
        Optional. The path to the script/binary. If not provided, auto-detection will be attempted.

    .EXAMPLE
        $runfiles = [Runfiles]::Create()
        $path = $runfiles.Rlocation("my_workspace/path/to/file.txt")
    #>
    static [Runfiles] Create() {
        return [Runfiles]::Create($null)
    }

    static [Runfiles] Create([string]$ScriptPath) {
        $rf = [Runfiles]::new()

        # Try to find runfiles directory
        $foundRunfilesDir = $null
        $foundManifestFile = $null

        # 1. Check RUNFILES_DIR environment variable
        if ($env:RUNFILES_DIR -and (Test-Path $env:RUNFILES_DIR)) {
            $foundRunfilesDir = $env:RUNFILES_DIR
        }

        # 2. Check for {binary_name}.runfiles directory adjacent to the script/binary
        if (-not $foundRunfilesDir) {
            # Get the directory where the current script is running from
            # Use different methods to find the script/binary path
            $detectedScriptPath = $ScriptPath

            if (-not $detectedScriptPath) {
                # Try to auto-detect the script path from the call stack
                $callStack = Get-PSCallStack
                if ($callStack -and $callStack.Count -gt 0) {
                    # Walk up the call stack to find the first script file
                    # Skip this module's own frames
                    foreach ($frame in $callStack) {
                        if ($frame.ScriptName -and
                            $frame.ScriptName -notlike "*Runfiles.psm1" -and
                            (Test-Path $frame.ScriptName)) {
                            $detectedScriptPath = $frame.ScriptName
                            break
                        }
                    }
                }
            }

            # If we found a script path, look for .runfiles directory
            if ($detectedScriptPath) {
                $scriptDir = Split-Path -Parent $detectedScriptPath
                $scriptName = Split-Path -Leaf $detectedScriptPath

                # Check for {script_name}.runfiles
                $candidateRunfiles = Join-Path $scriptDir "${scriptName}.runfiles"
                if (Test-Path $candidateRunfiles) {
                    $foundRunfilesDir = $candidateRunfiles
                }
            }
        }

        # 3. Set the runfiles directory if found
        if ($foundRunfilesDir) {
            $rf.RunfilesDir = $foundRunfilesDir
        }

        # 4. Check for RUNFILES_MANIFEST_FILE environment variable
        if ($env:RUNFILES_MANIFEST_FILE -and
            $env:RUNFILES_MANIFEST_FILE -ne "" -and
            (Test-Path $env:RUNFILES_MANIFEST_FILE)) {
            $foundManifestFile = $env:RUNFILES_MANIFEST_FILE
        }

        # 5. Check for MANIFEST file in {binary_name}.runfiles directory
        if (-not $foundManifestFile -and $rf.RunfilesDir) {
            $candidateManifest = Join-Path $rf.RunfilesDir "MANIFEST"
            if (Test-Path $candidateManifest) {
                $foundManifestFile = $candidateManifest
            }
        }

        # 6. Load the manifest file if found
        if ($foundManifestFile) {
            $rf.LoadManifest($foundManifestFile)
        }

        # If we couldn't find any runfiles location, throw an error
        if (-not $rf.RunfilesDir -and $rf.ManifestMap.Count -eq 0) {
            throw "Failed to locate runfiles. Set RUNFILES_DIR or RUNFILES_MANIFEST_FILE environment variable, or ensure a .runfiles directory exists adjacent to the binary."
        }

        return $rf
    }

    <#
    .SYNOPSIS
        Loads a runfiles manifest file.

    .PARAMETER ManifestPath
        The path to the manifest file to load.
    #>
    hidden [void] LoadManifest([string]$ManifestPath) {
        if (-not (Test-Path $ManifestPath)) {
            throw "Manifest file not found: $ManifestPath"
        }

        $lines = Get-Content $ManifestPath
        foreach ($line in $lines) {
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
                continue
            }

            # Parse the manifest line: "rlocationpath realpath"
            if ($line -match '^(.+?)\s+(.+)$') {
                $rlocationPath = $matches[1]
                $realPath = $matches[2]

                # Handle escaped spaces in rlocation paths
                $rlocationPath = $rlocationPath -replace '\\s', ' '

                $this.ManifestMap[$rlocationPath] = $realPath
            }
        }
    }

    <#
    .SYNOPSIS
        Resolves a runfiles path to an absolute filesystem path.

    .PARAMETER Rlocationpath
        The runfiles path to resolve (e.g., "my_workspace/path/to/file.txt").

    .RETURNS
        The absolute filesystem path to the runfile, or $null if not found.

    .EXAMPLE
        $runfiles = [Runfiles]::Create()
        $path = $runfiles.Rlocation("my_workspace/data/test.txt")
        if ($path) {
            $content = Get-Content $path
        }
    #>
    [string] Rlocation([string]$Rlocationpath) {
        if ([string]::IsNullOrWhiteSpace($Rlocationpath)) {
            return $null
        }

        # If it's already an absolute path that exists, return it
        if ([System.IO.Path]::IsPathRooted($Rlocationpath) -and (Test-Path $Rlocationpath)) {
            return $Rlocationpath
        }

        # 1. Try the manifest map first (most reliable)
        if ($this.ManifestMap.ContainsKey($Rlocationpath)) {
            $resolved = $this.ManifestMap[$Rlocationpath]
            if (Test-Path $resolved) {
                return $resolved
            }
        }

        # 2. Try RUNFILES_DIR
        if ($this.RunfilesDir) {
            $resolved = Join-Path $this.RunfilesDir $Rlocationpath
            if (Test-Path $resolved) {
                return $resolved
            }
        }

        # 3. Not found
        return $null
    }
}

# Module-level cached runfiles instance for convenience cmdlets
$script:CachedRunfiles = $null

function New-Runfiles {
    <#
    .SYNOPSIS
        Creates a new Runfiles instance.

    .DESCRIPTION
        This is a convenience function that wraps [Runfiles]::Create().

    .EXAMPLE
        $runfiles = New-Runfiles
        $path = $runfiles.Rlocation("my_workspace/path/to/file.txt")
    #>
    [CmdletBinding()]
    param()

    return [Runfiles]::Create()
}

function Get-Runfile {
    <#
    .SYNOPSIS
        Resolves a runfiles path to an absolute filesystem path.

    .DESCRIPTION
        Convenience cmdlet that creates or uses a cached Runfiles instance
        to resolve a runfile path. This is the most idiomatic PowerShell way
        to use the runfiles library.

    .PARAMETER Path
        The runfiles path to resolve (e.g., "my_workspace/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use. If not provided,
        a cached module-level instance will be created and reused.

    .OUTPUTS
        System.String. The absolute path to the runfile, or $null if not found.

    .EXAMPLE
        $path = Get-Runfile "my_workspace/data/config.txt"
        if ($path) {
            $content = Get-Content $path
        }

    .EXAMPLE
        # Using pipeline
        "my_workspace/data/file.txt" | Get-Runfile

    .EXAMPLE
        # Using explicit runfiles instance
        $runfiles = New-Runfiles
        $path = Get-Runfile "my_workspace/file.txt" -Runfiles $runfiles
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles
    )

    process {
        # Use provided instance or create/reuse cached one
        if ($Runfiles) {
            $rf = $Runfiles
        } else {
            if (-not $script:CachedRunfiles) {
                $script:CachedRunfiles = [Runfiles]::Create()
            }
            $rf = $script:CachedRunfiles
        }

        return $rf.Rlocation($Path)
    }
}

function Test-Runfile {
    <#
    .SYNOPSIS
        Tests whether a runfile exists.

    .DESCRIPTION
        Convenience cmdlet that resolves a runfiles path and checks if the
        file exists on the filesystem.

    .PARAMETER Path
        The runfiles path to test (e.g., "my_workspace/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use. If not provided,
        a cached module-level instance will be created and reused.

    .OUTPUTS
        System.Boolean. $true if the runfile exists, $false otherwise.

    .EXAMPLE
        if (Test-Runfile "my_workspace/data/config.txt") {
            Write-Host "Config file exists"
        }

    .EXAMPLE
        # Using pipeline
        "my_workspace/file.txt" | Test-Runfile
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles
    )

    process {
        # Use provided instance or create/reuse cached one
        if ($Runfiles) {
            $rf = $Runfiles
        } else {
            if (-not $script:CachedRunfiles) {
                $script:CachedRunfiles = [Runfiles]::Create()
            }
            $rf = $script:CachedRunfiles
        }

        $resolvedPath = $rf.Rlocation($Path)
        if ($resolvedPath -and (Test-Path $resolvedPath)) {
            return $true
        }
        return $false
    }
}

function Resolve-Runfile {
    <#
    .SYNOPSIS
        Alias for Get-Runfile. Resolves a runfiles path to an absolute filesystem path.

    .DESCRIPTION
        This is an alias for Get-Runfile, provided for users who prefer
        the more verbose "Resolve-" verb.

    .PARAMETER Path
        The runfiles path to resolve (e.g., "my_workspace/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use.

    .EXAMPLE
        $path = Resolve-Runfile "my_workspace/data/config.txt"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles
    )

    process {
        if ($Runfiles) {
            return Get-Runfile -Path $Path -Runfiles $Runfiles
        } else {
            return Get-Runfile -Path $Path
        }
    }
}

# Only export when running as a module (not when embedded)
# When embedded, the class and function are already in scope
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function New-Runfiles, Get-Runfile, Test-Runfile, Resolve-Runfile
}
