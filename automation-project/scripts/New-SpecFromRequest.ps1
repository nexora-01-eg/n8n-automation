# New-SpecFromRequest.ps1 — تحويل طلب لغة طبيعية (Markdown مقسم) إلى Spec JSON
# القالب: requests\*.md بعناوين ## ثابتة. الذكاء (OpenCode) يملأ الفجوات؛ السكربت يستخرج ويتحقق.
# Usage: powershell -ExecutionPolicy Bypass -File New-SpecFromRequest.ps1 -Request "..\requests\news-ai.md"
param([Parameter(Mandatory = $true)][string]$Request)
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $Request)) { throw "Request file not found: $Request" }
$text = Get-Content -LiteralPath $Request -Raw

function Get-Section([string]$Title) {
  $m = [regex]::Match($text, "(?ms)^##\s+" + [regex]::Escape($Title) + "\s*\r?\n(.*?)(?=^##\s+|\z)")
  if ($m.Success) { return $m.Groups[1].Value.Trim() } else { return "" }
}
function Get-List([string]$Title) {
  $s = Get-Section $Title
  if ($s -eq "") { return @() }
  return @($s -split "`r?`n" | ForEach-Object { $_.Trim() -replace '^[-*]\s*', '' } | Where-Object { $_ -ne "" -and $_ -notmatch '^(لا يوجد|none|-|N/A)$' })
}

$slug = (Get-Section "Slug").Trim()
if ($slug -eq "") {
  $slug = [System.IO.Path]::GetFileNameWithoutExtension($Request) -replace '[^a-z0-9]+', '-'
}
$triggerRaw = (Get-Section "Trigger").Trim()
$triggerType = "manual"
if ($triggerRaw -match 'schedul|مجدول|كل ') { $triggerType = "schedule" }
elseif ($triggerRaw -match 'webhook|ويب هوك') { $triggerType = "webhook" }
elseif ($triggerRaw -match 'rss|آر إس إس|خلاصات|أخبار.*تلقائي') { $triggerType = "rss" }

$steps = Get-List "Steps"
$processing = @()
$i = 0
foreach ($s in $steps) { $i++; $processing += [ordered]@{ step = "step$i"; action = $s; node = "TODO: assigned by OpenCode" } }

$spec = [ordered]@{
  slug          = $slug
  version       = "v001"
  goal          = (Get-Section "Goal")
  trigger       = [ordered]@{ type = $triggerType; schedule = (Get-Section "Schedule"); httpMethod = "GET"; path = ""; feedUrl = (Get-Section "Feed URL") }
  inputs        = Get-List "Inputs"
  processing    = $processing
  conditions    = Get-List "Conditions"
  externalServices = Get-List "External Services"
  outputs       = [ordered]@{ description = (Get-Section "Outputs"); example = [ordered]@{}; storage = (Get-Section "Storage") }
  schedule      = (Get-Section "Schedule")
  errorHandling = [ordered]@{ onFailure = "stop"; notifyChannel = "" }
  retryPolicy   = [ordered]@{ maxRetries = 0; backoff = "" }
  deduplication = [ordered]@{ enabled = $false; key = ""; strategy = "" }
  storage       = (Get-Section "Storage")
  notifications = Get-List "Notifications"
  credentialsRequired = @()
  security      = [ordered]@{ dataSentExternally = @(); sideEffects = @(); approvalRequired = $false }
}

$dest = Join-Path (Join-Path $projectDir "specs") ("$slug.spec.json")
($spec | ConvertTo-Json -Depth 12) | Out-File -LiteralPath $dest -Encoding utf8
Write-Host "Spec draft created: $dest"
Write-Host "Next: OpenCode reviews/fills TODO fields, then runs Test-Spec.ps1"
& powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Test-Spec.ps1") -Path $dest
