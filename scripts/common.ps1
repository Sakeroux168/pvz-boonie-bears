function Resolve-GrayboxGodot {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    if ($env:GODOT_BIN) {
        return (Resolve-Path -LiteralPath $env:GODOT_BIN).Path
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $bundled = Get-ChildItem -LiteralPath (Join-Path $repoRoot '.tools\godot') -Filter '*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bundled) {
        return $bundled.FullName
    }

    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    throw 'Godot not found. Pass -GodotBin or set GODOT_BIN to the Godot 4.7.2 console executable.'
}

function Set-GrayboxGodotUserDirs {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $userRoot = Join-Path $repoRoot '.tools\userdata'
    $roaming = Join-Path $userRoot 'Roaming'
    $local = Join-Path $userRoot 'Local'
    New-Item -ItemType Directory -Force -Path $roaming, $local | Out-Null
    $env:APPDATA = $roaming
    $env:LOCALAPPDATA = $local
}

function Initialize-GrayboxTestDependencies {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $downloadRoot = Join-Path $repoRoot '.tools\test-dependencies'
    $addonsRoot = Join-Path $repoRoot 'addons'
    New-Item -ItemType Directory -Force -Path $downloadRoot, $addonsRoot | Out-Null

    $dependencies = @(
        @{
            Name = 'gut'
            Uri = 'https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip'
            Sha256 = '14969AA46ADC84AA08CDD21B9F6D1A64ADDD92AE60B36F02D0521ED305AA4086'
            ArchiveRoot = 'Gut-9.7.1\addons\gut'
            Marker = 'plugin.cfg'
        },
        @{
            Name = 'gdUnit4'
            Uri = 'https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.2.0.zip'
            Sha256 = '99E86A1C0C91DEEF9AB88C4A0BFEA8802BF2D6FFB8167634C16CA12FEE16338B'
            ArchiveRoot = 'gdUnit4-6.2.0\addons\gdUnit4'
            Marker = 'plugin.cfg'
        }
    )

    foreach ($dependency in $dependencies) {
        $destination = Join-Path $addonsRoot $dependency.Name
        if (Test-Path -LiteralPath (Join-Path $destination $dependency.Marker)) {
            continue
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

    $generatedRoot = Join-Path $repoRoot '.generated-tests'
    $gutGenerated = Join-Path $generatedRoot 'gut'
    $gdUnitGenerated = Join-Path $generatedRoot 'gdunit4'
    New-Item -ItemType Directory -Force -Path $gutGenerated, $gdUnitGenerated | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src\tests\gut\test_graybox_spec.gd.template') -Destination (Join-Path $gutGenerated 'test_graybox_spec.gd') -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src\tests\gdunit4\GrayboxSpecTest.gd.template') -Destination (Join-Path $gdUnitGenerated 'GrayboxSpecTest.gd') -Force
}
