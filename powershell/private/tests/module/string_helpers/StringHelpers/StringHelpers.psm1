# StringHelpers.psm1
# A sample PowerShell module for testing module support

function Join-Strings {
    <#
    .SYNOPSIS
    Joins strings with a separator.
    
    .PARAMETER Strings
    Array of strings to join.
    
    .PARAMETER Separator
    The separator to use between strings. Defaults to a space.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Strings,
        
        [Parameter(Mandatory = $false)]
        [string]$Separator = " "
    )
    
    return $Strings -join $Separator
}

function Get-ReversedString {
    <#
    .SYNOPSIS
    Reverses a string.
    
    .PARAMETER InputString
    The string to reverse.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString
    )
    
    $chars = $InputString.ToCharArray()
    [Array]::Reverse($chars)
    return -join $chars
}

# Export module members
Export-ModuleMember -Function Join-Strings, Get-ReversedString

