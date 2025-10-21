# cross_dir_test.ps1
# Test importing modules from different directories

# Try to import a module from the same directory
Import-Module MathFunctions -Force

# Try to import a module from a subdirectory
Import-Module SubdirModule -Force

# Test both modules work
$mathResult = Add-Numbers -First 5 -Second 3
$subdirMessage = Get-SubdirMessage

Write-Output "Math result: $mathResult"
Write-Output "Subdir message: $subdirMessage"

# Verify results
if ($mathResult -ne 8) {
    Write-Error "Math test failed: expected 8, got $mathResult"
    exit 1
}

if ($subdirMessage -ne "Hello from SubdirModule!") {
    Write-Error "Subdir test failed: unexpected message '$subdirMessage'"
    exit 1
}

Write-Output "Cross-directory module test passed!"
exit 0

