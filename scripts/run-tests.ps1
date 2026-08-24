[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotBin)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup-gut.ps1')
$reportRoot = Join-Path $repoRoot 'reports\gut'
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null

# Run via Start-Process so the process exit code is captured reliably.
# ($LASTEXITCODE after a redirected native call is not dependable on
# Windows PowerShell 5.1, which broke CI failure detection. Ported from
# the PR #6 branch where the approach was verified.)
$gutArgs = @(
    '--headless',
    ('--path ' + $repoRoot),
    '-s', 'res://addons/gut/gut_cmdln.gd',
    '-gdir=res://src/tests', '-ginclude_subdirs',
    '-gjunit_xml_file=res://reports/gut/results.xml',
    '-gexit'
)
$proc = Start-Process -FilePath $GodotBin -ArgumentList $gutArgs -Wait -PassThru -NoNewWindow
$code = $proc.ExitCode
Write-Host "GUT exit code: $code"
exit $code
