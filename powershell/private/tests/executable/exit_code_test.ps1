# Runs sibling `pwsh_binary` launchers and checks that their exit codes propagate.

using module Runfiles

param()

$ErrorActionPreference = 'Stop'

$extension = if ($IsWindows) { '.bat' } else { '.sh' }

function Invoke-Launcher {
    param([string]$Name)

    $launcher = Get-Runfile "_main/powershell/private/tests/executable/${Name}${extension}"
    if (-not $launcher) {
        throw "Unable to locate the launcher for '$Name' in runfiles"
    }

    Write-Host "Running $launcher"
    & $launcher | Out-Null
    return $LASTEXITCODE
}

$expected = [ordered]@{
    'exit_42'              = 42
    'nonterminating_error' = 0
    'terminating_error'    = 1
    'parse_error'          = 1
    'missing_module'       = 1
}

$checked = 0
foreach ($name in $expected.Keys) {
    $code = Invoke-Launcher $name
    if ($code -ne $expected[$name]) {
        throw "'$name' exited with $code, expected $($expected[$name])"
    }
    Write-Output "'$name' exited with $code as expected"
    $checked++
}

if ($checked -ne $expected.Count) {
    throw "Only $checked of $($expected.Count) launchers were checked"
}

Write-Output "All exit code tests passed."
