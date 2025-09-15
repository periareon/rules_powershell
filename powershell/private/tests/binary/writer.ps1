<#
.SYNOPSIS
A small test script.

.DESCRIPTION
Parses command-line arguments and writes a message to the specified output file,
creating parent directories if necessary.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Output
)

function Main {
    param (
        [string]$Output
    )

    # Ensure parent directory exists
    $parentDir = Split-Path -Parent $Output
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Write text as UTF-8 bytes
    $text = "La-Li-Lu-Le-Lo.`n"
    [System.IO.File]::WriteAllBytes($Output, [System.Text.Encoding]::UTF8.GetBytes($text))
}

Main -Output $Output
