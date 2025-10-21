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

# Write to output file
$content = @"
Sum: $sum
Product: $product
Joined: $joined
Reversed: $reversed
"@

Set-Content -Path $Output -Value $content -NoNewline

