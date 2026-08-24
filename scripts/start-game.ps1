[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotBin)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
& $GodotBin --path $repoRoot
exit $LASTEXITCODE
