# Export a small Windows PCK package that runs with an installed Godot 4 engine.
param(
    [string]$GodotExe = "",
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "godot_common.ps1")
$GodotExe = Resolve-GodotExecutable -GodotExe $GodotExe
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build\windows"
$PackPath = Join-Path $BuildDir "TriangleArt.pck"

Push-Location $ProjectRoot
try {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

    & $PythonExe "tools/subset_font.py"
    if ($LASTEXITCODE -ne 0) {
        throw "UI font subsetting failed. Install tools/requirements-font.txt with the selected Python interpreter."
    }

    & $GodotExe --headless --editor --import --quit --path $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Godot resource import failed."
    }

    Write-Host "Exporting Triangle Art Windows PCK package..." -ForegroundColor Cyan
    & $GodotExe --headless --path $ProjectRoot --export-pack "Windows Desktop" $PackPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $PackPath)) {
        throw "Windows Desktop export failed with code $LASTEXITCODE."
    }

    # The launcher resolves the local engine at run time, so no engine is bundled.
    $LauncherContent = @'
@echo off
setlocal
set "TRIANGLE_ART_PROJECT_DIR=%~dp0..\.."
set "TRIANGLE_ART_PACK=%~dp0TriangleArt.pck"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; . (Join-Path $env:TRIANGLE_ART_PROJECT_DIR 'tools\godot_common.ps1'); $engine=Resolve-GodotExecutable; & $engine --main-pack $env:TRIANGLE_ART_PACK; exit $LASTEXITCODE"
exit /b %ERRORLEVEL%
'@
    Set-Content -LiteralPath (Join-Path $BuildDir "Run_TriangleArt.bat") -Value $LauncherContent -Encoding ASCII

    Write-Host "Windows package prepared in: $BuildDir" -ForegroundColor Green
    Write-Host "Run Run_TriangleArt.bat with Godot 4 installed."
} finally {
    Pop-Location
}
