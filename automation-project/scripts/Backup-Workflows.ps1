# Backup-Workflows.ps1 — نسخ احتياطي لكل الـ Workflows والـ Credentials (مشفرة) قبل أي تعديل
# Usage: powershell -ExecutionPolicy Bypass -File Backup-Workflows.ps1 [-Label "before-change"]
param([string]$Label = "manual")
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
$n8nDir = Split-Path -Parent $projectDir
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = Join-Path (Join-Path $projectDir "backups") "$ts-$Label"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "Exporting workflows (server running, read-only)..."
& docker exec n8n n8n export:workflow --backup --output=/backups/auto 2>&1 | Select-Object -Last 3
Write-Host "Exporting credentials (ENCRYPTED - never use --decrypted)..."
Remove-Item (Join-Path $n8nDir "backups\auto\credentials.json") -Force -ErrorAction SilentlyContinue
& docker exec n8n n8n export:credentials --all --output=/backups/auto/credentials.json 2>&1 | Select-Object -Last 2
if (-not (Test-Path -LiteralPath (Join-Path $n8nDir "backups\auto\credentials.json"))) {
  Write-Host "WARNING: no credentials exported (none exist yet - normal before owner setup)."
}

$stage = Join-Path $n8nDir "backups\auto"
if (Test-Path -LiteralPath $stage) {
  Copy-Item "$stage\*" -Destination $dest -Recurse -Force
  Write-Host "Backup saved to: $dest"
  Get-ChildItem -LiteralPath $dest | Select-Object Name
} else {
  throw "Export stage not found: $stage"
}
