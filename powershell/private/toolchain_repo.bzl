"""Powershell toolchain repositories"""

load("//powershell/private:versions.bzl", _POWERSHELL_VERSIONS = "POWERSHELL_VERSIONS")

POWERSHELL_DEFAULT_VERSION = "7.5.4"

POWERSHELL_VERSIONS = _POWERSHELL_VERSIONS

POWERSHELL_PATHS = {
    "linux_arm64": "pwsh",
    "linux_x64": "pwsh",
    "osx_arm64": "pwsh",
    "osx_x64": "pwsh",
    "win_arm64": "pwsh.exe",
    "win_x64": "pwsh.exe",
}

CONSTRAINTS = {
    "linux_arm64": ["@platforms//os:linux", "@platforms//cpu:aarch64"],
    "linux_x64": ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    "osx_arm64": ["@platforms//os:macos", "@platforms//cpu:aarch64"],
    "osx_x64": ["@platforms//os:macos", "@platforms//cpu:x86_64"],
    "win_arm64": ["@platforms//os:windows", "@platforms//cpu:aarch64"],
    "win_x64": ["@platforms//os:windows", "@platforms//cpu:x86_64"],
}

_TOOLS_BUILD_FILE_TEMPLATE = """\
load("@rules_powershell//powershell:pwsh_toolchain.bzl", "pwsh_toolchain")

filegroup(
    name = "powershell_bin",
    srcs = ["{pwsh}"],
    data = glob(
        include = ["**"],
        exclude = ["BUILD.bazel"],
    ),
)

pwsh_toolchain(
    name = "toolchain",
    pwsh = ":powershell_bin",
    visibility = ["//visibility:public"],
)
"""

def _bazel_major_version():
    version = getattr(native, "bazel_version", "")
    if not version:
        return None
    major = version.split(".")[0]
    if not major.isdigit():
        return None
    return int(major)

_BAZEL_MAJOR_VERSION = _bazel_major_version()

def _make_executable(rctx, path):
    """Set the executable bit on a file using only Bazel's repository APIs.

    The unix PowerShell archives ship `pwsh` without the executable bit. Rewriting
    the file through `repository_ctx.read` and `repository_ctx.file` restores it
    byte-for-byte without depending on `chmod` or a shell on the host.

    Bazel 7 re-encodes `repository_ctx.file` content as UTF-8 unless
    `legacy_utf8 = False` is passed, which would corrupt a binary. Bazel 8 and
    newer always write the bytes as read and deprecate the parameter, so it is
    only passed where it is needed.

    Args:
        rctx (repository_ctx): The repository context.
        path (str): The repository-relative path of the file.
    """
    content = rctx.read(path)
    rctx.delete(path)

    kwargs = {}
    if _BAZEL_MAJOR_VERSION != None and _BAZEL_MAJOR_VERSION < 8:
        kwargs["legacy_utf8"] = False

    rctx.file(path, content, executable = True, **kwargs)

def _powershell_tools_repository_impl(rctx):
    pwsh = POWERSHELL_PATHS[rctx.attr.platform]

    rctx.download_and_extract(
        url = rctx.attr.urls,
        integrity = rctx.attr.integrity,
    )

    # Windows does not use file mode bits, so only the unix archives need fixing.
    if not rctx.attr.platform.startswith("win"):
        _make_executable(rctx, pwsh)

    rctx.file("BUILD.bazel", _TOOLS_BUILD_FILE_TEMPLATE.format(pwsh = pwsh))

powershell_tools_repository = repository_rule(
    doc = "Downloads a PowerShell release archive and defines a `pwsh_toolchain` named `toolchain` for it.",
    implementation = _powershell_tools_repository_impl,
    attrs = {
        "integrity": attr.string(
            doc = "The integrity checksum of the archive.",
            mandatory = True,
        ),
        "platform": attr.string(
            doc = "The platform of the archive, e.g. `linux_x64`.",
            mandatory = True,
            values = POWERSHELL_PATHS.keys(),
        ),
        "urls": attr.string_list(
            doc = "A list of urls for fetching the archive.",
            mandatory = True,
        ),
    },
)

_HUB_TOOLCHAIN_TEMPLATE = """\
toolchain(
    name = "{name}",
    target_compatible_with = {target_compatible_with},
    toolchain = "{toolchain}",
    toolchain_type = "@rules_powershell//powershell:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

def _powershell_toolchain_repository_hub_impl(rctx):
    rctx.file("BUILD.bazel", "\n".join([
        _HUB_TOOLCHAIN_TEMPLATE.format(
            name = name,
            target_compatible_with = json.encode(rctx.attr.target_compatible_with.get(name, [])),
            toolchain = toolchain,
        )
        for name, toolchain in rctx.attr.toolchains.items()
    ]))

powershell_toolchain_repository_hub = repository_rule(
    doc = (
        "Generates a repository declaring a `toolchain` for each PowerShell tools repository, " +
        "so that all of them can be registered at once with the `:all` target."
    ),
    implementation = _powershell_toolchain_repository_hub_impl,
    attrs = {
        "target_compatible_with": attr.string_list_dict(
            doc = "Constraints for the target platform, keyed by toolchain name.",
            mandatory = True,
        ),
        "toolchains": attr.string_dict(
            doc = "The label of the `pwsh_toolchain` implementation, keyed by toolchain name.",
            mandatory = True,
        ),
    },
)
