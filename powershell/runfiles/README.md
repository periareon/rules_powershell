# PowerShell Runfiles Library

This library provides a PowerShell implementation of the Bazel runfiles mechanism, allowing PowerShell scripts to locate data dependencies at runtime.

## Usage

### In a PowerShell Binary or Test

To use the runfiles library in your PowerShell script, you need to:

1. Add the runfiles library as a dependency
2. Use `using module Runfiles` at the top of your script (before `param()`)
3. Create a runfiles instance and use it to resolve paths

#### Example

**BUILD.bazel:**

```python
load("@rules_powershell//powershell:defs.bzl", "pwsh_binary")

pwsh_binary(
    name = "my_script",
    srcs = ["my_script.ps1"],
    data = ["data/config.txt"],
    deps = ["@rules_powershell//powershell/runfiles"],
)
```

**my_script.ps1:**

```powershell
# Import the Runfiles module (must be at the very top, before param())
using module Runfiles

param()

$ErrorActionPreference = "Stop"

# Create a runfiles instance
$runfiles = [Runfiles]::Create()

# Resolve a runfile path. `my_module` is the name given to `module(name = ...)`
# in MODULE.bazel; `_main` also works for the root module.
$configPath = $runfiles.Rlocation("my_module/data/config.txt")

if ($configPath -and (Test-Path $configPath)) {
    $config = Get-Content $configPath
    Write-Host "Config: $config"
} else {
    Write-Error "Could not find config file"
}
```

The cmdlets `Get-Runfile`, `Test-Runfile` and `Resolve-Runfile` wrap a cached instance for convenience:

```powershell
$configPath = Get-Runfile "my_module/data/config.txt"
```

## Repository names

Under bzlmod, runfiles are laid out by *canonical* repository name: `_main` for the root module and
names such as `rules_powershell+` for dependencies. The library reads the `_repo_mapping` file that
Bazel ships with every executable, so the *apparent* names you use in `MODULE.bazel` (your own module
name, or the names passed to `bazel_dep`) can be used instead and will be translated automatically.

The mapping depends on which repository the calling code lives in. This is inferred from the script
that calls into the library, and can be overridden with `[Runfiles]::Create($null, "<canonical repo>")`
or the `-SourceRepo` parameter of the cmdlets.

## Notes

- When using classes from PowerShell modules, you must use `using module ModuleName` instead of `Import-Module ModuleName`
- The `using` statement must appear at the very top of the script, before any other code (including `param()` blocks)
