param([string]$GodotExe = "")
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "godot_common.ps1")
$quadEngine = Resolve-GodotExecutable -GodotExe $GodotExe
$quadRoot = Split-Path -Parent $PSScriptRoot
Push-Location $quadRoot
try {
    & $quadEngine --headless --editor --import --quit --path .
    if ($LASTEXITCODE -ne 0) { throw "Godot resource import failed." }
    & $quadEngine --path .
} finally { Pop-Location }
