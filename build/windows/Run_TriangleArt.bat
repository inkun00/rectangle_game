@echo off
setlocal
set "TRIANGLE_ART_PROJECT_DIR=%~dp0..\.."
set "TRIANGLE_ART_PACK=%~dp0TriangleArt.pck"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; . (Join-Path $env:TRIANGLE_ART_PROJECT_DIR 'tools\godot_common.ps1'); $engine=Resolve-GodotExecutable; & $engine --main-pack $env:TRIANGLE_ART_PACK; exit $LASTEXITCODE"
exit /b %ERRORLEVEL%
