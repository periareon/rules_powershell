"""Powershell toolchain repositories"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//powershell/private:versions.bzl", _POWERSHELL_VERSIONS = "POWERSHELL_VERSIONS")

POWERSHELL_DEFAULT_VERSION = "7.5.3"

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

_POWERSHELL_TOOLCHAIN_BUILD_FILE_CONTENT = """\
load("@rules_powershell//powershell:pwsh_toolchain.bzl", "pwsh_toolchain")

filegroup(
    name = "powershell_bin",
    srcs = ["{powershell}"],
    data = glob(
        include = ["**"],
        exclude = ["WORKSPACE", "BUILD", "*.bazel"],
    ),
)

pwsh_toolchain(
    name = "toolchain",
    pwsh = ":powershell_bin",
    visibility = ["//visibility:public"],
)

alias(
    name = "{name}",
    actual = ":toolchain",
    visibility = ["//visibility:public"],
)
"""

def powershell_tools_repository(*, name, version, platform, urls, integrity, **kwargs):
    """Download a version of Powershell and instantiate targets for itl

    Args:
        name (str): The name of the repository to create.
        version (str): The version of Powershell
        platform (str): The target platform of the Powershell executable.
        urls (list): A list of urls for fetching powershell.
        integrity (str): The integrity checksum of the powershell binary.
        **kwargs (dict): Additional keyword arguments.

    Returns:
        str: Return `name` for convenience.
    """
    bin_path = POWERSHELL_PATHS[platform].replace("{version}", version)
    http_archive(
        name = name,
        urls = urls,
        integrity = integrity,
        build_file_content = _POWERSHELL_TOOLCHAIN_BUILD_FILE_CONTENT.format(
            name = name,
            powershell = bin_path,
        ),
        patch_cmds = [
            "chmod +x {}".format(bin_path),
        ],
        **kwargs
    )

    return name

_BUILD_FILE_FOR_TOOLCHAIN_HUB_TEMPLATE = """
toolchain(
    name = "{name}",
    exec_compatible_with = {exec_constraint_sets_serialized},
    target_compatible_with = {target_constraint_sets_serialized},
    target_settings = {target_settings_serialized},
    toolchain = "{toolchain}",
    toolchain_type = "@rules_powershell//powershell:toolchain_type",
    visibility = ["//visibility:public"],
)
"""

def _BUILD_for_toolchain_hub(
        toolchain_names,
        toolchain_labels,
        target_settings,
        target_compatible_with,
        exec_compatible_with):
    return "\n".join([_BUILD_FILE_FOR_TOOLCHAIN_HUB_TEMPLATE.format(
        name = toolchain_name,
        exec_constraint_sets_serialized = json.encode(exec_compatible_with.get(toolchain_name, [])),
        target_constraint_sets_serialized = json.encode(target_compatible_with.get(toolchain_name, [])),
        target_settings_serialized = json.encode(target_settings.get(toolchain_name)) if toolchain_name in target_settings else "None",
        toolchain = toolchain_labels[toolchain_name],
    ) for toolchain_name in toolchain_names])

def _powershell_toolchain_repository_hub_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", _BUILD_for_toolchain_hub(
        toolchain_names = repository_ctx.attr.toolchain_names,
        toolchain_labels = repository_ctx.attr.toolchain_labels,
        target_settings = repository_ctx.attr.target_settings,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
    ))

powershell_toolchain_repository_hub = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares a set of other toolchains from other " +
        "repositories. This exists to allow registering a set of toolchains in one go with the `:all` target."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the execution platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_compatible_with": attr.string_list_dict(
            doc = "A list of constraints for the target platform for this toolchain, keyed by toolchain name.",
            mandatory = True,
        ),
        "target_settings": attr.string_list_dict(
            doc = "A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.",
            mandatory = True,
        ),
        "toolchain_labels": attr.string_dict(
            doc = "The name of the toolchain implementation target, keyed by toolchain name.",
            mandatory = True,
        ),
        "toolchain_names": attr.string_list(
            mandatory = True,
        ),
    },
    implementation = _powershell_toolchain_repository_hub_impl,
)
