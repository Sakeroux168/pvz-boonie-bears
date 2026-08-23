[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-P2Godot $GodotBin
Set-P2GodotUserDirs
Initialize-P2TestDependencies
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot 'reports\gut') | Out-Null
& $godot --headless --path $repoRoot -s res://addons/gut/gut_cmdln.gd -gdir=res://src/tests/gut -ginclude_subdirs -gjunit_xml_file=res://reports/gut/results.xml -gexit
exit $LASTEXITCODE
