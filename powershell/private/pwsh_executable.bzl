"""Powershell rules"""

load(":powershell.bzl", "COMMON_ATTRS", "PwshInfo")
load(":toolchain.bzl", "TOOLCHAIN_TYPE")

_EXECUTABLE_ATTRS = COMMON_ATTRS | {
    "env": attr.string_dict(
        doc = "Dictionary of strings; values are subject to `$(location)` and \"Make variable\" substitution.",
    ),
    "_entrypoint": attr.label(
        default = Label("//powershell/private:entrypoint"),
        cfg = "target",
        allow_single_file = True,
    ),
}

def _create_run_environment_info(ctx, env, env_inherit, targets):
    """Create an environment info provider

    This macro performs location expansions.

    Args:
        ctx (ctx): The rule's context object.
        env (dict): Environment variables to set.
        env_inherit (list): Environment variables to inherit from the host.
        targets (List[Target]): Targets to use in location expansion.

    Returns:
        RunEnvironmentInfo: The provider.
    """

    known_variables = {}
    for target in ctx.attr.toolchains:
        if platform_common.TemplateVariableInfo in target:
            variables = getattr(target[platform_common.TemplateVariableInfo], "variables", {})
            known_variables.update(variables)

    expanded_env = {}
    for key, value in env.items():
        expanded_env[key] = ctx.expand_make_variables(
            key,
            ctx.expand_location(value, targets),
            known_variables,
        )

    workspace_name = ctx.label.workspace_name
    if not workspace_name:
        workspace_name = ctx.workspace_name

    if not workspace_name:
        workspace_name = "_main"

    # Needed for bzlmod-aware runfiles resolution.
    expanded_env["REPOSITORY_NAME"] = workspace_name

    return RunEnvironmentInfo(
        environment = expanded_env,
        inherited_environment = env_inherit,
    )

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _pwsh_binary_impl(ctx):
    toolchain = ctx.toolchains[TOOLCHAIN_TYPE]

    is_windows = ctx.file._entrypoint.basename.endswith(".bat")
    executable = ctx.actions.declare_file("{}.{}".format(
        ctx.label.name,
        "bat" if is_windows else "sh",
    ))

    if len(ctx.files.srcs) != 1:
        fail("you must specify exactly one file in 'srcs'", attr = "srcs")
    main = ctx.files.srcs[0]

    ctx.actions.expand_template(
        template = ctx.file._entrypoint,
        output = executable,
        substitutions = {
            "{MAIN}": _rlocationpath(main, ctx.workspace_name),
            "{PWSH_INTERPRETER}": _rlocationpath(toolchain.pwsh, ctx.workspace_name),
        },
    )

    files = depset(ctx.files.srcs)

    runfiles = ctx.runfiles(files = ctx.files.srcs + ctx.files.data, transitive_files = toolchain.all_files)

    for collection in (ctx.attr.data, ctx.attr.deps):
        for target in collection:
            if DefaultInfo in target:
                runfiles = runfiles.merge_all([
                    ctx.runfiles(transitive_files = target[DefaultInfo].files),
                    target[DefaultInfo].default_runfiles,
                ])

    return [
        DefaultInfo(
            executable = executable,
            files = files,
            runfiles = runfiles,
        ),
        PwshInfo(
            srcs = depset(ctx.files.srcs),
        ),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps"],
            extensions = ["ps1"],
            source_attributes = ["srcs"],
        ),
        _create_run_environment_info(
            ctx,
            ctx.attr.env,
            getattr(ctx.attr, "env_inherit", []),
            ctx.attr.data,
        ),
    ]

pwsh_binary = rule(
    doc = """\
The `pwsh_binary` rule is used to declare executable powershell scripts.
(`pwsh_binary` is a misnomer: its outputs aren't necessarily binaries.) This rule ensures
that all dependencies are built, and appear in the `runfiles` area at execution time.
We recommend that you name your `pwsh_binary()` rules after the name of the script minus
the extension (e.g. `.ps1`); the rule name and the file name must be distinct.

For a simple Powershell script with no dependencies and some data files:

```python
pwsh_binary(
    name = "foo",
    srcs = ["foo.ps1"],
    data = glob(["datafiles/*.txt"]),
)
```
""",
    implementation = _pwsh_binary_impl,
    attrs = _EXECUTABLE_ATTRS,
    executable = True,
    provides = [PwshInfo],
    toolchains = [
        TOOLCHAIN_TYPE,
    ],
)

def _pwsh_test_impl(ctx):
    return _pwsh_binary_impl(ctx)

pwsh_test = rule(
    doc = """\
A `pwsh_test` rule creates a test written as a Powershell script.

```python
pwsh_test(
    name = "foo_integration_test",
    size = "small",
    srcs = ["foo_integration_test.ps1"],
    deps = [":foo_sh_lib"],
    data = glob(["testdata/*.txt"]),
)
```
""",
    implementation = _pwsh_test_impl,
    fragments = ["coverage"],
    attrs = _EXECUTABLE_ATTRS | {
        "env_inherit": attr.string_list(
            doc = "Specifies additional environment variables to inherit from the external environment when the test is executed by `bazel test`.",
        ),
        # Add the script as an attribute in order for sh_test to output code coverage results for
        # code covered by CC binaries invocations.
        "_collect_cc_coverage": attr.label(
            cfg = config.exec(exec_group = "test"),
            default = "@bazel_tools//tools/test:collect_cc_coverage",
            executable = True,
        ),
        "_lcov_merger": attr.label(
            cfg = config.exec(exec_group = "test"),
            default = configuration_field(fragment = "coverage", name = "output_generator"),
            executable = True,
        ),
    },
    test = True,
    provides = [PwshInfo],
    toolchains = [
        TOOLCHAIN_TYPE,
    ],
)
