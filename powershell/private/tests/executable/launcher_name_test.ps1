# Only reachable if the launcher ran the process wrapper rather than the vendored
# runfiles library's standalone entry point.
Write-Output "Launcher named $($MyInvocation.MyCommand.Name) ran the script."
