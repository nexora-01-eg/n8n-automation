# New-WorkflowScaffold.ps1 — توليد هيكل Workflow جديد من اسم + وصف (نقطة بداية، يُكملها OpenCode)
# Usage: powershell -ExecutionPolicy Bypass -File New-WorkflowScaffold.ps1 -Name "My Flow" -Id "my-flow-00000001"
param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][string]$Id)
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
$dest = Join-Path (Join-Path $projectDir "workflows") ("$Id.json")
if (Test-Path -LiteralPath $dest) { throw "Workflow file already exists: $dest (no overwrite without approval)" }

$scaffold = [ordered]@{
  name   = $Name
  id     = $Id
  active = $false
  nodes  = @(
    [ordered]@{
      parameters  = [ordered]@{}
      id          = [guid]::NewGuid().ToString()
      name        = "Start"
      type        = "n8n-nodes-base.manualTrigger"
      typeVersion = 1
      position    = @(240, 300)
    },
    [ordered]@{
      parameters  = [ordered]@{ content = "## TODO: $Name`nDescribe nodes here, then ask OpenCode to build them."; height = 140; width = 320 }
      id          = [guid]::NewGuid().ToString()
      name        = "TODO"
      type        = "n8n-nodes-base.stickyNote"
      typeVersion = 1
      position    = @(240, 120)
    }
  )
  connections = [ordered]@{}
  settings    = [ordered]@{ executionOrder = "v1"; timezone = "Africa/Cairo" }
}
($scaffold | ConvertTo-Json -Depth 20) | Out-String | ForEach-Object { [System.IO.File]::WriteAllText($dest, $_, (New-Object System.Text.UTF8Encoding $false)) }
Write-Host "Scaffold created: $dest"
