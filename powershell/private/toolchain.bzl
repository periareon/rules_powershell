"""Powershell toolchain"""

load(":utils.bzl", "rlocationpath")

TOOLCHAIN_TYPE = str(Label("//powershell:toolchain_type"))

def _pwsh_toolchain_impl(ctx):
    all_files = []
    if DefaultInfo in ctx.attr.pwsh:
        all_files.extend([
            ctx.attr.pwsh[DefaultInfo].files,
            ctx.attr.pwsh[DefaultInfo].default_runfiles.files,
        ])

    make_variable_info = platform_common.TemplateVariableInfo({
        "PWSH": ctx.executable.pwsh.path,
        "PWSH_RLOCATIONPATH": rlocationpath(ctx, ctx.executable.pwsh),
    })

    return [
        platform_common.ToolchainInfo(
            pwsh = ctx.executable.pwsh,
            all_files = depset(transitive = all_files),
            make_variable_info = make_variable_info,
        ),
    ]

pwsh_toolchain = rule(
    doc = """\
A toolchain for providing Powershell to Bazel rules.

Example:

```python
load("@rules_powershell//powershell:pwsh_toolchain.bzl", "pwsh_toolchain")

filegroup(
    name = "powershell_bin",
    srcs = ["powershell/pwsh"],
    # Note that additional runfiles associated with a hermetic archive
    # of powershell should be associated with the target passed to the
    # `pwsh` attribute. The executable itself must carry the executable
    # bit; the upstream unix archives do not set it.
    data = glob(["powershell/**"]),
)

pwsh_toolchain(
    name = "pwsh_toolchain",
    pwsh = ":powershell_bin",
    visibility = ["//visibility:public"],
)
```

For users looking to use a system install of Powershell, a shell/batch script
should be added that points to the system install.

Example of a non-hermetic toolchain:

`pwsh.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/pwsh "$@"
```

`pwsh.bat`
```batch
@ECHO OFF
"C:\\Program Files\\PowerShell\\7\\pwsh.exe" %*
exit /b %ERRORLEVEL%
```

```python
load("@rules_powershell//powershell:pwsh_toolchain.bzl", "pwsh_toolchain")

filegroup(
    name = "powershell_bin",
    srcs = select({
        "@platforms//os:windows": ["pwsh.bat"],
        "//conditions:default": ["pwsh.sh"],
    }),
)

pwsh_toolchain(
    name = "pwsh_toolchain",
    pwsh = ":powershell_bin",
    visibility = ["//visibility:public"],
)
```
""",
    implementation = _pwsh_toolchain_impl,
    attrs = {
        "pwsh": attr.label(
            doc = "The Powershell executable.",
            cfg = "target",
            executable = True,
            mandatory = True,
            allow_files = True,
        ),
    },
)

def _current_pwsh_toolchain_impl(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    return [
        DefaultInfo(
            files = toolchain.all_files,
            runfiles = ctx.runfiles(transitive_files = toolchain.all_files),
        ),
        toolchain,
        toolchain.make_variable_info,
    ]

current_pwsh_toolchain = rule(
    doc = "Access the `pwsh_toolchain` for the current configuration.",
    implementation = _current_pwsh_toolchain_impl,
    toolchains = [TOOLCHAIN_TYPE],
)
