# rules_powershell

Bazel rules for [PowerShell](https://learn.microsoft.com/en-us/powershell/).

## Setup

To begin using the rules, add the following to your `MODULE.bazel` file:

```python
# Available versions can be found here: https://github.com/periareon/rules_powershell/releases
bazel_dep(name = "rules_powershell", version = "{version}")
```

### Toolchains

By default no toolchain is registered for the rules. To register toolchains, see the module extension [`powershell.toolchain`](./bzlmod.md#toolchain)
