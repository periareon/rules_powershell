"""Powershell bzlmod extensions"""

load(
    "//powershell/private:toolchain_repo.bzl",
    "CONSTRAINTS",
    "POWERSHELL_DEFAULT_VERSION",
    "POWERSHELL_VERSIONS",
    "powershell_toolchain_repository_hub",
    "powershell_tools_repository",
)

def _format_toolchain_url(url, version, platform, artifact):
    major_minor, _, _ = version.rpartition(".")

    return (
        url.replace("{major_minor}", major_minor)
            .replace("{semver}", version)
            .replace("{platform}", platform)
            .replace("{artifact}", artifact)
    )

def _powershell_impl(module_ctx):
    reproducible = True

    # Collect toolchain requests from all modules. `module_ctx.modules` always lists the
    # root module first, so when two modules request the same hub name the root module
    # (or the first module encountered) wins. This lets consumers override the default
    # `powershell_toolchains` hub declared by `rules_powershell` itself.
    requests = {}
    for mod in module_ctx.modules:
        for attrs in mod.tags.toolchain:
            if attrs.name in requests:
                continue
            requests[attrs.name] = attrs

    for attrs in requests.values():
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
    doc = """\
An extension for defining a `pwsh_toolchain` from a download archive.

`rules_powershell` declares and registers a default hub named `powershell_toolchains`
for all consumers, so no setup is required to get started. To use a different version
of Powershell, declare a hub with a unique name and register it. Toolchains registered
by the root module take precedence over the default. If two modules declare a hub with
the same name, the root module's declaration wins.

An example of defining and registering toolchains:

```python
powershell = use_extension("@rules_powershell//powershell:extensions.bzl", "powershell")
powershell.toolchain(
    name = "powershell_7_5_3",
    version = "7.5.3",
)
use_repo(powershell, "powershell_7_5_3")

register_toolchains(
    "@powershell_7_5_3//:all",
)
```
""",
    attrs = {
        "name": attr.string(
            doc = "The name of the toolchain hub repository.",
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
