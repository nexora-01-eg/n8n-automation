# Test-CodeSyntax.ps1 — فحص صياغة كل Code nodes بـ node --check داخل حاوية n8n
# يمسك أخطاء الـ Syntax قبل الاستيراد (الـ JSON الصحيح لا يكفي).
# Usage: powershell -ExecutionPolicy Bypass -File Test-CodeSyntax.ps1 -Path "..\workflows\x.json"
param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
$n8nDir = Split-Path -Parent $projectDir
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
$wf = Get-Content -LiteralPath $Path -Encoding utf8 -Raw | ConvertFrom-Json
$codeNodes = @($wf.nodes | Where-Object { $_.type -eq "n8n-nodes-base.code" -and $_.parameters.jsCode })
if ($codeNodes.Count -eq 0) { Write-Host "No Code nodes. SKIP."; exit 0 }

$stage = Join-Path $n8nDir "backups\stage"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$fail = 0
foreach ($n in $codeNodes) {
  $safe = ($n.name -replace '[^a-z0-9]+', '-')
  $f = Join-Path $stage ("syntax-$safe.js")
  [System.IO.File]::WriteAllText($f, $n.parameters.jsCode, (New-Object System.Text.UTF8Encoding $false))
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { $r = & docker exec n8n node --check ("/backups/stage/syntax-$safe.js") 2>&1 } finally { $ErrorActionPreference = $prev }
  Remove-Item $f -Force -ErrorAction SilentlyContinue
  if ($LASTEXITCODE -ne 0) {
    Write-Host "SYNTAX FAIL: $($n.name)"
    Write-Host "$r" | Select-Object -First 4
    $fail++
  } else {
    Write-Host "SYNTAX OK: $($n.name)"
  }
}
if ($fail -gt 0) { throw "$fail Code node(s) have syntax errors." }
Write-Host "ALL $($codeNodes.Count) CODE NODES SYNTAX OK"
