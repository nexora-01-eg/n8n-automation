# Test-Spec.ps1 — التحقق من Automation Spec مقابل القواعد (بدون مكتبات خارجية)
# Usage: powershell -ExecutionPolicy Bypass -File Test-Spec.ps1 -Path "..\specs\news-ai.spec.json"
param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$errors = @()
$warnings = @()
try { $spec = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
catch { throw "Invalid JSON: $($_.Exception.Message)" }

foreach ($f in @("slug", "version", "goal", "trigger", "inputs", "processing", "outputs", "errorHandling", "retryPolicy", "credentialsRequired", "security")) {
  if ($null -eq $spec.$f) { $errors += "Missing required field: $f" }
}
if ($spec.version -and $spec.version -notmatch '^v\d{3}$') { $errors += "version must match vNNN (e.g. v001)." }
if ($spec.goal -and $spec.goal.Length -lt 10) { $errors += "goal too short." }
if ($spec.trigger) {
  $validTriggers = @("manual", "schedule", "webhook", "rss")
  if ($validTriggers -notcontains $spec.trigger.type) { $errors += "trigger.type must be one of: $($validTriggers -join ', ')." }
  if ($spec.trigger.type -eq "schedule" -and [string]::IsNullOrWhiteSpace($spec.trigger.schedule)) { $errors += "schedule trigger requires trigger.schedule." }
  if ($spec.trigger.type -eq "rss" -and [string]::IsNullOrWhiteSpace($spec.trigger.feedUrl)) { $errors += "rss trigger requires trigger.feedUrl." }
  if ($spec.trigger.type -eq "webhook" -and [string]::IsNullOrWhiteSpace($spec.trigger.path)) { $errors += "webhook trigger requires trigger.path." }
}
if ($spec.processing -and $spec.processing.Count -eq 0) { $errors += "processing must contain at least one step." }
if ($spec.outputs -and [string]::IsNullOrWhiteSpace($spec.outputs.description)) { $errors += "outputs.description required." }
if ($spec.errorHandling -and @("stop", "continue", "notify") -notcontains $spec.errorHandling.onFailure) { $errors += "errorHandling.onFailure must be stop|continue|notify." }
foreach ($c in @($spec.credentialsRequired)) {
  if ([string]::IsNullOrWhiteSpace($c.service) -or [string]::IsNullOrWhiteSpace($c.type) -or [string]::IsNullOrWhiteSpace($c.reason)) {
    $errors += "Each credentialsRequired entry needs service+type+reason."
  }
}
if ($spec.security) {
  if ($null -eq $spec.security.approvalRequired) { $errors += "security.approvalRequired required (true/false)." }
  if ($spec.externalServices -and $spec.externalServices.Count -gt 0 -and $spec.security.approvalRequired -ne $true) {
    $warnings += "External services present but approvalRequired != true. Safety plan will still require approval."
  }
}

Write-Host "Spec: $($spec.slug) $($spec.version)"
$warnings | ForEach-Object { Write-Host "WARNING: $_" }
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host "ERROR: $_" }; Write-Host "SPEC INVALID"; exit 1 }
Write-Host "SPEC VALID"
