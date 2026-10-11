# Test-ManualWorkflow.ps1 — تنفيذ فعلي لـ Workflow (Manual Trigger) بدون واجهة
# الطريقة: إيقاف السيرفر مؤقتًا + تنفيذ عبر حاوية مؤقتة بنفس الإعدادات + إعادة التشغيل + فحص
# Usage: powershell -ExecutionPolicy Bypass -File Test-ManualWorkflow.ps1 -Id "demo-hello-e2e-01"
param([Parameter(Mandatory = $true)][string]$Id, [string]$SaveTo = "")
$ErrorActionPreference = "Stop"

$n8nDir = "C:\Users\NOUR SOFT\n8n"
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH

function Invoke-Compose([string[]]$ComposeArgs) {
  # docker يكتب التقدم على stderr — يجب ألا يكون قاتلًا مع EPS=Stop
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & docker @ComposeArgs 2>&1 | ForEach-Object { Write-Host "$_" } } finally { $ErrorActionPreference = $prev }
  if ($LASTEXITCODE -ne 0) { throw "docker $ComposeArgs failed with exit code $LASTEXITCODE" }
}

Write-Host "Stopping n8n server for isolated execution test..."
Invoke-Compose @("compose", "--project-directory", $n8nDir, "stop")
try {
  Write-Host "Executing workflow id=$Id ..."
  # حاوية مؤقتة (--rm) بنفس الصورة والبيانات، بدون نشر منافذ، تُحذف تلقائيًا بعد التنفيذ
  # stderr (بانر n8n) يُفصل في ملف حتى لا يلوث JSON الخارج من stdout
  $errLog = Join-Path $env:TEMP "n8n-run-$Id.log"
  Remove-Item $errLog -Force -ErrorAction SilentlyContinue
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { $out = & docker compose --project-directory "$n8nDir" run --rm n8n execute --id=$Id --rawOutput 2>$errLog } finally { $ErrorActionPreference = $prev }
  $runExit = $LASTEXITCODE
  if ($runExit -ne 0) {
    Write-Host "----- STDOUT tail (n8n output) -----"
    @($out) | Select-Object -Last 25 | ForEach-Object { Write-Host "$_" }
    Write-Host "----- STDERR tail (diagnostics) -----"
    Get-Content $errLog -ErrorAction SilentlyContinue | Select-Object -Last 25 | ForEach-Object { Write-Host "$_" }
    throw "Workflow execution failed (exit $runExit)."
  }
  Write-Host "----- EXECUTION OUTPUT -----"
  $out | ForEach-Object { Write-Host $_ }
  Write-Host "----------------------------"
  $lines = @($out)
  # ناتج --rawOutput هو كائن JSON يبدأ بسطر "{" وينتهي بسطر "}" — تجاهل بانر n8n (مثل "[license SDK] ...")
  $startIdx = -1; $endIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($startIdx -eq -1 -and $lines[$i] -match '^\s*\{\s*$') { $startIdx = $i }
    if ($lines[$i] -match '^\s*\}\s*$') { $endIdx = $i }
  }
  if ($startIdx -eq -1 -or $endIdx -eq -1 -or $endIdx -le $startIdx) {
    Write-Host "----- STDOUT (diagnostics) -----"
    $lines | Select-Object -First 15 | ForEach-Object { Write-Host $_ }
    throw "Could not isolate execution JSON from output."
  }
  $json = ($lines[$startIdx..$endIdx] -join "`n")
  if ([string]::IsNullOrWhiteSpace($json)) { throw "No JSON output captured from execution." }
  $parsed = $json | ConvertFrom-Json
  Write-Host "EXECUTION OK: valid JSON output captured."
  if ($SaveTo -ne "") {
    if (Test-Path -LiteralPath $SaveTo) { Remove-Item -LiteralPath $SaveTo -Force }
    $runData = $parsed.data.resultData.runData
    $allNodes = [ordered]@{}
    foreach ($prop in $runData.PSObject.Properties) {
      try {
        $items = @($prop.Value[0].data.main[0] | ForEach-Object { $_.json })
        $allNodes[$prop.Name] = @($items)
      } catch { $allNodes[$prop.Name] = @("unreadable") }
    }
    @{ workflowId = $Id; status = $parsed.status; nodes = $allNodes } |
      ConvertTo-Json -Depth 12 | Out-String | ForEach-Object { [System.IO.File]::WriteAllText($SaveTo, $_, (New-Object System.Text.UTF8Encoding $false)) }
    Write-Host "Evidence saved: $SaveTo ($($allNodes.Keys.Count) nodes)"
  }
  return $parsed
} finally {
  Write-Host "Starting n8n server again..."
  Invoke-Compose @("compose", "--project-directory", $n8nDir, "start")
  Start-Sleep -Seconds 40
  $health = Invoke-RestMethod -Uri "http://localhost:5678/healthz" -TimeoutSec 15
  if ($health.status -ne "ok") { throw "n8n did not recover after test!" }
  Write-Host "n8n server is healthy again."
}
