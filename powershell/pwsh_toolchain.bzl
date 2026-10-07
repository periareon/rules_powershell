"""pwsh_toolchain"""

load(
    "//powershell/private:toolchain.bzl",
    _pwsh_interpreter = "pwsh_interpreter",
    _pwsh_toolchain = "pwsh_toolchain",
)

pwsh_interpreter = _pwsh_interpreter
pwsh_toolchain = _pwsh_toolchain
