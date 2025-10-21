"""Powershell rules"""

PwshInfo = provider(
    doc = "A provider for Powershell rules.",
    fields = {
        "imports": "Depset[str]: The list of rlocation paths to module files (.psm1, .psd1) for PSModulePath setup.",
        "srcs": "Depset[File]: The list of source files associated with the powershell target.",
    },
)

COMMON_ATTRS = {
    "data": attr.label_list(
        doc = "Files needed by this rule at runtime. May list file or rule targets. Generally allows any target.",
        allow_files = True,
    ),
    "deps": attr.label_list(
        doc = """\
The list of "library" targets to be aggregated into this target. See general comments about deps at Typical attributes defined by most build rules.

This attribute should be used to list other sh_library rules that provide interpreted program source code depended on by the code in srcs. The files provided by these rules will be present among the runfiles of this target.
""",
        providers = [PwshInfo],
    ),
}

LIBRARY_ATTRS = COMMON_ATTRS | {
    "srcs": attr.label_list(
        doc = "The list of source files that are processed to create the target.",
        allow_files = [".ps1", ".psm1", ".psd1"],
    ),
}

EXECUTABLE_SRCS_ATTR = {
    "srcs": attr.label_list(
        doc = "The list of source (.ps1) files that are processed to create the target.",
        allow_files = [".ps1"],
    ),
}

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)

def _pwsh_library_impl(ctx):
    # Validate that at most one .psd1 file is provided
    psd1_files = [f for f in ctx.files.srcs if f.path.endswith(".psd1")]
    if len(psd1_files) > 1:
        fail("Only one .psd1 manifest file is allowed per pwsh_library, but found {}: {}".format(
            len(psd1_files),
            ", ".join([f.basename for f in psd1_files]),
        ))

    # Collect module files (.psm1 and .psd1) for PSModulePath setup
    module_files = [f for f in ctx.files.srcs if f.path.endswith((".psm1", ".psd1"))]

    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name

    # Collect import paths from this target and dependencies
    direct_imports = [_rlocationpath(f, workspace_name) for f in module_files]
    transitive_imports = []

    runfiles = ctx.runfiles(files = ctx.files.srcs + ctx.files.data)

    for collection in (ctx.attr.data, ctx.attr.deps):
        for target in collection:
            if DefaultInfo in target:
                runfiles = runfiles.merge_all([
                    ctx.runfiles(transitive_files = target[DefaultInfo].files),
                    target[DefaultInfo].default_runfiles,
                ])
            if PwshInfo in target:
                transitive_imports.append(target[PwshInfo].imports)

    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
            runfiles = runfiles,
        ),
        PwshInfo(
            srcs = depset(ctx.files.srcs),
            imports = depset(direct_imports, transitive = transitive_imports),
        ),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps"],
            extensions = ["ps1", "psm1", "psd1"],
            source_attributes = ["srcs"],
        ),
    ]

pwsh_library = rule(
    doc = """\
The main use for this rule is to aggregate together a logical
"library" consisting of related scripts and modules.
""",
    implementation = _pwsh_library_impl,
    attrs = LIBRARY_ATTRS,
    provides = [PwshInfo],
)
