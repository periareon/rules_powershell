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

    Under bzlmod, paths are resolved through the `_repo_mapping` file Bazel ships with
    every executable, so apparent repository names (the module's own name, or the names
    given to `bazel_dep`) can be used in place of canonical ones. The source repository
    used for the mapping is inferred from the calling script and can be overridden.
#>

class Runfiles {
    [string]$RunfilesDir
    [hashtable]$ManifestMap
    # Canonical name of the repository whose repo mapping is used by default.
    # The main repository's canonical name is the empty string.
    [string]$SourceRepo
    hidden [hashtable]$RepoMapping

    # Private constructor - use [Runfiles]::Create() instead
    hidden Runfiles() {
        $this.RunfilesDir = $null
        $this.ManifestMap = @{}
        $this.SourceRepo = ''
        $this.RepoMapping = @{}
    }

    <#
    .SYNOPSIS
        Creates a new Runfiles instance.

    .DESCRIPTION
        Initializes the runfiles library by detecting the runfiles location
        from environment variables or the binary's adjacent .runfiles directory.

    .PARAMETER ScriptPath
        Optional. The path to the script/binary. If not provided, auto-detection will be attempted.

    .PARAMETER SourceRepo
        Optional. The canonical name of the repository whose repo mapping should be used.
        Defaults to the repository containing the calling script.

    .EXAMPLE
        $runfiles = [Runfiles]::Create()
        $path = $runfiles.Rlocation("my_module/path/to/file.txt")
    #>
    static [Runfiles] Create() {
        return [Runfiles]::Create($null)
    }

    static [Runfiles] Create([string]$ScriptPath) {
        $rf = [Runfiles]::new()

        $detectedScriptPath = $ScriptPath
        if (-not $detectedScriptPath) {
            $detectedScriptPath = [Runfiles]::DetectCallerScript()
        }

        # 1. RUNFILES_DIR environment variable
        if ($env:RUNFILES_DIR -and (Test-Path -LiteralPath $env:RUNFILES_DIR)) {
            $rf.RunfilesDir = $env:RUNFILES_DIR
        }

        # 2. {script}.runfiles directory adjacent to the script
        if (-not $rf.RunfilesDir -and $detectedScriptPath) {
            $candidate = "${detectedScriptPath}.runfiles"
            if (Test-Path -LiteralPath $candidate) {
                $rf.RunfilesDir = $candidate
            }
        }

        # 3. Manifest file
        $manifestFile = $null
        if ($env:RUNFILES_MANIFEST_FILE -and (Test-Path -LiteralPath $env:RUNFILES_MANIFEST_FILE)) {
            $manifestFile = $env:RUNFILES_MANIFEST_FILE
        } elseif ($rf.RunfilesDir -and (Test-Path -LiteralPath (Join-Path $rf.RunfilesDir 'MANIFEST'))) {
            $manifestFile = Join-Path $rf.RunfilesDir 'MANIFEST'
        } elseif ($detectedScriptPath -and (Test-Path -LiteralPath "${detectedScriptPath}.runfiles_manifest")) {
            $manifestFile = "${detectedScriptPath}.runfiles_manifest"
        }
        if ($manifestFile) {
            $rf.LoadManifest($manifestFile)
        }

        if (-not $rf.RunfilesDir -and $rf.ManifestMap.Count -eq 0) {
            throw "Failed to locate runfiles. Set RUNFILES_DIR or RUNFILES_MANIFEST_FILE environment variable, or ensure a .runfiles directory exists adjacent to the binary."
        }

        $rf.LoadRepoMapping()
        $rf.SourceRepo = $rf.InferSourceRepo($detectedScriptPath)

        return $rf
    }

    static [Runfiles] Create([string]$ScriptPath, [string]$SourceRepo) {
        $rf = [Runfiles]::Create($ScriptPath)
        $rf.SourceRepo = [Runfiles]::NormalizeRepo($SourceRepo)
        return $rf
    }

    # Walk the call stack to the first script outside this module.
    hidden static [string] DetectCallerScript() {
        foreach ($frame in (Get-PSCallStack)) {
            if ($frame.ScriptName -and
                $frame.ScriptName -notlike '*Runfiles.psm1' -and
                (Test-Path -LiteralPath $frame.ScriptName)) {
                return $frame.ScriptName
            }
        }
        return $null
    }

    # The main repository's canonical name is the empty string, but its runfiles
    # directory (and the value of REPOSITORY_NAME) is `_main`.
    hidden static [string] NormalizeRepo([string]$Repo) {
        if ($Repo -eq '_main') {
            return ''
        }
        return $Repo
    }

    hidden static [string] NormalizePath([string]$Path) {
        return $Path.Replace('\', '/')
    }

    hidden static [System.StringComparison] PathComparison() {
        if ($IsWindows) {
            return [System.StringComparison]::OrdinalIgnoreCase
        }
        return [System.StringComparison]::Ordinal
    }

    # Decode a field of an escaped manifest line. Escaped lines start with a space and
    # encode spaces as `\s`, newlines as `\n` and backslashes as `\b`. Every backslash in
    # an escaped field introduces an escape, so sequential replacement is safe as long
    # as `\b` is handled last.
    hidden static [string] UnescapeManifestField([string]$Value) {
        return $Value.Replace('\s', ' ').Replace('\n', "`n").Replace('\b', '\')
    }

    <#
    .SYNOPSIS
        Loads a runfiles manifest file.

    .PARAMETER ManifestPath
        The path to the manifest file to load.
    #>
    hidden [void] LoadManifest([string]$ManifestPath) {
        if (-not (Test-Path -LiteralPath $ManifestPath)) {
            throw "Manifest file not found: $ManifestPath"
        }

        foreach ($line in [System.IO.File]::ReadAllLines($ManifestPath)) {
            if ([string]::IsNullOrEmpty($line)) {
                continue
            }

            $escaped = $line.StartsWith(' ')
            if ($escaped) {
                $line = $line.Substring(1)
            }

            # Parse the manifest line: "rlocationpath realpath"
            $split = $line.IndexOf(' ')
            if ($split -lt 0) {
                continue
            }

            $rlocationPath = $line.Substring(0, $split)
            $realPath = $line.Substring($split + 1)
            if ($escaped) {
                $rlocationPath = [Runfiles]::UnescapeManifestField($rlocationPath)
                $realPath = [Runfiles]::UnescapeManifestField($realPath)
            }

            $this.ManifestMap[$rlocationPath] = $realPath
        }
    }

    # Load `_repo_mapping` if present. Each line is `source,apparent,target`.
    hidden [void] LoadRepoMapping() {
        $path = $this.RawRlocation('_repo_mapping')
        if (-not $path) {
            return
        }

        foreach ($line in [System.IO.File]::ReadAllLines($path)) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $parts = $line.Split(',', 3)
            if ($parts.Length -ne 3) {
                continue
            }
            $this.RepoMapping["$($parts[0]),$($parts[1])"] = $parts[2]
        }
    }

    # Translate the apparent repository name at the start of a path into the canonical
    # runfiles directory name. Paths that do not match any mapping are returned unchanged
    # so canonical names keep working.
    hidden [string] ApplyRepoMapping([string]$Path, [string]$SourceRepo) {
        if ($this.RepoMapping.Count -eq 0) {
            return $Path
        }

        $slash = $Path.IndexOf('/')
        if ($slash -lt 0) {
            return $Path
        }
        $apparent = $Path.Substring(0, $slash)
        $remainder = $Path.Substring($slash + 1)

        $key = "${SourceRepo},${apparent}"
        if ($this.RepoMapping.ContainsKey($key)) {
            return "$($this.RepoMapping[$key])/${remainder}"
        }

        # Compact manifests (--incompatible_compact_repo_mapping_manifest) key entries by
        # the source repository with its trailing version segment replaced by `*`.
        if ($SourceRepo -match '[^A-Za-z0-9_.\-]') {
            $prefix = ($SourceRepo -replace '[A-Za-z0-9_.\-]+$', '') + '*'
            $key = "${prefix},${apparent}"
            if ($this.RepoMapping.ContainsKey($key)) {
                return "$($this.RepoMapping[$key])/${remainder}"
            }
        }

        return $Path
    }

    # Resolve a canonical rlocationpath without applying the repo mapping.
    hidden [string] RawRlocation([string]$Path) {
        if ($this.ManifestMap.ContainsKey($Path)) {
            $resolved = $this.ManifestMap[$Path]
            if (Test-Path -LiteralPath $resolved) {
                return $resolved
            }
        }

        if ($this.RunfilesDir) {
            $resolved = Join-Path $this.RunfilesDir $Path
            if (Test-Path -LiteralPath $resolved) {
                return $resolved
            }
        }

        return $null
    }

    # Reverse lookup: find the rlocationpath of an absolute path inside the runfiles.
    hidden [string] RlocationpathOf([string]$AbsolutePath) {
        $normalized = [Runfiles]::NormalizePath($AbsolutePath)
        $comparison = [Runfiles]::PathComparison()

        if ($this.RunfilesDir) {
            $root = [Runfiles]::NormalizePath($this.RunfilesDir).TrimEnd('/') + '/'
            if ($normalized.StartsWith($root, $comparison)) {
                return $normalized.Substring($root.Length)
            }
        }

        foreach ($entry in $this.ManifestMap.GetEnumerator()) {
            if ([string]::Equals([Runfiles]::NormalizePath($entry.Value), $normalized, $comparison)) {
                return $entry.Key
            }
        }

        return $null
    }

    # Determine the canonical repository of the calling script, falling back to the
    # REPOSITORY_NAME variable set by `pwsh_binary`/`pwsh_test`, then to the main repository.
    hidden [string] InferSourceRepo([string]$ScriptPath) {
        if ($ScriptPath) {
            $rlocationpath = $this.RlocationpathOf($ScriptPath)
            if ($rlocationpath) {
                return [Runfiles]::NormalizeRepo($rlocationpath.Split('/')[0])
            }
        }

        if ($env:REPOSITORY_NAME) {
            return [Runfiles]::NormalizeRepo($env:REPOSITORY_NAME)
        }

        return ''
    }

    <#
    .SYNOPSIS
        Resolves a runfiles path to an absolute filesystem path.

    .PARAMETER Rlocationpath
        The runfiles path to resolve (e.g., "my_module/path/to/file.txt"). The first
        segment may be an apparent or a canonical repository name.

    .PARAMETER SourceRepo
        Optional. The canonical name of the repository whose repo mapping should be
        used. Defaults to the instance's SourceRepo.

    .RETURNS
        The absolute filesystem path to the runfile, or $null if not found.

    .EXAMPLE
        $runfiles = [Runfiles]::Create()
        $path = $runfiles.Rlocation("my_module/data/test.txt")
        if ($path) {
            $content = Get-Content $path
        }
    #>
    [string] Rlocation([string]$Rlocationpath) {
        return $this.Rlocation($Rlocationpath, $this.SourceRepo)
    }

    [string] Rlocation([string]$Rlocationpath, [string]$SourceRepo) {
        if ([string]::IsNullOrWhiteSpace($Rlocationpath)) {
            return $null
        }

        # Absolute paths are returned as-is when they exist.
        if ([System.IO.Path]::IsPathRooted($Rlocationpath)) {
            if (Test-Path -LiteralPath $Rlocationpath) {
                return $Rlocationpath
            }
            return $null
        }

        $mapped = $this.ApplyRepoMapping($Rlocationpath, [Runfiles]::NormalizeRepo($SourceRepo))
        return $this.RawRlocation($mapped)
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
        $path = $runfiles.Rlocation("my_module/path/to/file.txt")
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
        The runfiles path to resolve (e.g., "my_module/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use. If not provided,
        a cached module-level instance will be created and reused.

    .PARAMETER SourceRepo
        Optional. The canonical repository whose repo mapping should be used.

    .OUTPUTS
        System.String. The absolute path to the runfile, or $null if not found.

    .EXAMPLE
        $path = Get-Runfile "my_module/data/config.txt"
        if ($path) {
            $content = Get-Content $path
        }

    .EXAMPLE
        # Using pipeline
        "my_module/data/file.txt" | Get-Runfile

    .EXAMPLE
        # Using explicit runfiles instance
        $runfiles = New-Runfiles
        $path = Get-Runfile "my_module/file.txt" -Runfiles $runfiles
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles,

        [Parameter(Mandatory = $false)]
        [string]$SourceRepo
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

        if ($PSBoundParameters.ContainsKey('SourceRepo')) {
            return $rf.Rlocation($Path, $SourceRepo)
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
        The runfiles path to test (e.g., "my_module/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use. If not provided,
        a cached module-level instance will be created and reused.

    .PARAMETER SourceRepo
        Optional. The canonical repository whose repo mapping should be used.

    .OUTPUTS
        System.Boolean. $true if the runfile exists, $false otherwise.

    .EXAMPLE
        if (Test-Runfile "my_module/data/config.txt") {
            Write-Host "Config file exists"
        }

    .EXAMPLE
        # Using pipeline
        "my_module/file.txt" | Test-Runfile
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles,

        [Parameter(Mandatory = $false)]
        [string]$SourceRepo
    )

    process {
        $resolvedPath = Get-Runfile @PSBoundParameters
        if ($resolvedPath -and (Test-Path -LiteralPath $resolvedPath)) {
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
        The runfiles path to resolve (e.g., "my_module/path/to/file.txt").

    .PARAMETER Runfiles
        Optional. An existing Runfiles instance to use.

    .PARAMETER SourceRepo
        Optional. The canonical repository whose repo mapping should be used.

    .EXAMPLE
        $path = Resolve-Runfile "my_module/data/config.txt"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Runfiles]$Runfiles,

        [Parameter(Mandatory = $false)]
        [string]$SourceRepo
    )

    process {
        return Get-Runfile @PSBoundParameters
    }
}

# Only export when running as a module (not when embedded)
# When embedded, the class and function are already in scope
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function New-Runfiles, Get-Runfile, Test-Runfile, Resolve-Runfile
}
