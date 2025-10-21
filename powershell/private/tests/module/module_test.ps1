# module_test.ps1
# Test script that imports and tests both modules

# Import the modules by name
Import-Module MathFunctions -Force
Import-Module StringHelpers -Force

# Test MathFunctions
$sum = Add-Numbers -First 100 -Second 50
if ($sum -ne 150) {
    Write-Error "MathFunctions.Add-Numbers failed: expected 150, got $sum"
    exit 1
}

$product = Get-Product -First 6 -Second 9
if ($product -ne 54) {
    Write-Error "MathFunctions.Get-Product failed: expected 54, got $product"
    exit 1
}

# Test StringHelpers
$joined = Join-Strings -Strings @("Hello", "World") -Separator ", "
if ($joined -ne "Hello, World") {
    Write-Error "StringHelpers.Join-Strings failed: expected 'Hello, World', got '$joined'"
    exit 1
}

$reversed = Get-ReversedString -InputString "Bazel"
if ($reversed -ne "lezaB") {
    Write-Error "StringHelpers.Get-ReversedString failed: expected 'lezaB', got '$reversed'"
    exit 1
}

Write-Output "All module tests passed successfully!"
exit 0

