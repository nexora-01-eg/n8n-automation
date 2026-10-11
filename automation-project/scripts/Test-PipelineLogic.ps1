# Test-PipelineLogic.ps1 — تنفيذ منطق Code node فعليًا داخل حاوية n8n (harness)
# يستخرج jsCode الدقيق من ملف الـ Workflow ويشغله بـ node مع $input/console/require shims.
# Usage: powershell -ExecutionPolicy Bypass -File Test-PipelineLogic.ps1 -Workflow "..\workflows\ai-news-pipeline-v001.json" -Node "Dedupe by Fingerprint" -Fixture "tenArticles"
param([Parameter(Mandatory = $true)][string]$Workflow, [Parameter(Mandatory = $true)][string]$Node, [Parameter(Mandatory = $true)][string]$Fixture)
$ErrorActionPreference = "Stop"

$projectDir = Split-Path -Parent $PSScriptRoot
$n8nDir = Split-Path -Parent $projectDir
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;" + $env:PATH

$wf = Get-Content -LiteralPath $Workflow -Encoding utf8 -Raw | ConvertFrom-Json
$found = @($wf.nodes | Where-Object { $_.name -eq $Node })
if ($found.Count -eq 0) { throw "Node not found: $Node" }
$jsCode = $found[0].parameters.jsCode
if ([string]::IsNullOrWhiteSpace($jsCode)) { throw "Node has no jsCode: $Node" }

$fixtures = Get-Content -LiteralPath (Join-Path (Join-Path $projectDir "tests") "ai-news-fixtures.json") -Encoding utf8 -Raw | ConvertFrom-Json
$setName = $Fixture
$items = @($fixtures.$setName)
if ($null -eq $fixtures.$setName) { throw "Fixture not found: $Fixture" }

$runner = @'
const fs = require("fs");
const items = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const code = fs.readFileSync(process.argv[3], "utf8");
const logs = [];
const shimConsole = { log: function () { logs.push(Array.prototype.join.call(arguments, " ")); } };
const shimInput = { all: function () { return items.map(function (j) { return { json: j }; }); }, first: function () { return items.length ? { json: items[0] } : {}; } };
const shimStatic = {};
const shimGetStatic = function () { return shimStatic; };
let out;
try {
  out = new Function("$input", "console", "require", "$getWorkflowStaticData", code)(shimInput, shimConsole, require, shimGetStatic);
} catch (e) {
  process.stdout.write(JSON.stringify({ __harnessError: String((e && e.message) || e) }));
  process.exit(2);
}
process.stdout.write(JSON.stringify({ items: out.map(function (o) { return o.json; }), logs: logs }));
'@

$stage = Join-Path $n8nDir "backups\stage"
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$ts = Get-Date -Format "HHmmss"
$itemsFile = Join-Path $stage "harness-items-$ts.json"
$codeFile = Join-Path $stage "harness-code-$ts.js"
$runnerFile = Join-Path $stage "harness-run-$ts.js"
$noBom = New-Object System.Text.UTF8Encoding $false
if ($items.Count -eq 0) { $itemsJson = "[]" } else { $itemsJson = ($items | ConvertTo-Json -Depth 12); if ($itemsJson.TrimStart()[0] -ne '[') { $itemsJson = "[$itemsJson]" } }
[System.IO.File]::WriteAllText($itemsFile, $itemsJson, $noBom)
[System.IO.File]::WriteAllText($codeFile, $jsCode, $noBom)
[System.IO.File]::WriteAllText($runnerFile, $runner, $noBom)

$prev = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try { $raw = & docker exec n8n node "/backups/stage/harness-run-$ts.js" "/backups/stage/harness-items-$ts.json" "/backups/stage/harness-code-$ts.js" 2>$null } finally { $ErrorActionPreference = $prev }
Remove-Item $itemsFile, $codeFile, $runnerFile -Force -ErrorAction SilentlyContinue
if ($LASTEXITCODE -ne 0) { throw "Harness execution failed: $raw" }
$result = ($raw | Out-String) | ConvertFrom-Json
if ($result.__harnessError) { throw "Node code threw: $($result.__harnessError)" }
Write-Host "HARNESS OK: node=$Node fixture=$Fixture in=$($items.Count) out=$($result.items.Count)"
$result.items | ConvertTo-Json -Depth 10 -Compress | Write-Host
return $result
