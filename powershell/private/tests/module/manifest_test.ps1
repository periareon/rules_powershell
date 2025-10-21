# manifest_test.ps1
# Test that modules with manifests work properly

# Import module with manifest
Import-Module ModuleWithManifest -Force

# Test that manifest can be read
$version = Get-ModuleVersion
Write-Output "Module version: $version"

# Test module function
$result = Test-ManifestFeature
Write-Output "Manifest feature result: $result"

# Verify results
if ($version -ne "1.2.3") {
    Write-Error "Version mismatch: expected '1.2.3', got '$version'"
    exit 1
}

if ($result -ne "Manifest feature works!") {
    Write-Error "Unexpected result: '$result'"
    exit 1
}

Write-Output "Manifest test passed!"
exit 0

