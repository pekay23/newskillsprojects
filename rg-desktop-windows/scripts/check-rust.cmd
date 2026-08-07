@echo off
REM check-rust.cmd - Verifies the Rust backend compiles.
REM Works from any working directory (uses %~dp0 for script-relative paths).

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\"

call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set PATH=%USERPROFILE%\.cargo\bin;%PATH%

REM Explicitly set LIB to include MSVC and Windows SDK library paths
set "MSVC_LIB=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\lib\x64"
set "SDK_UM_LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64"
set "SDK_UCRT_LIB=C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64"
set "LIB=%MSVC_LIB%;%SDK_UM_LIB%;%SDK_UCRT_LIB%;%LIB%"

cargo build --manifest-path "%PROJECT_DIR%src-tauri\Cargo.toml"
