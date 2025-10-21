#!/usr/bin/env bash
# Test that multiple .psd1 files in one library are rejected

set -e

# Create a temporary BUILD file with invalid configuration
cat > /tmp/test_invalid_BUILD.bazel << 'EOF'
load("//powershell:pwsh_library.bzl", "pwsh_library")

pwsh_library(
    name = "invalid_lib",
    srcs = [
        "ModuleWithManifest/ModuleWithManifest.psd1",
        "MathFunctions/MathFunctions.psd1",  # This would be a second manifest
    ],
)
EOF

# Try to build it (should fail)
if bazel build //powershell/private/tests/module:invalid_lib 2>&1 | grep -q "Only one .psd1 manifest file is allowed"; then
    echo "✓ Validation correctly rejected multiple .psd1 files"
    exit 0
else
    echo "✗ Validation did not catch multiple .psd1 files"
    exit 1
fi

