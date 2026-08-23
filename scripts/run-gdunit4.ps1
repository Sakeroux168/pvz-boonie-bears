[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-GrayboxGodot $GodotBin
Set-GrayboxGodotUserDirs
Initialize-GrayboxTestDependencies
Push-Location $repoRoot
try {
    & $godot --headless --path $repoRoot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://.generated-tests/gdunit4 -rd res://reports/gdunit4 -c
    $testExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $testExitCode
