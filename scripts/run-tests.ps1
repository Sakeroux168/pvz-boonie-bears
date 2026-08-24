[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Resolve-P2Godot $GodotBin
Set-P2GodotUserDirs
Initialize-P2TestDependencies
New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot 'reports\gut') | Out-Null

# Run via Start-Process so the process exit code is captured reliably.
# ($LASTEXITCODE after a redirected native call is not dependable on
# Windows PowerShell 5.1, which broke CI failure detection.)
$gutArgs = @(
    '--headless',
    ('--path ' + $repoRoot),
    '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gdir=res://src/tests/gut', '-ginclude_subdirs',
    '-gjunit_xml_file=res://reports/gut/results.xml',
    '-gexit'
)
$proc = Start-Process -FilePath $godot -ArgumentList $gutArgs -Wait -PassThru -NoNewWindow
# Godot's exit code must propagate verbatim: 0 = all green, non-zero = failures.
exit $proc.ExitCode
