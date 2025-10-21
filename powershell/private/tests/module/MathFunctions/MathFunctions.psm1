# MathFunctions.psm1
# A sample PowerShell module for testing module support

function Add-Numbers {
    <#
    .SYNOPSIS
    Adds two numbers together.
    
    .DESCRIPTION
    This function takes two numbers and returns their sum.
    
    .PARAMETER First
    The first number to add.
    
    .PARAMETER Second
    The second number to add.
    
    .EXAMPLE
    Add-Numbers -First 5 -Second 3
    Returns 8
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$First,
        
        [Parameter(Mandatory = $true)]
        [int]$Second
    )
    
    return $First + $Second
}

function Get-Product {
    <#
    .SYNOPSIS
    Multiplies two numbers together.
    
    .DESCRIPTION
    This function takes two numbers and returns their product.
    
    .PARAMETER First
    The first number to multiply.
    
    .PARAMETER Second
    The second number to multiply.
    
    .EXAMPLE
    Get-Product -First 5 -Second 3
    Returns 15
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$First,
        
        [Parameter(Mandatory = $true)]
        [int]$Second
    )
    
    return $First * $Second
}

function Get-ModuleGreeting {
    <#
    .SYNOPSIS
    Returns a greeting message.
    
    .DESCRIPTION
    This function returns a simple greeting message to verify module loading.
    
    .EXAMPLE
    Get-ModuleGreeting
    Returns "Hello from MathFunctions module!"
    #>
    return "Hello from MathFunctions module!"
}

# Export module members
Export-ModuleMember -Function Add-Numbers, Get-Product, Get-ModuleGreeting

