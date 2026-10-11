# automation.ps1 — واجهة Autonomous Automation Engineer
# Usage (from this folder):
#   .\automation.ps1 new "وصف الأتمتة"
#   .\automation.ps1 plan <slug>
#   .\automation.ps1 validate <workflow-file>
#   .\automation.ps1 test <workflow-id>
#   .\automation.ps1 backup
#   .\automation.ps1 list
#   .\automation.ps1 inspect <workflow-id>
param([string]$Command = "", [string]$Arg = "", [string]$Label = "manual")
$ErrorActionPreference = "Stop"
$projectDir = $PSScriptRoot
$scriptsDir = Join-Path $projectDir "scripts"

function Run-Step([string]$Name, [string[]]$StepArgs) {
  powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir $Name) @StepArgs
  if ($LASTEXITCODE -ne 0) { throw "$Name failed." }
}
function Get-ArgSlug([string]$Text) {
  $s = $Text.ToLower().Replace(" ", "-")
  $s = $s -replace "[^a-z0-9\-]", ""
  $s = $s -replace "-+", "-"
  $s = $s.Trim("-")
  if ([string]::IsNullOrWhiteSpace($s)) { $s = "req-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
  if ($s.Length -gt 40) { $s = $s.Substring(0, 40).Trim("-") }
  return $s
}
function Get-LatestVersion([string]$Slug) {
  $files = Get-ChildItem -LiteralPath (Join-Path $projectDir "workflows") -Filter ($Slug + "-v*.json") -ErrorAction SilentlyContinue | Sort-Object Name
  if ($files -and $files.Count -gt 0) { return $files[-1].FullName }
  return ""
}
function Show-Usage {
  Write-Host "Usage:"
  Write-Host '  .\automation.ps1 new "وصف الأتمتة"'
  Write-Host "  .\automation.ps1 plan <slug>"
  Write-Host "  .\automation.ps1 validate <workflow-file>"
  Write-Host "  .\automation.ps1 test <workflow-id>"
  Write-Host "  .\automation.ps1 backup"
  Write-Host "  .\automation.ps1 list"
  Write-Host "  .\automation.ps1 inspect <workflow-id>"
}

if ([string]::IsNullOrWhiteSpace($Command)) { Show-Usage; exit 0 }
$cmd = $Command.ToLower()

if ($cmd -eq "new") {
  if ([string]::IsNullOrWhiteSpace($Arg)) { throw "new needs a description." }
  $slug = Get-ArgSlug $Arg
  $reqFile = Join-Path (Join-Path $projectDir "requests") ($slug + ".md")
  if (Test-Path -LiteralPath $reqFile) { throw "Request already exists: $reqFile" }
  $tpl = Get-Content -LiteralPath (Join-Path (Join-Path $projectDir "requests") "_template.md") -Raw
  $tpl = $tpl.Replace("__SLUG__", $slug).Replace("__DESC__", $Arg)
  $tpl | Out-File -LiteralPath $reqFile -Encoding utf8
  Write-Host "Request created:"
  Write-Host $reqFile
  Write-Host "Next: fill the sections, then run plan with the slug:"
  Write-Host $slug
  exit 0
}

if ($cmd -eq "plan") {
  if ([string]::IsNullOrWhiteSpace($Arg)) { throw "plan needs a slug." }
  $specFile = Join-Path (Join-Path $projectDir "specs") ($Arg + ".spec.json")
  if (-not (Test-Path -LiteralPath $specFile)) {
    $reqFile = Join-Path (Join-Path $projectDir "requests") ($Arg + ".md")
    Write-Host "No spec yet. Parsing request file."
    Run-Step "New-SpecFromRequest.ps1" @("-Request", $reqFile)
  }
  Run-Step "Test-Spec.ps1" @("-Path", $specFile)
  $wf = Get-LatestVersion $Arg
  if ($wf -ne "") { Run-Step "Show-SafetyPlan.ps1" @("-Spec", $specFile, "-Workflow", $wf) }
  if ($wf -eq "") { Run-Step "Show-SafetyPlan.ps1" @("-Spec", $specFile) }
  exit 0
}

if ($cmd -eq "validate") {
  if ([string]::IsNullOrWhiteSpace($Arg)) { throw "validate needs a workflow file." }
  Run-Step "Validate-Workflow.ps1" @("-Path", $Arg)
  exit 0
}

if ($cmd -eq "test") {
  if ([string]::IsNullOrWhiteSpace($Arg)) { throw "test needs a workflow id." }
  Run-Step "Test-ManualWorkflow.ps1" @("-Id", $Arg)
  exit 0
}

if ($cmd -eq "backup") {
  Run-Step "Backup-Workflows.ps1" @("-Label", $Label)
  exit 0
}

if ($cmd -eq "list") {
  $env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
  $prevEp = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { docker exec n8n n8n list:workflow 2>&1 | ForEach-Object { Write-Host ([string]$_) } } finally { $ErrorActionPreference = $prevEp }
  exit 0
}

if ($cmd -eq "inspect") {
  if ([string]::IsNullOrWhiteSpace($Arg)) { throw "inspect needs a workflow id." }
  $env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH
  $prevEp2 = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { $jsonOut = docker exec n8n n8n export:workflow --id=$Arg 2>$null } finally { $ErrorActionPreference = $prevEp2 }
  if ($LASTEXITCODE -ne 0) { throw "Workflow not found." }
  $wfObj = ([string]$jsonOut | Out-String) | ConvertFrom-Json
  Write-Host ("Name: " + $wfObj.name)
  Write-Host ("ID: " + $wfObj.id)
  Write-Host ("Active: " + $wfObj.active)
  Write-Host ("Nodes (" + $wfObj.nodes.Count + "):")
  foreach ($nd in $wfObj.nodes) {
    $credTxt = ""
    if ($nd.credentials) { $credTxt = " credentials=" + ((($nd.credentials.PSObject.Properties | ForEach-Object { $_.Name }) -join ",")) }
    Write-Host ("  - " + $nd.name + " <" + $nd.type + " v" + $nd.typeVersion + ">" + $credTxt)
  }
  $connCount = ($wfObj.connections.PSObject.Properties | Measure-Object).Count
  Write-Host ("Connections from " + $connCount + " source node(s).")
  exit 0
}

Show-Usage
throw "Unknown command."
