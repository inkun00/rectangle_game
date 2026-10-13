@echo off
setlocal
set "QUADRILATERAL_WORLD_PROJECT_DIR=%~dp0"
set "QUADRILATERAL_WORLD_PACK=%~dp0QuadrilateralWorld.pck"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; . (Join-Path $env:QUADRILATERAL_WORLD_PROJECT_DIR 'godot_common.ps1'); $engine=Resolve-GodotExecutable; & $engine --main-pack $env:QUADRILATERAL_WORLD_PACK; exit $LASTEXITCODE"
exit /b %ERRORLEVEL%
