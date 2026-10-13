# Export Quadrilateral World to Web (HTML5/WASM)
param(
    [string]$GodotExe,
    [string]$PythonExe = "python"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "godot_common.ps1")
$GodotExe = Resolve-GodotExecutable -GodotExe $GodotExe

$BuildDir = "build\web"
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

& $PythonExe tools/subset_font.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "UI font subsetting failed. Install tools/requirements-font.txt."
    exit 1
}

& $GodotExe --headless --editor --import --quit --path .
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot resource import failed."
    exit 1
}

Write-Host "Exporting Quadrilateral World for Web (Release)..." -ForegroundColor Cyan
& $GodotExe --headless --path . --export-release "Web" "build/web/index.html"
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0 -and (Test-Path "build\web\index.html")) {
    & $PythonExe tools/prepare_web_release.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Web asset compression and fingerprinting failed."
        exit 1
    }
    Write-Host "`nWeb export succeeded! Output located in: $BuildDir" -ForegroundColor Green
} else {
    Write-Host "`nWeb export failed with exit code $exitCode" -ForegroundColor Red
}

exit $exitCode
