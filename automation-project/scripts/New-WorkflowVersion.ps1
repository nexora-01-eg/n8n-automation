# New-WorkflowVersion.ps1 — ترقيم إصدارات Workflow (لا حذف، لا استبدال)
# Usage: powershell -ExecutionPolicy Bypass -File New-WorkflowVersion.ps1 -Slug "news-ai"
param([Parameter(Mandatory = $true)][string]$Slug)
$ErrorActionPreference = "Stop"

$wfDir = Join-Path (Split-Path -Parent $PSScriptRoot) "workflows"
$existing = Get-ChildItem -LiteralPath $wfDir -Filter "$Slug-v*.json" | Sort-Object Name
if ($existing.Count -eq 0) {
  $next = "v001"
} else {
  $max = ($existing | ForEach-Object {
    if ($_.BaseName -match '-v(\d{3})$') { [int]$Matches[1] } else { 0 }
  } | Measure-Object -Maximum).Maximum
  $next = "v{0:D3}" -f ($max + 1)
}
$dest = Join-Path $wfDir "$Slug-$next.json"
if ($existing.Count -eq 0) {
  Write-Host "No versions yet. Create first version at: $dest"
} else {
  Copy-Item $existing[-1].FullName -Destination $dest
  Write-Host "New version branched from $($existing[-1].Name): $dest"
}
Write-Host "NEXT_VERSION=$next"
