# Run Headless Test Suite for Triangle Art
param([string]$GodotExe = "")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "godot_common.ps1")
$GodotExe = Resolve-GodotExecutable -GodotExe $GodotExe
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Running Godot Headless Test Runner..." -ForegroundColor Cyan
$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
try {
    $process = Start-Process -FilePath $GodotExe -ArgumentList @("--headless", "--path", ".", "res://tests/test_runner.tscn") -WorkingDirectory $ProjectRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -Wait -PassThru
    $exitCode = $process.ExitCode
    $testOutput = @(Get-Content -LiteralPath $stdoutPath -Encoding UTF8) + @(Get-Content -LiteralPath $stderrPath -Encoding UTF8)
} finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
}
$testOutput | ForEach-Object { Write-Host "$_" }
$engineProblems = @($testOutput | Where-Object { "$($_)".TrimStart() -match '^(SCRIPT ERROR|ERROR|WARNING):' })
if ($engineProblems.Count -gt 0) {
    Write-Error "Godot reported $($engineProblems.Count) runtime error(s) or warning(s)."
    exit 1
}

if ($exitCode -eq 0) {
    Write-Host "`nAll tests passed successfully!" -ForegroundColor Green
} else {
    Write-Host "`nTests failed with exit code $exitCode" -ForegroundColor Red
}

exit $exitCode
