#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Process wrapper for rules_powershell executables.

.DESCRIPTION
    Configures the PowerShell environment for a `pwsh_binary` or `pwsh_test` by:
    - Resolving the config file and main script through the runfiles directory or manifest
    - Prepending the module directories of all dependencies to `PSModulePath`
    - Running the main script so that `param()`, `exit` and error handling behave
      exactly as they would under `pwsh -File`

    Every helper defined here carries a `RulesPowerShell` infix so it cannot collide with
    commands defined by user scripts or modules.
#>

$ErrorActionPreference = 'Stop'

# The parsed runfiles manifest, loaded lazily and at most once.
$script:RulesPowerShellManifest = $null

function ConvertFrom-RulesPowerShellManifestField {
    <#
    .SYNOPSIS
        Decode a field of an escaped runfiles manifest line.
    .DESCRIPTION
        Bazel escapes manifest lines that contain special characters: such lines start
        with a space and encode spaces as `\s`, newlines as `\n` and backslashes as `\b`.
        Every backslash in an escaped field introduces an escape, so the replacements can
        be applied in sequence as long as `\b` is handled last.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value.Replace('\s', ' ').Replace('\n', "`n").Replace('\b', '\')
}

function Read-RulesPowerShellManifest {
    <#
    .SYNOPSIS
        Parse a runfiles manifest into a hashtable of rlocationpath -> absolute path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $map = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ([string]::IsNullOrEmpty($line)) {
            continue
        }

        $escaped = $line.StartsWith(' ')
        if ($escaped) {
            $line = $line.Substring(1)
        }

        $split = $line.IndexOf(' ')
        if ($split -lt 0) {
            continue
        }

        $key = $line.Substring(0, $split)
        $value = $line.Substring($split + 1)
        if ($escaped) {
            $key = ConvertFrom-RulesPowerShellManifestField $key
            $value = ConvertFrom-RulesPowerShellManifestField $value
        }

        $map[$key] = $value
    }

    return $map
}

function Resolve-RulesPowerShellRunfile {
    <#
    .SYNOPSIS
        Resolve an rlocationpath to an absolute path using RUNFILES_DIR or RUNFILES_MANIFEST_FILE.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RlocationPath
    )

    if ($env:RUNFILES_DIR) {
        $candidate = Join-Path $env:RUNFILES_DIR $RlocationPath
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    if ($env:RUNFILES_MANIFEST_FILE -and (Test-Path -LiteralPath $env:RUNFILES_MANIFEST_FILE)) {
        if ($null -eq $script:RulesPowerShellManifest) {
            $script:RulesPowerShellManifest = Read-RulesPowerShellManifest $env:RUNFILES_MANIFEST_FILE
        }
        if ($script:RulesPowerShellManifest.ContainsKey($RlocationPath)) {
            return $script:RulesPowerShellManifest[$RlocationPath]
        }
    }

    # Not found in runfiles. The value may already be an absolute path.
    return $RlocationPath
}

function Initialize-RulesPowerShellEnvironment {
    <#
    .SYNOPSIS
        Configure PSModulePath from the config file and return the path to the main script.
    #>
    foreach ($name in @('RULES_POWERSHELL_CONFIG', 'RULES_POWERSHELL_MAIN')) {
        if (-not [System.Environment]::GetEnvironmentVariable($name)) {
            throw "$name environment variable is not set"
        }
    }

    $configPath = Resolve-RulesPowerShellRunfile $env:RULES_POWERSHELL_CONFIG
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Config file not found: $configPath"
    }

    $mainPath = Resolve-RulesPowerShellRunfile $env:RULES_POWERSHELL_MAIN
    if (-not (Test-Path -LiteralPath $mainPath)) {
        throw "Main script not found: $mainPath"
    }

    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

    # Each import is `<parent>/<ModuleName>/<ModuleName>.psm1`; `<parent>` is what
    # belongs on PSModulePath. Preserve order and avoid duplicates.
    $moduleDirs = [System.Collections.Generic.List[string]]::new()
    foreach ($importPath in @($config.imports | Where-Object { $_ })) {
        $moduleFile = Resolve-RulesPowerShellRunfile $importPath
        if (-not (Test-Path -LiteralPath $moduleFile)) {
            continue
        }

        $parentDir = Split-Path -Parent (Split-Path -Parent $moduleFile)
        if ($parentDir -and -not $moduleDirs.Contains($parentDir)) {
            $moduleDirs.Add($parentDir)
        }
    }

    if ($moduleDirs.Count -gt 0) {
        $separator = [System.IO.Path]::PathSeparator
        $newPaths = $moduleDirs -join $separator
        if ($env:PSModulePath) {
            $env:PSModulePath = "${newPaths}${separator}$($env:PSModulePath)"
        } else {
            $env:PSModulePath = $newPaths
        }
    }

    return $mainPath
}

$RulesPowerShellMain = Initialize-RulesPowerShellEnvironment

# Restore PowerShell's default so the user's script runs with the same preferences
# it would have under `pwsh -File`, rather than inheriting `Stop` from this wrapper.
$ErrorActionPreference = 'Continue'

# Run the script and reproduce the exit code `pwsh -File` would have given it:
#   - `exit N` inside the script becomes the process exit code,
#   - an uncaught terminating error exits 1 (it propagates out of this wrapper),
#   - a script that fails to parse, including one whose `using module` statement
#     fails, exits 1,
#   - anything else exits 0, regardless of `$LASTEXITCODE` left behind by native
#     commands the script ran.
#
# A nested script's `exit N` only ends that script; it leaves `$?` false and
# `$LASTEXITCODE` set to N. A parse failure likewise only fails the call itself,
# recording a ParseException. Both have to be turned into exit codes here.
$global:LASTEXITCODE = 0
$RulesPowerShellErrorCount = $Error.Count
& $RulesPowerShellMain @args
$RulesPowerShellSucceeded = $?

if (-not $RulesPowerShellSucceeded) {
    if ($Error.Count -gt $RulesPowerShellErrorCount -and
        $Error[0].Exception -is [System.Management.Automation.ParseException]) {
        exit 1
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
