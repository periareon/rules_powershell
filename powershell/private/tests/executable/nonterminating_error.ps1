# A non-terminating error must not abort the script. `pwsh -File` exits 0 here, and the
# process wrapper must not leak its own `$ErrorActionPreference = 'Stop'` into user code.
Write-Error "This is a non-terminating error"
Write-Output "Continued after Write-Error"
