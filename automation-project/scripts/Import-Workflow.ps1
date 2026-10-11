# Import-Workflow.ps1 — استيراد Workflow إلى n8n بأمان (تحقق + Backup + استيراد + Restart + فحص)
# Usage: powershell -ExecutionPolicy Bypass -File Import-Workflow.ps1 -Path "..\workflows\my-flow.json"
param([Parameter(Mandatory = $true)][string]$Path, [switch]$SkipBackup)
$ErrorActionPreference = "Stop"

$scriptsDir = $PSScriptRoot
$projectDir = Split-Path -Parent $scriptsDir
$n8nDir = Split-Path -Parent $projectDir
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH

if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$file = Get-Item -LiteralPath $Path

Write-Host "Step 1/4: validating..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "Validate-Workflow.ps1") -Path $file.FullName
if ($LASTEXITCODE -ne 0) { throw "Validation failed, import aborted." }
Write-Host "Step 1b/4: code syntax check..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "Test-CodeSyntax.ps1") -Path $file.FullName
if ($LASTEXITCODE -ne 0) { throw "Syntax check failed, import aborted." }

if (-not $SkipBackup) {
  Write-Host "Step 2/4: backing up existing workflows..."
  & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "Backup-Workflows.ps1") -Label "before-import"
}

Write-Host "Step 3/4: importing via Server CLI..."
$stageDir = Join-Path $n8nDir "backups\stage"
New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-Item $file.FullName -Destination (Join-Path $stageDir $file.Name) -Force
& docker exec n8n n8n import:workflow --input="/backups/stage/$($file.Name)" 2>&1 | Select-Object -Last 3
if ($LASTEXITCODE -ne 0) { throw "Import failed." }

Write-Host "Step 4/4: restarting n8n so changes take effect, then health check..."
& docker restart n8n 2>&1 | Out-Null
Start-Sleep -Seconds 45
$health = Invoke-RestMethod -Uri "http://localhost:5678/healthz" -TimeoutSec 15
if ($health.status -ne "ok") { throw "n8n health check failed after restart!" }
Write-Host "IMPORT DONE + n8n healthy."
