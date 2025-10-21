# use_module.ps1
# Script that uses the MathFunctions module

# Import the MathFunctions module by name
Import-Module MathFunctions -Force

# Use the module functions
$sum = Add-Numbers -First 10 -Second 5
$product = Get-Product -First 4 -Second 7
$greeting = Get-ModuleGreeting

Write-Output "Sum: $sum"
Write-Output "Product: $product"
Write-Output "Greeting: $greeting"

# Verify results
if ($sum -ne 15) {
    Write-Error "Addition failed: expected 15, got $sum"
    exit 1
}

if ($product -ne 28) {
    Write-Error "Multiplication failed: expected 28, got $product"
    exit 1
}

if ($greeting -ne "Hello from MathFunctions module!") {
    Write-Error "Greeting failed: unexpected message '$greeting'"
    exit 1
}

Write-Output "All module tests passed!"
exit 0

