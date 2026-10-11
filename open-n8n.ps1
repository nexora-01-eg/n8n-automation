# open-n8n.ps1 — ضغطة واحدة تفتح n8n مهما كانت الحالة
# 1) لو n8n شغال: يفتح المتصفح فورًا. 2) لو مطفي: يشغل Docker ويستناه ثم يفتح.
$ErrorActionPreference = "Continue"
function Say($m) { Write-Host $m }

function Test-N8n {
  try {
    $r = Invoke-WebRequest -Uri "http://localhost:5678/healthz" -UseBasicParsing -TimeoutSec 8
    return ($r.StatusCode -eq 200)
  } catch { return $false }
}

if (Test-N8n) {
  Say "n8n is already running - opening browser..."
  Start-Process "http://localhost:5678"
  exit 0
}

Say "n8n is not running. Starting Docker Desktop (may take 1-2 minutes)..."
$dd = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
if (-not $dd) {
  Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"
}
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
$up = $false
for ($i = 1; $i -le 15; $i++) {
  Start-Sleep -Seconds 20
  $o = docker info 2>&1 | Out-String
  if ($o -match "Server Version") { $up = $true; break }
  Say "waiting for Docker... ($i/15)"
}
if (-not $up) { Say "Docker did not start. Open Docker Desktop manually, then run this again."; Read-Host "Press Enter to close"; exit 1 }

Say "Docker is up. Waiting for n8n..."
$ok = $false
for ($i = 1; $i -le 12; $i++) {
  Start-Sleep -Seconds 10
  if (Test-N8n) { $ok = $true; break }
  Say "waiting for n8n... ($i/12)"
}
if (-not $ok) { Say "n8n did not respond. Check Docker Desktop containers."; Read-Host "Press Enter to close"; exit 1 }

Say "Opening n8n in your browser..."
Start-Process "http://localhost:5678"
Start-Sleep -Seconds 3
