# opportunity-hunter.ps1 — CLI for Opportunity Hunter (Windows)
# Usage: .\opportunity-hunter.ps1 doctor|run|status|stats|sources|opportunities|backup|test
param([string]$Command = "status", [string]$Arg = "")
$ErrorActionPreference = "Stop"
$proj = $PSScriptRoot
$API = "http://localhost:8091"

function Api-Get([string]$Path) {
  return Invoke-RestMethod -Uri ($API + $Path) -TimeoutSec 30
}
function Docker-Env {
  $env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
}
switch ($Command.ToLower()) {
  "doctor" {
    Docker-Env
    echo "--- container ---"
    docker ps --format "{{.Names}} {{.Status}}" | Select-String "opportunity-hunter"
    echo "--- api ---"
    Api-Get "/api/health" | ConvertTo-Json -Compress
    echo ""
    echo "--- n8n ---"
    (Invoke-WebRequest -Uri "http://localhost:5678/healthz" -UseBasicParsing -TimeoutSec 15).Content
    echo ""
    echo "--- db ---"
    Get-Item (Join-Path $proj "database\opps.db") | Select-Object Name, @{N = "KB"; E = { [math]::Round($_.Length / 1KB, 1) } }
  }
  "run" {
    $body = if ($Arg -ne "") { $Arg } else { '{}' }
    Api-Get "/api/health" | Out-Null
    Invoke-RestMethod -Uri ($API + "/api/run") -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600 | ConvertTo-Json -Depth 4
  }
  "status" { Api-Get "/api/health" | ConvertTo-Json -Compress; Api-Get "/api/stats" | ConvertTo-Json -Compress }
  "stats" { Api-Get "/api/stats" | ConvertTo-Json -Depth 4 }
  "sources" { Api-Get "/api/sources" | ConvertTo-Json -Depth 4 }
  "opportunities" {
    $q = if ($Arg -ne "") { $Arg } else { "?per_page=10&sort=opportunity_score" }
    $d = Api-Get ("/api/opportunities" + $q)
    echo "total=$($d.total) page=$($d.page)"
    $d.items | ForEach-Object { echo "#$($_.id) [$($_.opportunity_score)] [$($_.status)] $($_.title.Substring(0, [Math]::Min(75, $_.title.Length)))" }
  }
  "backup" {
    Docker-Env
    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $dest = Join-Path (Join-Path $proj "backups") $ts
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item (Join-Path $proj "database\opps.db*") -Destination $dest -Force
    docker exec n8n n8n export:workflow --id=opportunity-hunter-v001 --output=/backups/auto/oh-v001.json 2>&1 | Select-Object -Last 1
    Copy-Item "$env:USERPROFILE\n8n\backups\auto\oh-v001.json" -Destination (Join-Path $dest "workflow.json") -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $proj "config\app.json") -Destination $dest -Force
    Get-ChildItem -LiteralPath $dest | Select-Object Name
    Get-ChildItem -LiteralPath (Join-Path $proj "backups") -Directory | Sort-Object Name -Descending | Select-Object -Skip 10 | Remove-Item -Recurse -Force
    echo "backup: $dest (retention: last 10)"
  }
  "test" {
    Docker-Env
    docker exec opportunity-hunter python -m unittest discover -s /app/tests -v 2>&1 | Select-Object -Last 25
  }
  default { echo "commands: doctor|run|status|stats|sources|opportunities|backup|test" }
}
