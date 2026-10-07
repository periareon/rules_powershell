"""pwsh_toolchain"""

load(
    "//powershell/private:toolchain.bzl",
    _pwsh_toolchain = "pwsh_toolchain",
)

pwsh_toolchain = _pwsh_toolchain
