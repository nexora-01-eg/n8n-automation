# Show-SafetyPlan.ps1 — طبقة الأمان: خطة مختصرة قبل أي تنفيذ (قراءة فقط، لا ينفذ شيئًا)
# Usage: powershell -ExecutionPolicy Bypass -File Show-SafetyPlan.ps1 -Spec "..\specs\x.spec.json" [-Workflow "..\workflows\x-v001.json"]
param([Parameter(Mandatory = $true)][string]$Spec, [string]$Workflow = "")
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Spec)) { throw "Spec not found: $Spec" }
$specObj = Get-Content -LiteralPath $Spec -Raw | ConvertFrom-Json
$wf = $null
if ($Workflow -ne "" -and (Test-Path -LiteralPath $Workflow)) { $wf = Get-Content -LiteralPath $Workflow -Raw | ConvertFrom-Json }

$nodeNames = @()
if ($wf) { $nodeNames = @($wf.nodes | ForEach-Object { "$($_.name) [$($_.type)]" }) }

$needsApproval = $false
$reasons = @()
if ($specObj.security -and $specObj.security.approvalRequired) { $needsApproval = $true; $reasons += "spec.security.approvalRequired=true" }
if ($specObj.externalServices -and $specObj.externalServices.Count -gt 0) { $needsApproval = $true; $reasons += "external services involved" }
if ($specObj.credentialsRequired -and $specObj.credentialsRequired.Count -gt 0) { $needsApproval = $true; $reasons += "credentials required (user must create in UI)" }
if ($specObj.notifications -and $specObj.notifications.Count -gt 0) { $needsApproval = $true; $reasons += "outbound notifications (real messages)" }
if ($specObj.security -and $specObj.security.sideEffects -and $specObj.security.sideEffects.Count -gt 0) { $needsApproval = $true; $reasons += "declared side effects" }

Write-Host "================ SAFETY PLAN ================"
Write-Host "Workflow:           $($specObj.slug) ($($specObj.version)) - $($specObj.goal)"
Write-Host "Trigger:            $($specObj.trigger.type) $($specObj.trigger.schedule) $($specObj.trigger.path) $($specObj.trigger.feedUrl)"
Write-Host "Nodes:              $(if ($nodeNames.Count -gt 0) { $nodeNames -join ' | ' } else { '(workflow not generated yet)' })"
Write-Host "External services:  $(if ($specObj.externalServices.Count -gt 0) { $specObj.externalServices -join ', ' } else { 'none' })"
Write-Host "Credentials required:"
if ($specObj.credentialsRequired.Count -eq 0) { Write-Host "  none" }
foreach ($c in $specObj.credentialsRequired) { Write-Host "  CREDENTIAL REQUIRED: service=$($c.service) type=$($c.type) reason=$($c.reason)" }
Write-Host "Data sent externally: $(if ($specObj.security.dataSentExternally.Count -gt 0) { $specObj.security.dataSentExternally -join ', ' } else { 'none' })"
Write-Host "Potential side effects: $(if ($specObj.security.sideEffects.Count -gt 0) { $specObj.security.sideEffects -join '; ' } else { 'none (local execution only)' })"
Write-Host "Actions requiring approval: $(if ($needsApproval) { $reasons -join '; ' } else { 'none' })"
Write-Host "============================================="
if ($needsApproval) { Write-Host "VERDICT: APPROVAL REQUIRED — do not execute side-effecting steps without explicit user approval." }
else { Write-Host "VERDICT: SAFE TO RUN LOCALLY (validation/backup/isolated tests auto-allowed)." }
