# Simple test for the runfiles library

# Use 'using module' to import classes (must be at the top, before param)
using module Runfiles

param()

# Error handling
$ErrorActionPreference = "Stop"

function Test-CreateRunfilesInstance {
    <#
    .SYNOPSIS
        Test creating a runfiles instance
    #>
    Write-Host "Test 1: Creating runfiles instance..."
    $runfiles = [Runfiles]::Create()
    Write-Host "  ✓ Runfiles instance created successfully"
    return $runfiles
}

function Test-RlocationMethod {
    <#
    .SYNOPSIS
        Test that the runfiles object has the expected methods
    #>
    param([Runfiles]$Runfiles)
    
    Write-Host "Test 2: Checking Rlocation method exists..."
    if ($Runfiles.PSObject.Methods['Rlocation']) {
        Write-Host "  ✓ Rlocation method exists"
    } else {
        throw "Rlocation method not found"
    }
}

function Test-NewRunfilesFunction {
    <#
    .SYNOPSIS
        Test the New-Runfiles convenience function
    #>
    Write-Host "Test 3: Testing New-Runfiles convenience function..."
    $runfiles = New-Runfiles
    Write-Host "  ✓ New-Runfiles works"
}

function Test-GetRunfileCmdlet {
    <#
    .SYNOPSIS
        Test the Get-Runfile cmdlet
    #>
    Write-Host "Test 4: Testing Get-Runfile cmdlet..."
    $path = Get-Runfile "_main/powershell/runfiles/Runfiles/Runfiles.psm1"
    Write-Host "  ✓ Get-Runfile works: path type is $($path.GetType().Name)"
}

function Test-TestRunfileCmdlet {
    <#
    .SYNOPSIS
        Test the Test-Runfile cmdlet
    #>
    Write-Host "Test 5: Testing Test-Runfile cmdlet..."
    
    # This file should exist (the module itself)
    $exists = Test-Runfile "_main/powershell/runfiles/Runfiles/Runfiles.psm1"
    if ($exists -ne $true) {
        throw "Test-Runfile should return true for existing file"
    }
    Write-Host "  ✓ Test-Runfile correctly returned true for existing file"
    
    # This file should not exist
    $exists2 = Test-Runfile "_main/nonexistent_file_12345.txt"
    if ($exists2 -ne $false) {
        throw "Test-Runfile should return false for nonexistent file"
    }
    Write-Host "  ✓ Test-Runfile correctly returned false for nonexistent file"
}

function Test-ResolveRunfileAlias {
    <#
    .SYNOPSIS
        Test the Resolve-Runfile alias
    #>
    Write-Host "Test 6: Testing Resolve-Runfile alias..."
    $path = Resolve-Runfile "_main/powershell/runfiles/Runfiles/Runfiles.psm1"
    if (-not $path) {
        throw "Resolve-Runfile should work"
    }
    Write-Host "  ✓ Resolve-Runfile works (alias for Get-Runfile)"
}

function Test-PipelineSupport {
    <#
    .SYNOPSIS
        Test pipeline support for cmdlets
    #>
    Write-Host "Test 7: Testing pipeline support..."
    $path = "_main/powershell/runfiles/Runfiles/Runfiles.psm1" | Get-Runfile
    if (-not $path) {
        throw "Pipeline should work with Get-Runfile"
    }
    Write-Host "  ✓ Pipeline support works"
}

function Main {
    <#
    .SYNOPSIS
        Run all tests
    #>
    try {
        $runfiles = Test-CreateRunfilesInstance
        Test-RlocationMethod -Runfiles $runfiles
        Test-NewRunfilesFunction
        Test-GetRunfileCmdlet
        Test-TestRunfileCmdlet
        Test-ResolveRunfileAlias
        Test-PipelineSupport
        
        Write-Host ""
        Write-Host "All tests passed!"
    } catch {
        Write-Error "Test failed: $_"
        exit 1
    }
}

# Run the tests
Main
