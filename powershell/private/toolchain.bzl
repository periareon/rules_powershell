"""Powershell toolchain"""

load(":utils.bzl", "rlocationpath")

TOOLCHAIN_TYPE = str(Label("//powershell:toolchain_type"))

def _pwsh_interpreter_impl(ctx):
    pwsh = ctx.file.pwsh
    files = [f for f in ctx.files.files if f != pwsh]

    # Produce a byte-for-byte copy of the interpreter with the executable bit set.
    # Template expansion reads and writes the file as Latin-1, so arbitrary binary
    # content survives unchanged, and the action runs inside Bazel without any
    # host tools.
    executable = ctx.actions.declare_file("{}/{}".format(ctx.label.name, pwsh.basename))
    ctx.actions.expand_template(
        template = pwsh,
        output = executable,
        substitutions = {},
        is_executable = True,
    )

    # The .NET apphost locates `pwsh.dll` and the runtime relative to its own
    # location, so every other file of the distribution is symlinked next to the copy.
    base = pwsh.short_path[:-len(pwsh.basename)]
    siblings = []
    for file in files:
        if not file.short_path.startswith(base):
            fail("`{}` is not located in the same directory tree as `{}`".format(
                file.short_path,
                pwsh.short_path,
            ))
        link = ctx.actions.declare_file("{}/{}".format(ctx.label.name, file.short_path[len(base):]))
        ctx.actions.symlink(output = link, target_file = file)
        siblings.append(link)

    return [DefaultInfo(
        executable = executable,
        files = depset([executable]),
        runfiles = ctx.runfiles(files = [executable] + siblings),
    )]

pwsh_interpreter = rule(
    doc = """\
Materializes an executable PowerShell interpreter from an extracted distribution.

The upstream Linux and macOS archives ship `pwsh` without the executable bit. This rule
restores it using only built-in Bazel actions, so no `chmod`, shell or other host tools
are required: the interpreter is copied with the executable bit set and the remaining
files of the distribution are symlinked next to it.

Windows does not use file mode bits, so `pwsh.exe` can be referenced directly (for
example through a `filegroup`) without this rule.

The resulting target is suitable for the `pwsh` attribute of `pwsh_toolchain`.
""",
    implementation = _pwsh_interpreter_impl,
    attrs = {
        "files": attr.label_list(
            doc = "All other files of the PowerShell distribution, located next to `pwsh`.",
            allow_files = True,
        ),
        "pwsh": attr.label(
            doc = "The `pwsh` file of the distribution.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    executable = True,
)

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
load("@rules_powershell//powershell:pwsh_toolchain.bzl", "pwsh_interpreter", "pwsh_toolchain")

# `pwsh_interpreter` makes the interpreter executable without host tools and
# carries the rest of the distribution along as runfiles.
pwsh_interpreter(
    name = "powershell_bin",
    pwsh = "powershell/pwsh",
    files = glob(["powershell/**"]),
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
