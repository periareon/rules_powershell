@ECHO OFF

SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

@REM {RUNFILES_API}

if not defined RUNFILES_DIR if not defined RUNFILES_MANIFEST_FILE (
    if exist "%~f0.runfiles" (
        set "RUNFILES_DIR=%~f0.runfiles"
    ) else if exist "%~f0.runfiles_manifest" (
        set "RUNFILES_MANIFEST_FILE=%~f0.runfiles_manifest"
    ) else if exist "%~f0.exe.runfiles_manifest" (
        set "RUNFILES_MANIFEST_FILE=%~f0.exe.runfiles_manifest"
    ) else (
        echo>&2 ERROR: cannot find runfiles
        exit /b 1
    )
)

call :runfiles_export_envvars

call :rlocation "{PWSH_INTERPRETER}" PWSH_INTERPRETER_PATH
call :rlocation "{PROCESS_WRAPPER}" PROCESS_WRAPPER_PATH
call :rlocation "{CONFIG}" RULES_POWERSHELL_CONFIG
call :rlocation "{MAIN}" RULES_POWERSHELL_MAIN

@REM Powershell tries to cache files in the user's `HOME` directory. When running
@REM tests, try to contain this cache to an isolated location.
if defined TEST_TMPDIR (
    set "HOME=%TEST_TMPDIR%\powershell"
    set "USERPROFILE=%TEST_TMPDIR%\powershell"
)

%PWSH_INTERPRETER_PATH% ^
    %PROCESS_WRAPPER_PATH% ^
    %*
