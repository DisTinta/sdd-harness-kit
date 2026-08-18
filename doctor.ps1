<#
.SYNOPSIS
    Comprueba que el harness SDD Harness Kit está sano en un proyecto ya instalado.

.EXAMPLE
    .\doctor.ps1 -Dest C:\proyectos\mi-api
    .\doctor.ps1
#>
[CmdletBinding()]
param(
    [string]$Dest = (Get-Location).Path
)

$ErrorActionPreference = 'Continue'
$Dest = (Resolve-Path -LiteralPath $Dest).Path
$fail = 0
$warn = 0

function Ok($t)   { Write-Host "  OK   $t" -ForegroundColor Green }
function Warn($t) { Write-Host "  WARN $t" -ForegroundColor Yellow; $script:warn++ }
function Fail($t) { Write-Host "  FAIL $t" -ForegroundColor Red; $script:fail++ }

Write-Host ""
Write-Host "SDD Harness Kit doctor — $Dest" -ForegroundColor Cyan
Write-Host ""

function Test-File($rel) {
    $p = Join-Path $Dest $rel
    if (Test-Path -LiteralPath $p) { Ok $rel } else { Fail "falta $rel" }
}

Test-File 'docs\base-standards.md'
Test-File 'docs\project-context.md'
$ctx = Join-Path $Dest 'docs\project-context.md'
if ((Test-Path $ctx) -and (Select-String -Path $ctx -Pattern '\{\{' -Quiet)) {
    Warn 'docs/project-context.md todavía tiene marcadores {{...}} sin completar'
}
Test-File '.claude\sdd-harness.env'

foreach ($f in @('CLAUDE.md','AGENTS.md')) {
    if (Test-Path (Join-Path $Dest $f)) { Ok "$f presente" }
    else { Warn "falta $f" }
}

if (Test-Path (Join-Path $Dest 'ai-specs\skills')) { Ok 'ai-specs/skills' } else { Fail 'falta ai-specs/skills' }
$skillN = @(Get-ChildItem (Join-Path $Dest 'ai-specs\skills') -Directory -ErrorAction SilentlyContinue).Count
Ok "skills canónicas: $skillN"

$hooks = @(
    'session-context','block-secrets','block-secret-reads','block-dangerous-bash',
    'docs-gate','protect-specs-and-tests','post-edit-quality','validate-tasks','verify-tests','lib'
)
foreach ($h in $hooks) {
    $hp = Join-Path $Dest ".claude\hooks\$h.sh"
    if (Test-Path $hp) { Ok "hook $h" } else { Fail "falta hook $h.sh" }
}
$invoke = Join-Path $Dest '.claude\hooks\invoke.cjs'
if (Test-Path $invoke) { Ok 'hook invoke.cjs' } else { Fail 'falta hook invoke.cjs' }

$settings = Join-Path $Dest '.claude\settings.json'
if (Test-Path $settings) {
    Ok 'settings.json'
    if (Select-String -Path $settings -Pattern 'block-secret-reads' -Quiet) { Ok 'settings registra block-secret-reads' }
    else { Warn 'settings.json no referencia block-secret-reads' }
    if (Select-String -Path $settings -Pattern 'invoke\.cjs' -Quiet) { Ok 'settings lanza hooks via invoke.cjs' }
    else { Warn 'settings.json no usa invoke.cjs (en Windows `bash` puede ser WSL)' }
} else { Fail 'falta .claude/settings.json' }

if (Get-Command jq -ErrorAction SilentlyContinue) { Ok 'jq instalado' }
else { Warn 'jq NO instalado — winget install jqlang.jq' }
if (Get-Command bash -ErrorAction SilentlyContinue) { Ok 'bash disponible' }
else { Fail 'bash no disponible — instala Git for Windows' }
if (Get-Command git -ErrorAction SilentlyContinue) { Ok 'git disponible' } else { Warn 'git no disponible' }
if (Get-Command openspec -ErrorAction SilentlyContinue) { Ok 'openspec CLI' }
else { Warn 'openspec no está en PATH' }

if (Test-Path (Join-Path $Dest 'openspec')) { Ok 'openspec/ presente' }
else { Warn 'openspec/ no inicializado — openspec init' }

$mcp = Join-Path $Dest '.mcp.json'
if (Test-Path $mcp) {
    Ok '.mcp.json (Claude Code)'
    if (Select-String -Path $mcp -Pattern '"context7"' -Quiet) { Ok 'MCP context7 en .mcp.json' }
    else { Warn '.mcp.json no declara context7' }
    if (Select-String -Path $mcp -Pattern '"playwright"' -Quiet) { Ok 'MCP playwright en .mcp.json' }
    else { Warn 'MCP playwright no está en .mcp.json (normal con -NoFrontend)' }
} else {
    Warn 'falta .mcp.json — el instalador del kit lo copia; sin él Context7/Playwright no cargan en Claude Code'
}
$cursorMcp = Join-Path $Dest '.cursor\mcp.json'
if (Test-Path $cursorMcp) {
    Ok '.cursor/mcp.json (Cursor)'
    if (Select-String -Path $cursorMcp -Pattern '"context7"' -Quiet) { Ok 'MCP context7 en .cursor/mcp.json' }
    else { Warn '.cursor/mcp.json no declara context7' }
} else {
    Warn 'falta .cursor/mcp.json — el instalador del kit lo copia; sin él Context7/Playwright no cargan en Cursor'
}

$envFile = Join-Path $Dest '.claude\sdd-harness.env'
if (Test-Path $envFile) {
    if (Select-String -Path $envFile -Pattern '^BRANCH_PREFIX=' -Quiet) { Ok 'BRANCH_PREFIX definido' }
    else { Warn 'BRANCH_PREFIX no está en sdd-harness.env' }
    $envRaw = Get-Content -LiteralPath $envFile -Raw
    if ($envRaw -match '\$\(' -or $envRaw -match '`') {
        Fail 'sdd-harness.env contiene command substitution — limpia el fichero'
    }
}

Write-Host ""
Write-Host "Resumen: $fail fallos, $warn avisos"
if ($fail -gt 0) { exit 1 }
exit 0
