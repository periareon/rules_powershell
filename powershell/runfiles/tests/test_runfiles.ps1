# Simple test for the runfiles library

# Use 'using module' to import classes (must be at the top, before param)
using module Runfiles

param()

# Error handling
$ErrorActionPreference = "Stop"

# Test 1: Create a runfiles instance
Write-Host "Test 1: Creating runfiles instance..."
try {
    $runfiles = [Runfiles]::Create()
    Write-Host "Runfiles instance created successfully"
} catch {
    Write-Error "Failed to create runfiles instance: $_"
    exit 1
}

# Test 2: Test that the runfiles object has the expected methods
Write-Host "Test 2: Checking Rlocation method exists..."
if ($runfiles.PSObject.Methods['Rlocation']) {
    Write-Host "Rlocation method exists"
} else {
    Write-Error "Rlocation method not found"
    exit 1
}

# Test 3: Test convenience function
Write-Host "Test 3: Testing New-Runfiles convenience function..."
try {
    $runfiles2 = New-Runfiles
    Write-Host "New-Runfiles works"
} catch {
    Write-Error "New-Runfiles failed: $_"
    exit 1
}

Write-Host ""
Write-Host "All tests passed!"
