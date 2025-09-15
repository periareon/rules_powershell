<#
.SYNOPSIS
A script for rendering a `pwsh_*` executable's entrypoint.

.DESCRIPTION
This script takes a template file, applies text substitutions, and writes
the result to an output file. Some substitutions can come from JSON-encoded
files whose contents are inlined with a vendor template.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [Parameter(Mandatory = $true)]
    [string]$TemplateFile,

    [Parameter(Mandatory = $true)]
    [string]$SubstitutionsFile
)

# Parse JSON input arguments
$json = Get-Content -LiteralPath $SubstitutionsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$substitutions = $json.substitutions
$fileSubstitutions = $json.file_substitutions

# Vendor template format
$VENDORED_TEMPLATE = @"
################################################################################
## rules_powershell vendor: {0}
################################################################################
{1}
################################################################################
## rules_powershell end vendor: {0}
################################################################################
"@

# Read template content
$content = Get-Content -LiteralPath $TemplateFile -Raw -Encoding UTF8

# Apply direct substitutions
foreach ($key in $substitutions.PSObject.Properties.Name) {
    $value = $substitutions.$key
    $content = $content.Replace($key, $value)
}

# Apply file substitutions
foreach ($key in $fileSubstitutions.PSObject.Properties.Name) {
    $file = $fileSubstitutions.$key
    if (-not (Test-Path -LiteralPath $file)) {
        Write-Error "File substitution path does not exist: $file"
        continue
    }
    $value = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $vendored = $VENDORED_TEMPLATE.Replace('{0}', $file).Replace('{1}', $value)
    $content = $content.Replace($key, $vendored)
}

# Ensure output directory exists
$parent = Split-Path -Parent $OutputFile
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

# Write content
Set-Content -LiteralPath $OutputFile -Value $content -Encoding UTF8

# Make file executable (best effort: sets +x on *nix, ignored on Windows)
if ($IsLinux -or $IsMacOS) {
    $chmod = Get-Command chmod -ErrorAction SilentlyContinue
    if ($chmod) {
        & $chmod.Source +x $OutputFile
    }
}
