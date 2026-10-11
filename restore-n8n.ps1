# n8n Restore Script (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File "C:\Users\NOUR SOFT\n8n\restore-n8n.ps1" -BackupFile "C:\Users\NOUR SOFT\n8n\backups\n8n-backup-YYYYMMDD-HHMMSS.zip"
param([Parameter(Mandatory=$true)][string]$BackupFile)
$ErrorActionPreference = "Stop"
$n8nDir = "C:\Users\NOUR SOFT\n8n"
$dataDir = Join-Path $n8nDir "n8n_data"

if (-not (Test-Path -LiteralPath $BackupFile)) { throw "Backup file not found: $BackupFile" }

Write-Host "Stopping n8n (if running)..."
try { docker stop n8n 2>$null } catch {}
try { docker compose --project-directory "$n8nDir" down 2>$null } catch {}

if (Test-Path -LiteralPath $dataDir) {
  $old = "$dataDir.before-restore-" + (Get-Date -Format "yyyyMMdd-HHmmss")
  Rename-Item -LiteralPath $dataDir -NewName (Split-Path $old -Leaf)
  Write-Host "Old data moved to: $old"
}
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

# Extract backup to temp, then copy contents correctly
$tempDir = Join-Path $env:TEMP ("n8n-restore-" + (Get-Date -Format "yyyyMMddHHmmss"))
Expand-Archive -LiteralPath $BackupFile -DestinationPath $tempDir -Force
# Backup zip contains: n8n_data contents at root + .env + docker-compose.yml
Copy-Item (Join-Path $tempDir ".env") (Join-Path $n8nDir ".env") -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $tempDir "docker-compose.yml") (Join-Path $n8nDir "docker-compose.yml") -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $tempDir -Exclude ".env","docker-compose.yml" | Copy-Item -Destination $dataDir -Recurse -Force
Remove-Item -LiteralPath $tempDir -Recurse -Force
Write-Host "Restore done. Start with: docker compose --project-directory `"$n8nDir`" up -d"
