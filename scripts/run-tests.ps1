[CmdletBinding()]
param([string]$GodotBin = '')

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run-gut.ps1') -GodotBin $GodotBin
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
& (Join-Path $PSScriptRoot 'run-gdunit4.ps1') -GodotBin $GodotBin
exit $LASTEXITCODE
