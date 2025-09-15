"""Powershell bzlmod extensions"""

load(
    "//powershell/private:toolchain_repo.bzl",
    "CONSTRAINTS",
    "POWERSHELL_DEFAULT_VERSION",
    "POWERSHELL_VERSIONS",
    "powershell_toolchain_repository_hub",
    "powershell_tools_repository",
)

def _find_modules(module_ctx):
    root = None
    for mod in module_ctx.modules:
        if mod.is_root:
            return mod

    return root

def _format_toolchain_url(url, version, platform, artifact):
    major_minor, _, _ = version.rpartition(".")

    return (
        url.replace("{major_minor}", major_minor)
            .replace("{semver}", version)
            .replace("{platform}", platform)
            .replace("{artifact}", artifact)
    )

def _powershell_impl(module_ctx):
    root = _find_modules(module_ctx)
    reproducible = True

    for attrs in root.tags.toolchain:
        if attrs.version not in POWERSHELL_VERSIONS:
            fail("Powershell toolchain hub `{}` was given unsupported version `{}`. Try: {}".format(
                attrs.name,
                attrs.version,
                POWERSHELL_VERSIONS.keys(),
            ))
        available = POWERSHELL_VERSIONS[attrs.version]
        toolchain_names = []
        toolchain_labels = {}
        target_compatible_with = {}
        for platform, artifact_info in available.items():
            tool_name = powershell_tools_repository(
                name = "{}__{}".format(attrs.name, platform),
                version = attrs.version,
                platform = platform,
                urls = [
                    _format_toolchain_url(
                        url = url,
                        version = attrs.version,
                        platform = platform,
                        artifact = artifact_info["artifact"],
                    )
                    for url in attrs.urls
                ],
                integrity = artifact_info["integrity"],
            )

            toolchain_names.append(tool_name)
            toolchain_labels[tool_name] = "@{}".format(tool_name)
            target_compatible_with[tool_name] = CONSTRAINTS[platform]

        powershell_toolchain_repository_hub(
            name = attrs.name,
            toolchain_labels = toolchain_labels,
            toolchain_names = toolchain_names,
            exec_compatible_with = {},
            target_compatible_with = target_compatible_with,
            target_settings = {},
        )

    return module_ctx.extension_metadata(
        reproducible = reproducible,
    )

_TOOLCHAIN_TAG = tag_class(
    doc = "An extension for defining a `powershell_toolchain` from a download archive.",
    attrs = {
        "name": attr.string(
            doc = "The name of the toolchain.",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = "Url templates to use for downloading Powershell.",
            default = [
                "https://github.com/PowerShell/PowerShell/releases/download/v{semver}/{artifact}",
            ],
        ),
        "version": attr.string(
            doc = "The version of Powershell to download.",
            default = POWERSHELL_DEFAULT_VERSION,
        ),
    },
)

powershell = module_extension(
    doc = "Bzlmod extensions for Powershell",
    implementation = _powershell_impl,
    tag_classes = {
        "toolchain": _TOOLCHAIN_TAG,
    },
)
