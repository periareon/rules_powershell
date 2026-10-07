# Tests for the runfiles library

# Use 'using module' to import classes (must be at the top, before param)
using module Runfiles

param()

$ErrorActionPreference = "Stop"

$ModuleRlocation = "powershell/runfiles/Runfiles/Runfiles.psm1"

function Test-CreateRunfilesInstance {
    Write-Host "Test 1: Creating runfiles instance..."
    $runfiles = [Runfiles]::Create()
    Write-Host "  ok: Runfiles instance created successfully"
    return $runfiles
}

function Test-RlocationMethod {
    param([Runfiles]$Runfiles)

    Write-Host "Test 2: Resolving a canonical path with Rlocation..."
    $path = $Runfiles.Rlocation("_main/$ModuleRlocation")
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        throw "Rlocation failed to resolve _main/$ModuleRlocation"
    }
    Write-Host "  ok: resolved to $path"
}

function Test-NewRunfilesFunction {
    Write-Host "Test 3: Testing New-Runfiles convenience function..."
    $runfiles = New-Runfiles
    if (-not $runfiles) {
        throw "New-Runfiles returned nothing"
    }
    Write-Host "  ok: New-Runfiles works"
}

function Test-GetRunfileCmdlet {
    Write-Host "Test 4: Testing Get-Runfile cmdlet..."
    $path = Get-Runfile "_main/$ModuleRlocation"
    if (-not $path) {
        throw "Get-Runfile returned nothing"
    }
    Write-Host "  ok: Get-Runfile works"
}

function Test-TestRunfileCmdlet {
    Write-Host "Test 5: Testing Test-Runfile cmdlet..."
    if ((Test-Runfile "_main/$ModuleRlocation") -ne $true) {
        throw "Test-Runfile should return true for existing file"
    }
    if ((Test-Runfile "_main/nonexistent_file_12345.txt") -ne $false) {
        throw "Test-Runfile should return false for nonexistent file"
    }
    Write-Host "  ok: Test-Runfile distinguishes existing and missing files"
}

function Test-ResolveRunfileAlias {
    Write-Host "Test 6: Testing Resolve-Runfile alias..."
    if (-not (Resolve-Runfile -Path "_main/$ModuleRlocation")) {
        throw "Resolve-Runfile should work"
    }
    Write-Host "  ok: Resolve-Runfile works (alias for Get-Runfile)"
}

function Test-PipelineSupport {
    Write-Host "Test 7: Testing pipeline support..."
    if (-not ("_main/$ModuleRlocation" | Get-Runfile)) {
        throw "Pipeline should work with Get-Runfile"
    }
    Write-Host "  ok: Pipeline support works"
}

function Test-RepoMapping {
    Write-Host "Test 8: Resolving an apparent repository name through _repo_mapping..."
    $canonical = Get-Runfile "_main/$ModuleRlocation"
    $apparent = Get-Runfile "rules_powershell/$ModuleRlocation"
    if (-not $apparent) {
        throw "Expected the apparent name 'rules_powershell' to resolve via _repo_mapping"
    }
    if ($apparent -ne $canonical) {
        throw "Apparent and canonical names resolved differently: '$apparent' vs '$canonical'"
    }
    Write-Host "  ok: apparent repository names are mapped"
}

function Test-SourceRepoInference {
    param([Runfiles]$Runfiles)

    Write-Host "Test 9: Inferring the source repository of the calling script..."
    if ($Runfiles.SourceRepo -ne '') {
        throw "Expected the main repository (empty string) but got '$($Runfiles.SourceRepo)'"
    }
    Write-Host "  ok: source repository is the main repository"
}

function Main {
    try {
        $runfiles = Test-CreateRunfilesInstance
        Test-RlocationMethod -Runfiles $runfiles
        Test-NewRunfilesFunction
        Test-GetRunfileCmdlet
        Test-TestRunfileCmdlet
        Test-ResolveRunfileAlias
        Test-PipelineSupport
        Test-RepoMapping
        Test-SourceRepoInference -Runfiles $runfiles

        Write-Host ""
        Write-Host "All tests passed!"
    } catch {
        Write-Error "Test failed: $_"
        exit 1
    }
}

Main
