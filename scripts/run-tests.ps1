[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotBin)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup-gut.ps1')
$reportRoot = Join-Path $repoRoot 'reports\gut'
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
& $GodotBin --headless --path $repoRoot -s res://addons/gut/gut_cmdln.gd -gdir=res://src/tests -ginclude_subdirs -gexit -gjunit_xml_file=res://reports/gut/results.xml
$code = $LASTEXITCODE
Write-Host "GUT exit code: $code"
exit $code
