# rules_powershell

Bazel rules for [PowerShell](https://learn.microsoft.com/en-us/powershell/).

## Setup

To begin using the rules, add the following to your `MODULE.bazel` file:

```python
# Available versions can be found here: https://github.com/periareon/rules_powershell/releases
bazel_dep(name = "rules_powershell", version = "{version}")
```

### Toolchains

`rules_powershell` registers a default toolchain hub named `powershell_toolchains` for every
consumer. It downloads a pinned release of PowerShell for the current platform, so no further
setup is required to start using `pwsh_binary`, `pwsh_library` and `pwsh_test`.

To use a different version of PowerShell, declare a hub with a unique name through the
[`powershell.toolchain`](./bzlmod.md#toolchain) module extension and register it. Toolchains
registered by the root module take precedence over the default.
