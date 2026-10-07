# Verifies that arguments pass through the launcher and process wrapper intact.

param(
    [Parameter(Mandatory = $true)]
    [string]$First,

    [Parameter(Mandatory = $true)]
    [string]$Second
)

if ($First -ne 'Hello, World!') {
    throw "Unexpected value for -First: '$First'"
}

if ($Second -ne 'a b c') {
    throw "Unexpected value for -Second: '$Second'"
}

Write-Output "Arguments received intact."
