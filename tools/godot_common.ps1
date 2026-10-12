# Find an installed Godot executable without depending on one machine's paths.
# Usage: Resolve-GodotExecutable -GodotExe 'C:\path\to\Godot.exe'
# Alternatively set GODOT_EXE, add Godot to PATH, or use a WinGet installation.
function Resolve-GodotExecutable {
    [CmdletBinding()]
    param([string]$GodotExe = "")

    $requestedExe = $GodotExe
    $requestSource = "-GodotExe"
    if ([string]::IsNullOrWhiteSpace($requestedExe)) {
        $requestedExe = $env:GODOT_EXE
        $requestSource = "GODOT_EXE"
    }
    if (-not [string]::IsNullOrWhiteSpace($requestedExe)) {
        if (Test-Path -LiteralPath $requestedExe -PathType Leaf) {
            return (Resolve-Path -LiteralPath $requestedExe).ProviderPath
        }
        $requestedCommand = Get-Command -Name $requestedExe -CommandType Application -ErrorAction SilentlyContinue
        if ($requestedCommand) {
            return $requestedCommand[0].Source
        }
        throw "Godot executable specified by $requestSource was not found: $requestedExe. Supply -GodotExe with the full executable path or set GODOT_EXE."
    }

    foreach ($commandName in @("godot", "godot4", "godot_console", "godot4_console")) {
        $godotCommand = Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue
        if ($godotCommand) {
            return $godotCommand[0].Source
        }
    }

    $installDirectories = @()
    if ($env:LOCALAPPDATA) {
        $wingetDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        if (Test-Path -LiteralPath $wingetDirectory -PathType Container) {
            $installDirectories += @(Get-ChildItem -LiteralPath $wingetDirectory -Directory -Filter "GodotEngine.GodotEngine*" -ErrorAction SilentlyContinue)
        }
    }
    if ($env:PUBLIC) {
        $creatorTempDirectory = Join-Path $env:PUBLIC "Documents\ESTsoft\CreatorTemp"
        if (Test-Path -LiteralPath $creatorTempDirectory -PathType Container) {
            $installDirectories += @(Get-ChildItem -LiteralPath $creatorTempDirectory -Directory -Filter "godot-*" -ErrorAction SilentlyContinue)
        }
    }
    foreach ($installDirectory in @($installDirectories | Sort-Object LastWriteTime -Descending)) {
        $consoleExecutables = @(Get-ChildItem -LiteralPath $installDirectory.FullName -File -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue)
        if ($consoleExecutables.Count -gt 0) {
            return $consoleExecutables[0].FullName
        }
        $executables = @(Get-ChildItem -LiteralPath $installDirectory.FullName -File -Filter "Godot*.exe" -ErrorAction SilentlyContinue)
        if ($executables.Count -gt 0) {
            return $executables[0].FullName
        }
    }

    throw "Godot 4 was not found. Install Godot, add its executable to PATH, set GODOT_EXE, or supply -GodotExe 'C:\path\to\Godot.exe'."
}
