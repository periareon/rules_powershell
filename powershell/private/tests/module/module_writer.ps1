# module_writer.ps1
# Binary that uses modules to write output to a file

param(
    [Parameter(Mandatory = $true)]
    [string]$Output
)

# Import the modules by name
Import-Module MathFunctions -Force
Import-Module StringHelpers -Force

# Use module functions
$sum = Add-Numbers -First 42 -Second 8
$product = Get-Product -First 5 -Second 10
$joined = Join-Strings -Strings @("Rules", "PowerShell") -Separator "_"
$reversed = Get-ReversedString -InputString $joined

# Write to output file with Unix line endings (LF)
$text = "Sum: $sum`nProduct: $product`nJoined: $joined`nReversed: $reversed`n"
[System.IO.File]::WriteAllBytes($Output, [System.Text.Encoding]::UTF8.GetBytes($text))

