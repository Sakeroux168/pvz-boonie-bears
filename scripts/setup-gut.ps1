[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$addonsRoot = Join-Path $repoRoot 'addons'
$gutRoot = Join-Path $addonsRoot 'gut'
if (Test-Path -LiteralPath (Join-Path $gutRoot 'plugin.cfg')) {
    Write-Host 'GUT 9.7.1 already present.'
    exit 0
}
$tools = Join-Path $repoRoot '.tools'
$archive = Join-Path $tools 'gut-9.7.1.zip'
$expanded = Join-Path $tools 'gut-expanded'
New-Item -ItemType Directory -Force -Path $tools, $addonsRoot | Out-Null
$uri = 'https://github.com/bitwes/Gut/archive/refs/tags/v9.7.1.zip'
$expected = '14969AA46ADC84AA08CDD21B9F6D1A64ADDD92AE60B36F02D0521ED305AA4086'
if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $archive }
$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($actual -ne $expected) { throw "GUT SHA-256 mismatch: $actual" }
if (Test-Path -LiteralPath $expanded) { Remove-Item -LiteralPath $expanded -Recurse -Force }
Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
Copy-Item -LiteralPath (Join-Path $expanded 'Gut-9.7.1\addons\gut') -Destination $gutRoot -Recurse -Force
Write-Host 'Installed GUT 9.7.1.'
