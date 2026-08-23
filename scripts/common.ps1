# P2 test dependency bootstrap (formal stage): GUT 9.7.1 only.
# GdUnit4 is no longer a formal-stage requirement (D029).

function Resolve-P2Godot {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    if ($env:GODOT_BIN) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $bundled = Get-ChildItem -LiteralPath (Join-Path $repoRoot '.tools\godot') -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bundled) {
        return $bundled.FullName
    }

    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw 'Godot not found. Pass -GodotBin or set GODOT_BIN to the Godot 4.7.2 executable.'
}

function Set-P2GodotUserDirs {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $userRoot = Join-Path $repoRoot '.tools\userdata'
    $roaming = Join-Path $userRoot 'Roaming'
    $local = Join-Path $userRoot 'Local'
    New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
}

function Initialize-P2TestDependencies {
    # GUT 9.7.1, pinned by SHA-256; installed into the git-ignored addons/.
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $downloadRoot = Join-Path $repoRoot '.tools\test-dependencies'
    $addonsRoot = Join-Path $repoRoot 'addons'
    New-Item -ItemType Directory -Force -Path $downloadRoot, $addonsRoot | Out-Null

    $dependency = @{
        Name = 'gut'
        Uri = 'https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip'
        Sha256 = '14969AA46ADC84AA08CDD21B9F6D1A64ADDD92AE60B36F02D0521ED305AA4086'
        ArchiveRoot = 'Gut-9.7.1\addons\gut'
        Marker = 'plugin.cfg'
    }

    $destination = Join-Path $addonsRoot $dependency.Name
    if (Test-Path -LiteralPath (Join-Path $destination $dependency.Marker)) {
        return
    }
    $archive = Join-Path $downloadRoot ($dependency.Name + '.zip')
    if (-not (Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest -UseBasicParsing -Uri $dependency.Uri -OutFile $archive
    }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actualHash -ne $dependency.Sha256) {
        throw "SHA-256 mismatch for $($dependency.Name): $actualHash"
    }
    $expanded = Join-Path $downloadRoot ($dependency.Name + '-expanded')
    Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
    Copy-Item -LiteralPath (Join-Path $expanded $dependency.ArchiveRoot) -Destination $destination -Recurse -Force
}
