"""# Powershell rules"""

load(":pwsh_binary.bzl", _pwsh_binary = "pwsh_binary")
load(":pwsh_info.bzl", _PwshInfo = "PwshInfo")
load(":pwsh_library.bzl", _pwsh_library = "pwsh_library")
load(":pwsh_test.bzl", _pwsh_test = "pwsh_test")

pwsh_binary = _pwsh_binary
pwsh_library = _pwsh_library
pwsh_test = _pwsh_test
PwshInfo = _PwshInfo
