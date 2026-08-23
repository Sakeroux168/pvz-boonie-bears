[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-GrayboxGodot $GodotBin
Set-GrayboxGodotUserDirs
Initialize-GrayboxTestDependencies
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot 'reports\gut') | Out-Null
& $godot --headless --path $repoRoot -s res://addons/gut/gut_cmdln.gd -gdir=res://.generated-tests/gut -ginclude_subdirs -gjunit_xml_file=res://reports/gut/results.xml -gexit
exit $LASTEXITCODE
