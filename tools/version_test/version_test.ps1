<#
.SYNOPSIS
A suite of tests ensuring version strings are all in sync.
#>

using module Runfiles

function Main {
    # Locate files using the idiomatic PowerShell cmdlet interface
    # Try both possible workspace names
    $versionBzlPath = Get-Runfile "_main/version.bzl"
    if (-not $versionBzlPath) {
        $versionBzlPath = Get-Runfile "rules_powershell/version.bzl"
    }
    
    $moduleBazelPath = Get-Runfile "_main/MODULE.bazel"
    if (-not $moduleBazelPath) {
        $moduleBazelPath = Get-Runfile "rules_powershell/MODULE.bazel"
    }
    
    if (-not $versionBzlPath) {
        throw "Failed to locate version.bzl"
    }
    if (-not $moduleBazelPath) {
        throw "Failed to locate MODULE.bazel"
    }

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
