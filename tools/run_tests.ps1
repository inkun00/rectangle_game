# Run the Quadrilateral World suite, including on a fresh checkout.
param([string]$GodotExe = "")

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "godot_common.ps1")
$GodotExe = Resolve-GodotExecutable -GodotExe $GodotExe
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Running Godot Headless Test Runner..." -ForegroundColor Cyan
$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
try {
    for ($importAttempt = 0; $importAttempt -lt 2; $importAttempt++) {
        $importProcess = Start-Process -FilePath $GodotExe -ArgumentList @("--headless", "--editor", "--import", "--quit", "--path", ".") -WorkingDirectory $ProjectRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -Wait -PassThru
        $importOutput = @(Get-Content -LiteralPath $stdoutPath -Encoding UTF8) + @(Get-Content -LiteralPath $stderrPath -Encoding UTF8)
        $importProblems = @($importOutput | Where-Object { "$($_)".TrimStart() -match '^(SCRIPT ERROR|ERROR|WARNING):' })
        if ($importProcess.ExitCode -eq 0 -and $importProblems.Count -eq 0) { break }

        # On a fresh checkout Godot initializes the custom font before importing
        # its cache. Retry only this exact, now-created font cache; all other
        # diagnostics and every diagnostic on the second pass remain failures.
        $fontCachePattern = 'res://(?<cache>\.godot/imported/korean_font\.ttf-[a-f0-9]+\.fontdata)'
        $fontCacheMatch = [regex]::Match(($importProblems -join "`n"), $fontCachePattern)
        $expectedFontError = '^ERROR: (?:Cannot open file ''res://\.godot/imported/korean_font\.ttf-[a-f0-9]+\.fontdata''\.|Failed loading resource: res://(?:\.godot/imported/korean_font\.ttf-[a-f0-9]+\.fontdata|assets/fonts/korean_font\.ttf)\.|Error loading custom project font ''res://assets/fonts/korean_font\.ttf'')$'
        $unexpectedProblems = @($importProblems | Where-Object { "$($_)".Trim() -notmatch $expectedFontError })
        if ($importAttempt -eq 0 -and $importProcess.ExitCode -eq 0 -and $importProblems.Count -gt 0 -and $unexpectedProblems.Count -eq 0 -and $fontCacheMatch.Success -and (Test-Path -LiteralPath (Join-Path $ProjectRoot $fontCacheMatch.Groups['cache'].Value) -PathType Leaf)) {
            Write-Host 'Initial font cache generated; verifying a clean Godot import.'
            continue
        }
        $importOutput | ForEach-Object { Write-Host "$_" }
        throw "Godot import failed before tests."
    }
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
