# debug_psmodulepath.ps1
# Debug script to check PSModulePath structure

Write-Output "=== PSModulePath ==="
$env:PSModulePath -split ':' | ForEach-Object { Write-Output "  $_" }

Write-Output "`n=== Checking each path ==="
$env:PSModulePath -split ':' | ForEach-Object {
    $path = $_
    if (Test-Path $path) {
        Write-Output "`nPath: $path"
        Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Output "  [DIR] $($_.Name)"
            $modulePath = Join-Path $_.FullName "$($_.Name).psm1"
            if (Test-Path $modulePath) {
                Write-Output "    -> Has $($_.Name).psm1"
            }
        }
    }
}

Write-Output "`n=== Attempting Import ==="
try {
    Import-Module MathFunctions -Force -ErrorAction Stop
    Write-Output "✓ Successfully imported MathFunctions"
} catch {
    Write-Output "✗ Failed to import MathFunctions: $_"
}

exit 0

