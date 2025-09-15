"""Powershell toolchain"""

TOOLCHAIN_TYPE = str(Label("//powershell:toolchain_type"))

def _pwsh_toolchain_impl(ctx):
    all_files = []
    if DefaultInfo in ctx.attr.pwsh:
        all_files.extend([
            ctx.attr.pwsh[DefaultInfo].files,
            ctx.attr.pwsh[DefaultInfo].default_runfiles.files,
        ])

    return [
        platform_common.ToolchainInfo(
            pwsh = ctx.executable.pwsh,
            all_files = depset(transitive = all_files),
        ),
    ]

pwsh_toolchain = rule(
    doc = """\
Powershell toolchain.
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
        toolchain,
    ]

current_pwsh_toolchain = rule(
    doc = "Access the `pwsh_toolchain` for the current configuration.",
    implementation = _current_pwsh_toolchain_impl,
    toolchains = [TOOLCHAIN_TYPE],
)
