[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-GrayboxGodot $GodotBin
Set-GrayboxGodotUserDirs
& $godot --path $repoRoot
exit $LASTEXITCODE
