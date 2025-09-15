"""Powershell rules"""

PwshInfo = provider(
    doc = "A provider for Powershell rules.",
    fields = {
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
    "srcs": attr.label_list(
        doc = "The list of source (.ps1) files that are processed to create the target.",
        allow_files = [".ps1"],
    ),
}

def _pwsh_library_impl(ctx):
    runfiles = ctx.runfiles(files = ctx.files.srcs + ctx.files.data)

    for collection in (ctx.attr.data, ctx.attr.deps):
        for target in collection:
            if DefaultInfo in target:
                runfiles = runfiles.merge_all([
                    ctx.runfiles(transitive_files = target[DefaultInfo].files),
                    target[DefaultInfo].default_runfiles,
                ])

    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
            runfiles = runfiles,
        ),
        PwshInfo(
            srcs = depset(ctx.files.srcs),
        ),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps"],
            extensions = ["py"],
            source_attributes = ["srcs"],
        ),
    ]

pwsh_library = rule(
    doc = """\
Powershell library
""",
    implementation = _pwsh_library_impl,
    attrs = COMMON_ATTRS,
    provides = [PwshInfo],
)
