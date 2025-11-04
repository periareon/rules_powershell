# ModuleWithManifest.psm1
# A module with a proper manifest file

function Get-ModuleVersion {
    <#
    .SYNOPSIS
    Returns the module version from the manifest.
    #>
    $manifest = Import-PowerShellDataFile "$PSScriptRoot/ModuleWithManifest.psd1"
    return $manifest.ModuleVersion
}

function Test-ManifestFeature {
    <#
    .SYNOPSIS
    Tests that the manifest feature works.
    #>
    return "Manifest feature works!"
}

Export-ModuleMember -Function Get-ModuleVersion, Test-ManifestFeature

