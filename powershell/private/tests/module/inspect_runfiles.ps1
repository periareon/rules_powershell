# inspect_runfiles.ps1
# Inspect the runfiles structure

Write-Output "=== PSModulePath ==="
$env:PSModulePath -split ':' | ForEach-Object { Write-Output "  $_" }

Write-Output "`n=== Script Location ==="
$scriptPath = $MyInvocation.MyCommand.Path
Write-Output "Script: $scriptPath"

$scriptDir = Split-Path -Parent $scriptPath
Write-Output "Script Dir: $scriptDir"

Write-Output "`n=== Files in Script Directory ==="
Get-ChildItem $scriptDir -Recurse | Select-Object FullName, PSIsContainer | ForEach-Object {
    if ($_.PSIsContainer) {
        Write-Output "[DIR]  $($_.FullName)"
    } else {
        Write-Output "[FILE] $($_.FullName)"
    }
}

Write-Output "`n=== Available Modules ==="
Get-Module -ListAvailable | Select-Object Name, Path | ForEach-Object {
    Write-Output "$($_.Name): $($_.Path)"
}

exit 0

