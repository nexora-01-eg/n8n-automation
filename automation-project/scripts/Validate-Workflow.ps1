# Validate-Workflow.ps1 — التحقق من Workflow قبل استيراده إلى n8n
# Usage: powershell -ExecutionPolicy Bypass -File Validate-Workflow.ps1 -Path "..\workflows\my-flow.json"
param([Parameter(Mandatory = $true)][string]$Path, [string]$AllowListPath = "")
$ErrorActionPreference = "Stop"

# Allowlist افتراضية من نفس مجلد السكربت (أنواع n8n المثبتة فعليًا)
if ($AllowListPath -eq "") {
  $defaultAllow = Join-Path $PSScriptRoot "node-types-allowlist.json"
  if (Test-Path -LiteralPath $defaultAllow) { $AllowListPath = $defaultAllow }
}

if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$errors = @()
$warnings = @()

# n8n CLI يرفض BOM — فحص مبكر برسالة واضحة
$firstBytes = [System.IO.File]::ReadAllBytes($Path)[0..2]
if ($firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) {
  $errors += "File starts with UTF-8 BOM, which n8n CLI import rejects. Re-save without BOM."
}

try { $wf = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
catch { throw "Invalid JSON: $($_.Exception.Message)" }

if ([string]::IsNullOrWhiteSpace($wf.name)) { $errors += "Missing workflow 'name'." }
if (-not $wf.nodes -or $wf.nodes.Count -eq 0) { $errors += "Workflow has no 'nodes'." }
if ($null -eq $wf.connections) { $errors += "Missing 'connections' object." }

$triggerTypes = @("n8n-nodes-base.manualTrigger", "n8n-nodes-base.webhook", "n8n-nodes-base.scheduleTrigger",
  "n8n-nodes-base.errorTrigger", "n8n-nodes-base.executeWorkflowTrigger")
$hasTrigger = $false
foreach ($n in $wf.nodes) {
  if ([string]::IsNullOrWhiteSpace($n.name)) { $errors += "A node is missing 'name'." }
  if ([string]::IsNullOrWhiteSpace($n.type)) { $errors += "Node '$($n.name)' is missing 'type'." }
  if ($null -eq $n.position) { $warnings += "Node '$($n.name)' has no 'position' (UI layout)." }
  if ($triggerTypes -contains $n.type) { $hasTrigger = $true }
}
if (-not $hasTrigger) { $warnings += "No trigger node found (manual/webhook/schedule). Workflow may not start on its own." }

# --- Secret scan: قيم حساسة داخل الباراميترات ممنوعة ---
$secretKeyPattern = 'api[_-]?key|passwd|password|secret|token|bearer|authorization|private[_-]?key|client[_-]?secret'
$json = Get-Content -LiteralPath $Path -Raw
# ابحث عن مفاتيح حساسة بقيم ثابتة (ليست Expression تبدأ بـ = )
$rx = [regex]'"(?<k>[^"]*?(?:api[_-]?key|password|passwd|secret|token|bearer|authorization|private[_-]?key|client[_-]?secret)[^"]*?)"\s*:\s*"(?<v>[^"]+)"'
foreach ($m in $rx.Matches($json)) {
  $v = $m.Groups['v'].Value
  if ($v -ne "" -and -not $v.StartsWith("=") -and -not $v.StartsWith("{{") -and $v -ne "string" -and $v -ne "number") {
    # تجاهل أسماء الحقول الوصفية مثل "name": "message"
    if ($m.Groups['k'].Value -notmatch '^(name|id|value|type)$') {
      $errors += "Possible hardcoded secret in key '$($m.Groups['k'].Value)'. Use n8n Credentials instead."
    }
  }
}

Write-Host "Workflow: $($wf.name) | Nodes: $($wf.nodes.Count)"
$warnings | ForEach-Object { Write-Host "WARNING: $_" }

# --- Node type allowlist (PHASE 3): يجب أن تكون الأنواع من n8n المثبت ---
if ($AllowListPath -ne "" -and (Test-Path -LiteralPath $AllowListPath)) {
  $allow = (Get-Content -LiteralPath $AllowListPath -Raw | ConvertFrom-Json).nodeVersions
  foreach ($n in $wf.nodes) {
    if ($null -eq $allow.($n.type)) { $errors += "Node type not installed in this n8n: '$($n.type)' (node '$($n.name)')." }
  }
  Write-Host "Node-type check: allowlist loaded ($(($allow.PSObject.Properties | Measure-Object).Count) types)."
} else {
  Write-Host "WARNING: allowlist not found, skipping node-type check."
}

# --- Connection targets must exist ---
if ($wf.connections) {
  $names = @($wf.nodes | ForEach-Object { $_.name })
  foreach ($from in $wf.connections.PSObject.Properties.Name) {
    if ($names -notcontains $from) { $errors += "Connection from unknown node: $from" }
    foreach ($prop in $wf.connections.$from.PSObject.Properties) {
      foreach ($branch in @($prop.Value)) {
        foreach ($t in @($branch)) {
          if ($t -and $t.node -and $names -notcontains $t.node) { $errors += "Connection to unknown node: $($t.node)" }
        }
      }
    }
  }
}

# --- Expressions balance: افحص كل قيمة نصية تحتوي {{ على حدة ---
# (أقواس JS المفردة مثل }} في كود عادي تُتجاهل — المهم توازن أسطر الـ Expressions)
$script:exprErrors = @()
function Test-ExprNode($Obj) {
  if ($Obj -is [string]) {
    if ($Obj -match '\{\{') {
      $o = ([regex]::Matches($Obj, '\{\{')).Count
      $c = ([regex]::Matches($Obj, '\}\}')).Count
      if ($o -ne $c) { $script:exprErrors += "Unbalanced expression: '$($Obj.Substring(0, [Math]::Min(80, $Obj.Length)))...' ({{=$o, }}=$c)" }
    }
  } elseif ($Obj -is [System.Collections.IEnumerable] -and -not ($Obj -is [byte[]])) {
    foreach ($item in $Obj) { Test-ExprNode $item }
  } elseif ($Obj -is [PSCustomObject]) {
    foreach ($prop in $Obj.PSObject.Properties) { Test-ExprNode $prop.Value }
  }
}
Test-ExprNode $wf
$errors += $script:exprErrors
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Host "ERROR: $_" }
  Write-Host "VALIDATION FAILED"
  exit 1
}
Write-Host "VALIDATION PASSED"
