<#
.SYNOPSIS
A suite of tests ensuring version strings are all in sync.
#>

# Helper function to locate runfiles
# TODO: https://github.com/periareon/rules_powershell/issues/1
function Get-Runfile {
    param(
        [string]$RlocationPath
    )

    # Base directory: the script location (like Python's __file__)
    $scriptDir = Split-Path -Parent $PSCommandPath

    # Move up three directories
    $parent1 = Split-Path -Parent $scriptDir
    $parent2 = Split-Path -Parent $parent1
    $parent3 = Split-Path -Parent $parent2

    # Combine with the original path
    $runfile = Join-Path -Path $parent3 -ChildPath $RlocationPath

    # If it exists, return it
    if (Test-Path $runfile) {
        return $runfile
    }

    # If not, try replacing 'rules_powershell' with '_main' at the start
    if ($RlocationPath -like "rules_powershell*") {
        $altPath = $RlocationPath -replace "^rules_powershell", "_main"
        $runfileAlt = Join-Path -Path $parent3 -ChildPath $altPath
        if (Test-Path $runfileAlt) {
            return $runfileAlt
        }
    }

    # If neither exists, throw an error
    throw "Runfile does not exist: ($RlocationPath)"
}

function Main {
    # Locate files
    $versionBzlPath = Get-Runfile "rules_powershell/version.bzl"
    $moduleBazelPath = Get-Runfile "rules_powershell/MODULE.bazel"

    # Read file contents
    $versionBzlText = Get-Content -Path $versionBzlPath -Raw -Encoding UTF8
    $moduleBazelText = Get-Content -Path $moduleBazelPath -Raw -Encoding UTF8

    # Extract versions using regex
    $bzlVersionMatch = [regex]::Match($versionBzlText, 'VERSION\s*=\s*"([\w\d\.]+)"')
    if (-not $bzlVersionMatch.Success) {
        throw "Failed to parse version from $versionBzlPath"
    }

    $moduleVersionMatch = [regex]::Match($moduleBazelText, 'module\(\s*name\s*=\s*"rules_powershell",\s*version\s*=\s*"([\d\w\.]+)",')
    if (-not $moduleVersionMatch.Success) {
        throw "Failed to parse version from $moduleBazelPath"
    }

    # Compare versions
    if ($bzlVersionMatch.Groups[1].Value -ne $moduleVersionMatch.Groups[1].Value) {
        throw "Version mismatch: $($bzlVersionMatch.Groups[1].Value) != $($moduleVersionMatch.Groups[1].Value)"
    }

    Write-Output "Test passed: Versions match ($($bzlVersionMatch.Groups[1].Value))"
}

Main
