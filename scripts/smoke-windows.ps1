[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$GodotBin)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$reportRoot = Join-Path $repoRoot 'reports'
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$logPath = Join-Path $reportRoot 'windows-smoke.log'
& $GodotBin --headless --path $repoRoot --quit-after 120 2>&1 | Tee-Object -FilePath $logPath
$code = $LASTEXITCODE
if ($code -ne 0) { throw "Godot smoke failed with exit code $code" }
if (Select-String -Path $logPath -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet) { throw 'Godot smoke log contains an error marker.' }
Write-Host 'Windows Godot main-scene smoke passed.'
