@ECHO OFF

SETLOCAL ENABLEEXTENSIONS

@REM The runfiles library from rules_batch is vendored below. Jump over it so
@REM that its standalone entry point, which triggers when the containing file
@REM is named `runfiles.bat`, can never run no matter what this launcher is
@REM called. Its labels remain callable.
goto :rules_powershell_main

@REM {RUNFILES_API}

:rules_powershell_main

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

@REM Make sure child processes can locate runfiles too.
call :runfiles_export_envvars || exit /b 1

call :rlocation "{PWSH_INTERPRETER}" PWSH_INTERPRETER_PATH || exit /b 1
call :rlocation "{PROCESS_WRAPPER}" PROCESS_WRAPPER_PATH || exit /b 1
call :rlocation "{CONFIG}" RULES_POWERSHELL_CONFIG || exit /b 1
call :rlocation "{MAIN}" RULES_POWERSHELL_MAIN || exit /b 1

@REM Under `bazel test`, keep the state pwsh writes per user out of the real profile.
@REM On Windows pwsh resolves that location through `USERPROFILE` only; it ignores
@REM `HOME`, `LOCALAPPDATA` and `APPDATA`. Redirecting `USERPROFILE` into
@REM `TEST_TMPDIR` is not an option: it makes pwsh hang during startup whenever
@REM several tests run at once. So the individual knobs pwsh offers are used instead.
if defined BAZEL_TEST if defined TEST_TMPDIR (
    set "PSModuleAnalysisCachePath=%TEST_TMPDIR:/=\%\powershell\ModuleAnalysisCache"
    set "POWERSHELL_TELEMETRY_OPTOUT=1"
    set "POWERSHELL_UPDATECHECK=Off"
)

@REM The runfiles library scopes its own delayed expansion, so it is never
@REM enabled here and any `!` in the arguments survives the `%*` expansion.
"%PWSH_INTERPRETER_PATH%" -NoProfile -ExecutionPolicy Bypass -File "%PROCESS_WRAPPER_PATH%" %*
exit /b %ERRORLEVEL%
