# rules_powershell

Bazel rules for [PowerShell](https://learn.microsoft.com/en-us/powershell/).

`rules_powershell` is a set of Bazel rules that bring the same functionality as
[`rules_shell`](https://github.com/bazelbuild/rules_shell), but designed for
PowerShell. These rules make it possible to write and run build actions,
tests, and entrypoints in PowerShell while integrating cleanly with Bazel’s
sandboxing, toolchains, and reproducibility guarantees.

The goal is feature parity with `rules_shell`, so you can use PowerShell
scripts as first-class citizens in your Bazel builds without special casing.

## Documentation

<https://periareon.github.io/rules_powershell/>
