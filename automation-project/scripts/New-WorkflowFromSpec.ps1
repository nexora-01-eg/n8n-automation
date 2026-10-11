# New-WorkflowFromSpec.ps1 — مولد Workflows من Spec (هيكل + Gates رسمية، يُكمل OpenCode التفاصيل)
# Gates قبل الكتابة: node types ∈ allowlist الإصدار المثبت / connections سليمة / expressions متوازنة / بلا أسرار / Error Handling
# Usage: powershell -ExecutionPolicy Bypass -File New-WorkflowFromSpec.ps1 -Spec "..\specs\x.spec.json"
param([Parameter(Mandatory = $true)][string]$Spec)
$ErrorActionPreference = "Stop"

$scriptsDir = $PSScriptRoot
$projectDir = Split-Path -Parent $scriptsDir
if (-not (Test-Path -LiteralPath $Spec)) { throw "Spec not found: $Spec" }
$specObj = Get-Content -LiteralPath $Spec -Raw | ConvertFrom-Json

& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "Test-Spec.ps1") -Path $Spec
if ($LASTEXITCODE -ne 0) { throw "Spec invalid, generation aborted." }

$allowPath = Join-Path $scriptsDir "node-types-allowlist.json"
if (-not (Test-Path -LiteralPath $allowPath)) { throw "Allowlist missing: $allowPath" }
$allow = (Get-Content -LiteralPath $allowPath -Raw | ConvertFrom-Json).nodeVersions
function Assert-NodeType([string]$Type) {
  if ($null -eq $allow.$Type) { throw "Node type not available in installed n8n: $Type" }
}

$outName = "$($specObj.slug)-$($specObj.version).json"
$dest = Join-Path (Join-Path $projectDir "workflows") $outName
if (Test-Path -LiteralPath $dest) { throw "Version file already exists: $dest — bump version with New-WorkflowVersion.ps1" }

function New-Id { return [guid]::NewGuid().ToString() }
$nodes = @()
$conns = [ordered]@{}
$x = 240
function Add-Node($Node) { $script:nodes += $Node }
function Link($From, $To, $OutIndex = 0) {
  if (-not $conns.Contains($From)) { $conns[$From] = [ordered]@{} }
  if (-not $conns[$From].Contains("main")) { $conns[$From]["main"] = @() }
  while ($conns[$From]["main"].Count -le $OutIndex) { $conns[$From]["main"] += ,@() }
  $conns[$From]["main"][$OutIndex] += [ordered]@{ node = $To; type = "main"; index = 0 }
}

# ---- Trigger ----
$triggerName = "Trigger"
switch ($specObj.trigger.type) {
  "manual" {
    Assert-NodeType "n8n-nodes-base.manualTrigger"
    Add-Node ([ordered]@{ parameters = [ordered]@{}; id = (New-Id); name = $triggerName; type = "n8n-nodes-base.manualTrigger"; typeVersion = 1; position = @($x, 300) })
  }
  "schedule" {
    Assert-NodeType "n8n-nodes-base.scheduleTrigger"
    Add-Node ([ordered]@{ parameters = [ordered]@{ rule = [ordered]@{ interval = @([ordered]@{ field = "minutes"; minutesInterval = 30 }) } }; id = (New-Id); name = $triggerName; type = "n8n-nodes-base.scheduleTrigger"; typeVersion = 1.2; position = @($x, 300); notes = "Schedule from spec: $($specObj.trigger.schedule) — adjust interval in UI if needed" })
  }
  "webhook" {
    Assert-NodeType "n8n-nodes-base.webhook"
    Add-Node ([ordered]@{ parameters = [ordered]@{ httpMethod = "GET"; path = $specObj.trigger.path; responseMode = "responseNode"; options = [ordered]@{} }; id = (New-Id); name = $triggerName; type = "n8n-nodes-base.webhook"; typeVersion = 2; position = @($x, 300) })
  }
  "rss" {
    Assert-NodeType "n8n-nodes-base.rssFeedRead"
    Add-Node ([ordered]@{ parameters = [ordered]@{ url = $specObj.trigger.feedUrl }; id = (New-Id); name = $triggerName; type = "n8n-nodes-base.rssFeedRead"; typeVersion = 1.2; position = @($x, 300) })
  }
}
$x += 220
$prev = $triggerName

# ---- Processing steps -> Code nodes (try/catch + logging + onError) ----
Assert-NodeType "n8n-nodes-base.code"
$stepIdx = 0
foreach ($p in $specObj.processing) {
  $stepIdx++
  $stepName = "Step $stepIdx"
  $codeLines = @(
    '// SPEC step: ' + $p.action
    '// Scaffold: passes items through with logging and error capture.'
    'try {'
    '  const items = [];'
    '  for (const item of $input.all()) {'
    '    console.log("[scaffold] keys=" + Object.keys(item.json).join(","));'
    '    items.push({ json: { ...item.json } });'
    '  }'
    '  return items;'
    '} catch (err) {'
    '  console.log("[scaffold] ERROR: " + err.message);'
    '  return [{ json: { success: false, error: err.message } }];'
    '}'
  )
  $code = $codeLines -join "`n"
  Add-Node ([ordered]@{ parameters = [ordered]@{ jsCode = $code }; id = (New-Id); name = $stepName; type = "n8n-nodes-base.code"; typeVersion = 2; position = @($x, 300); settings = [ordered]@{ onError = "continueRegularOutput" } })
  Link $prev $stepName; $prev = $stepName; $x += 220
}

# ---- Conditions -> IF nodes (true continues, false -> Skipped NoOp) ----
Assert-NodeType "n8n-nodes-base.if"
Assert-NodeType "n8n-nodes-base.noOp"
foreach ($c in $specObj.conditions) {
  $ifName = "Check - " + ($c.Substring(0, [Math]::Min(40, $c.Length)))
  $ifParams = [ordered]@{
    conditions = [ordered]@{
      options = [ordered]@{ caseSensitive = $true; leftValue = ""; typeValidation = "loose" }
      conditions = @([ordered]@{ id = "cond1"; leftValue = '={{ $json.success }}'; rightValue = $true; operator = [ordered]@{ type = "boolean"; operation = "true" } })
      combinator = "and"
    }
    options = [ordered]@{}
  }
  Add-Node ([ordered]@{ parameters = $ifParams; id = (New-Id); name = $ifName; type = "n8n-nodes-base.if"; typeVersion = 2.2; position = @($x, 300); notes = "SPEC condition: $c — refine expression as needed" })
  Link $prev $ifName
  $skipName = "$ifName - Skipped"
  Add-Node ([ordered]@{ parameters = [ordered]@{}; id = (New-Id); name = $skipName; type = "n8n-nodes-base.noOp"; typeVersion = 1; position = @($x, 480) })
  Link $ifName $skipName 1
  $prev = $ifName; $x += 220
}

# ---- Output shaper ----
Assert-NodeType "n8n-nodes-base.set"
$exampleProps = @()
if ($specObj.outputs.example) { $exampleProps = @($specObj.outputs.example.PSObject.Properties | ForEach-Object { $_.Name }) }
$assignments = @()
foreach ($k in $exampleProps) { $assignments += [ordered]@{ id = "g$([guid]::NewGuid().ToString('N').Substring(0,6))"; name = $k; value = "={{ `$json.$k }}"; type = "string" } }
if ($assignments.Count -eq 0) { $assignments += [ordered]@{ id = "gpass"; name = "result"; value = "={{ `$json }}"; type = "object" } }
Add-Node ([ordered]@{ parameters = [ordered]@{ assignments = [ordered]@{ assignments = $assignments }; options = [ordered]@{} }; id = (New-Id); name = "Shape Output"; type = "n8n-nodes-base.set"; typeVersion = 3.4; position = @($x, 300) })
Link $prev "Shape Output"

# ---- SPEC note ----
Assert-NodeType "n8n-nodes-base.stickyNote"
Add-Node ([ordered]@{ parameters = [ordered]@{ content = "## $($specObj.slug) $($specObj.version)`n$($specObj.goal)"; height = 140; width = 360 }; id = (New-Id); name = "SPEC Note"; type = "n8n-nodes-base.stickyNote"; typeVersion = 1; position = @(240, 80) })

$wf = [ordered]@{
  name = "$($specObj.slug) $($specObj.version)"
  id = "$($specObj.slug)-$($specObj.version)"
  active = $false
  nodes = $nodes
  connections = $conns
  settings = [ordered]@{ executionOrder = "v1"; timezone = "Africa/Cairo"; saveDataErrorExecution = "all"; saveDataSuccessExecution = "all" }
}

# ---- Gates: connections reference existing nodes / expressions balanced ----
$names = @($nodes | ForEach-Object { $_.name })
foreach ($from in $conns.Keys) {
  if ($names -notcontains $from) { throw "Connection from unknown node: $from" }
  foreach ($branch in $conns[$from]["main"]) {
    foreach ($t in $branch) { if ($names -notcontains $t.node) { throw "Connection to unknown node: $($t.node)" } }
  }
}
$raw = ($wf | ConvertTo-Json -Depth 20)
$open = ([regex]::Matches($raw, '\{\{')).Count
$close = ([regex]::Matches($raw, '\}\}')).Count
if ($open -ne $close) { throw "Unbalanced expressions: {{$ count=$open, }} count=$close" }

# n8n CLI لا يقبل BOM — كتابة UTF-8 بدون BOM
[System.IO.File]::WriteAllText($dest, $raw, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Generated: $dest ($($nodes.Count) nodes)"
& powershell -ExecutionPolicy Bypass -File (Join-Path $scriptsDir "Validate-Workflow.ps1") -Path $dest
if ($LASTEXITCODE -ne 0) { throw "Generated workflow failed validation." }
Write-Host "GENERATION OK — next: OpenCode refines TODO nodes, then Import-Workflow.ps1"
