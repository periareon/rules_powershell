# SubdirModule.psm1
# A module in a subdirectory to test cross-directory imports

function Get-SubdirMessage {
    <#
    .SYNOPSIS
    Returns a message from the subdirectory module.
    #>
    return "Hello from SubdirModule!"
}

Export-ModuleMember -Function Get-SubdirMessage

