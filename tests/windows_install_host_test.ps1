# Extract only pure selection/install functions; never run the real bootstrap.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$parseErrors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'windows-bootstrap.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($name in @('Resolve-PluginHost', 'Install-CodexClient')) {
    $fn = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    if (-not $fn) { throw "Missing $name" }
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Resolve-ExternalCommand {
    param($Names)
    if ($Names[0] -like 'npm*') { return 'Test-Npm' }
    if ($Names[0] -like 'claude*' -and $script:clients -contains 'claude') { return 'test-claude' }
    if ($Names[0] -like 'codex*' -and $script:clients -contains 'codex') { return 'test-codex' }
    return $null
}
function Read-Host { throw 'Unexpected interactive prompt' }
function Write-Info { param($msg) }
function Test-Npm {
    $script:npmArgs = $args -join ' '
    $global:LASTEXITCODE = $script:npmExit
}
foreach ($selected in @('claude', 'codex', 'both')) {
    $script:clients = if ($selected -eq 'both') { @('claude', 'codex') } else { @($selected) }
    if ((Resolve-PluginHost -Requested 'auto') -ne $selected) { throw "Incorrect auto detection: $selected" }
}
if ((Resolve-PluginHost -Requested 'codex') -ne 'codex') { throw 'Explicit host ignored' }
$rejected = $false
try { Resolve-PluginHost -Requested 'unknown' } catch { $rejected = $true }
if (-not $rejected) { throw 'Invalid host accepted' }
$script:npmExit = 0
Install-CodexClient
if ($script:npmArgs -ne 'install -g @openai/codex --loglevel http') { throw "Incorrect package: $script:npmArgs" }
$script:npmExit = 1
$rejected = $false
try { Install-CodexClient } catch { $rejected = $true }
if (-not $rejected) { throw 'Failed Codex installation reported as success' }
# Verify the Claude installer sits inside a selected-host condition.
$npmInstall = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.Extent.Text -like '*install -g @anthropic-ai/claude-code --loglevel*' }, $true)
$guard = $npmInstall.Parent
while ($guard -and -not ($guard -is [System.Management.Automation.Language.IfStatementAst] -and $guard.Clauses[0].Item1.Extent.Text -eq '$PluginHost -ne ''codex''')) { $guard = $guard.Parent }
if (-not $guard) { throw 'Claude npm install is not guarded by host selection' }
$packageList = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$packages' }, $true)
$packageFilter = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -eq '$PluginHost -eq ''codex''' -and $node.Extent.Text -like '*$packages*' }, $true)
foreach ($selected in @('claude', 'codex', 'both')) {
    $PluginHost = $selected
    . ([scriptblock]::Create($packageList.Extent.Text))
    . ([scriptblock]::Create($packageFilter.Extent.Text))
    $ids = @($packages | ForEach-Object { $_.Ids[0] })
    if ($selected -eq 'codex' -and ($ids -join ',') -ne 'Git.Git,OpenJS.NodeJS.LTS') { throw 'Codex pulled in optional toolkits' }
    if ($selected -ne 'codex' -and $ids -notcontains 'Python.Python.3.12') { throw 'Claude prerequisites changed' }
}
Write-Output 'ok - Windows parser, host detection, packages, failure handling, and Claude guard'
