# n8n Backup Script (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File "C:\Users\NOUR SOFT\n8n\backup-n8n.ps1"
# Strategy: stop n8n briefly (SQLite files are locked while running), zip data, start again.
$ErrorActionPreference = "Stop"
$n8nDir = "C:\Users\NOUR SOFT\n8n"
$dataDir = Join-Path $n8nDir "n8n_data"
$backupDir = Join-Path $n8nDir "backups"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = Join-Path $backupDir "n8n-backup-$timestamp.zip"

if (-not (Test-Path -LiteralPath $dataDir)) { throw "Data dir not found: $dataDir" }
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH

function Invoke-DockerCompose([string[]]$ComposeArgs) {
  # docker writes progress to stderr; keep native stderr non-terminating
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & docker @ComposeArgs 2>&1 | Out-String | Write-Host } finally { $ErrorActionPreference = $prev }
  if ($LASTEXITCODE -ne 0) { throw "docker $ComposeArgs failed with exit code $LASTEXITCODE" }
}

Write-Host "Stopping n8n for consistent backup..."
Invoke-DockerCompose @("compose", "--project-directory", $n8nDir, "stop")
try {
  Compress-Archive -Path "$dataDir\*", (Join-Path $n8nDir ".env"), (Join-Path $n8nDir "docker-compose.yml") -DestinationPath $backupFile -Force
  Write-Host "Backup created: $backupFile"
} finally {
  Write-Host "Starting n8n again..."
  Invoke-DockerCompose @("compose", "--project-directory", $n8nDir, "start")
}

# Keep only last 10 backups
Get-ChildItem -LiteralPath $backupDir -Filter "n8n-backup-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force
Write-Host "Done. n8n status:"
docker ps --format "table {{.Names}}`t{{.Status}}" | Select-String "n8n"
Write-Host "To restore, run: powershell -ExecutionPolicy Bypass -File `"$n8nDir\restore-n8n.ps1`" -BackupFile `"$backupFile`""
