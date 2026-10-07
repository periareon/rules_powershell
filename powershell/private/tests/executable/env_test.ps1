# Verifies that the `env` attribute is applied when running under `bazel test`.

if ($env:RULES_POWERSHELL_TEST_ENV -ne 'hello from env') {
    throw "Unexpected value for RULES_POWERSHELL_TEST_ENV: '$($env:RULES_POWERSHELL_TEST_ENV)'"
}

Write-Output "Environment variable received."
