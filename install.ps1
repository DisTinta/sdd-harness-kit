<#
.SYNOPSIS
    Instala el SDD Harness Kit en un repositorio.

.DESCRIPTION
    Copia la fuente canónica (ai-specs), los hooks, la doctrina de docs/ y los standards
    del stack; enlaza .claude y .cursor a ai-specs; y genera docs/project-context.md.
    Es idempotente: al reejecutarlo conserva lo que ya existe salvo que uses -Force.

.PARAMETER Dest
    Repositorio destino. Por defecto, el directorio actual.

.PARAMETER Stack
    Adaptador a usar: adonisjs, laravel, fastify o _template. Si se omite, se detecta.
    La lista real es la de adapters\*.env; si pasas uno que no existe, el script
    la muestra y aborta.

.PARAMETER DryRun
    Muestra lo que haría sin escribir nada.

.PARAMETER Force
    Sobrescribe los ficheros que ya existan.

.PARAMETER NoFrontend
    No copia standards de frontend; usa la plantilla vacía y omite Playwright MCP y frontend.yml.

.PARAMETER Frontend
    UI frontend: auto (detecta Livewire vs React), react o livewire. Ignorado si -NoFrontend.

.EXAMPLE
    .\install.ps1 -Dest C:\proyectos\mi-api
.EXAMPLE
    .\install.ps1 -Stack laravel -DryRun
.EXAMPLE
    .\install.ps1 -Dest C:\proyectos\mi-api -NoFrontend
.EXAMPLE
    .\install.ps1 -Stack laravel -Frontend livewire
#>
[CmdletBinding()]
param(
    [string]$Dest = (Get-Location).Path,
    [string]$Stack = "",
    [ValidateSet('auto', 'react', 'livewire')]
    [string]$Frontend = 'auto',
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoFrontend
)

$ErrorActionPreference = 'Stop'
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Head($t) { Write-Host ""; Write-Host $t -ForegroundColor Cyan }
function Write-Ok($t)   { Write-Host "  + $t" -ForegroundColor Green }
function Write-Skip($t) { Write-Host "  . $t" -ForegroundColor DarkGray }
function Write-Warn($t) { Write-Host "  ! $t" -ForegroundColor Yellow }

if (-not (Test-Path -LiteralPath $Dest -PathType Container)) {
    throw "El destino no existe: $Dest"
}
$Dest = (Resolve-Path -LiteralPath $Dest).Path
if ($Dest -eq $KitDir) { throw "No instales el kit sobre si mismo. Usa -Dest." }

# ── Deteccion de stack ───────────────────────────────────────────────────────
if (-not $Stack) {
    $pkg = Join-Path $Dest 'package.json'
    if ((Test-Path $pkg) -and (Select-String -Path $pkg -Pattern '"@adonisjs/core"' -Quiet)) {
        $Stack = 'adonisjs'
    } elseif ((Test-Path (Join-Path $Dest 'artisan')) -and (Test-Path (Join-Path $Dest 'composer.json'))) {
        $Stack = 'laravel'
    } elseif (
        ((Test-Path $pkg) -and (Select-String -Path $pkg -Pattern '"fastify"' -Quiet)) -or
        ((Test-Path (Join-Path $Dest 'packages')) -and
         (Get-ChildItem -LiteralPath (Join-Path $Dest 'packages') -Filter 'package.json' -Recurse -Depth 1 -ErrorAction SilentlyContinue |
          Select-String -Pattern '"fastify"' -Quiet))
    ) {
        $Stack = 'fastify'
    } else {
        $Stack = '_template'
    }
}
$adapterEnv = Join-Path $KitDir "adapters\$Stack.env"
if (-not (Test-Path $adapterEnv)) {
    $avail = (Get-ChildItem (Join-Path $KitDir 'adapters') -Filter '*.env' | ForEach-Object { $_.BaseName }) -join ', '
    throw "No existe el adaptador '$Stack'. Disponibles: $avail"
}

function Resolve-FrontendUi {
    param([string]$Mode, [string]$DestPath)
    if ($Mode -ne 'auto') { return $Mode }
    $hasLivewire = $false
    $hasReact = $false
    $composer = Join-Path $DestPath 'composer.json'
    $composerLock = Join-Path $DestPath 'composer.lock'
    $pkg = Join-Path $DestPath 'package.json'
    if ((Test-Path $composer) -and (Select-String -Path $composer -Pattern 'livewire/livewire' -Quiet)) {
        $hasLivewire = $true
    }
    if ((Test-Path $composerLock) -and (Select-String -Path $composerLock -Pattern 'livewire/livewire' -Quiet)) {
        $hasLivewire = $true
    }
    if ((Test-Path $pkg) -and (Select-String -Path $pkg -Pattern '"react"|"@inertiajs/react"' -Quiet)) {
        $hasReact = $true
    }
    if ($hasLivewire -and -not $hasReact) { return 'livewire' }
    return 'react'
}

$FrontendUi = $null
if (-not $NoFrontend) {
    $FrontendUi = Resolve-FrontendUi -Mode $Frontend -DestPath $Dest
}

Write-Head "SDD Harness Kit"
$verFile = Join-Path $KitDir 'VERSION'
$ver = if (Test-Path $verFile) { (Get-Content $verFile -Raw).Trim() } else { 'dev' }
Write-Host "  Version: $ver"
Write-Host "  Origen : $KitDir"
Write-Host "  Destino: $Dest"
Write-Host "  Stack  : $Stack"
if ($NoFrontend) { Write-Host "  Frontend: plantilla vacia (-NoFrontend)" }
else { Write-Host "  Frontend UI: $FrontendUi (-Frontend $Frontend)" }
if ($DryRun) { Write-Host "  Modo   : simulacion, no se escribe nada" }

function Test-OsJunkName([string]$Name) {
    $n = $Name.ToLowerInvariant()
    return $n -eq 'desktop.ini' -or $n -eq 'thumbs.db' -or $n -eq '.ds_store'
}

function Copy-KitFile($Src, $Rel) {
    if (Test-OsJunkName ([System.IO.Path]::GetFileName($Src))) { return }
    $dst = Join-Path $Dest $Rel
    if ((Test-Path -LiteralPath $dst) -and -not $Force) {
        $same = $false
        try {
            $same = (Get-FileHash -LiteralPath $Src).Hash -eq (Get-FileHash -LiteralPath $dst).Hash
        } catch { $same = $false }
        if ($same) { Write-Skip "$Rel (identico)" }
        else { Write-Warn "$Rel ya existe y difiere - conservado (usa -Force para sobrescribir)" }
        return
    }
    if ($DryRun) { Write-Ok "$Rel (simulado)"; return }
    $dir = Split-Path -Parent $dst
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Copy-Item -LiteralPath $Src -Destination $dst -Force
    Write-Ok $Rel
}

Write-Head "1. Fuente canonica: ai-specs/ y configuracion de agente"
$coreRoot = Join-Path $KitDir 'core'
Get-ChildItem -Path $coreRoot -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($coreRoot.Length + 1)
    if ($rel -like 'docs\*') { return }   # la doctrina se copia aparte
    Copy-KitFile $_.FullName $rel
}

Write-Head "2. Doctrina en docs/"
foreach ($d in @('base-standards','documentation-standards','openspec-tasks-mandatory-steps')) {
    Copy-KitFile (Join-Path $KitDir "core\docs\$d.md") "docs\$d.md"
}

Write-Head "2b. MCP del proyecto (Context7 / Playwright)"
$mcpTpl = Join-Path $KitDir 'core\ai-specs\templates\mcp.json'
if ($NoFrontend) { $mcpTpl = Join-Path $KitDir 'core\ai-specs\templates\mcp.context7-only.json' }
Copy-KitFile $mcpTpl '.mcp.json'
Copy-KitFile $mcpTpl '.cursor\mcp.json'

Write-Head "3. Standards del stack"
Copy-KitFile $adapterEnv ".claude\sdd-harness.env"
$be = Join-Path $KitDir "adapters\$Stack.backend-standards.md"
if (-not (Test-Path $be)) { $be = Join-Path $KitDir 'adapters\_template.backend-standards.md' }
Copy-KitFile $be "docs\backend-standards.md"
if ($NoFrontend) {
    $fe = Join-Path $KitDir 'adapters\_template.frontend-standards.md'
    if (-not (Test-Path $fe)) { $fe = Join-Path $KitDir 'adapters\react.frontend-standards.md' }
    Copy-KitFile $fe "docs\frontend-standards.md"
} elseif ($FrontendUi -eq 'livewire') {
    Copy-KitFile (Join-Path $KitDir 'adapters\livewire.frontend-standards.md') "docs\frontend-standards.md"
} else {
    Copy-KitFile (Join-Path $KitDir 'adapters\react.frontend-standards.md') "docs\frontend-standards.md"
}
$rules = Join-Path $KitDir "adapters\$Stack.rules.mdc"
if (Test-Path $rules) { Copy-KitFile $rules ".cursor\rules\30-stack.mdc" }
$ci = Join-Path $KitDir "adapters\$Stack.ci.yml"
if (Test-Path $ci) { Copy-KitFile $ci ".github\workflows\ci.yml" }
if (-not $NoFrontend) {
    if ($FrontendUi -eq 'livewire') {
        $feCi = Join-Path $KitDir 'adapters\livewire.ci.yml'
        if (Test-Path $feCi) { Copy-KitFile $feCi '.github\workflows\frontend.yml' }
        $a11ySrc = Join-Path $KitDir 'adapters\livewire.a11y.smoke.example.mjs'
        $a11yRel = 'tests\a11y\smoke.example.mjs'
    } else {
        $feCi = Join-Path $KitDir 'adapters\react.ci.yml'
        if (Test-Path $feCi) { Copy-KitFile $feCi '.github\workflows\frontend.yml' }
        $a11ySrc = Join-Path $KitDir 'adapters\react.a11y.smoke.example.tsx'
        $a11yRel = 'tests\a11y\smoke.example.tsx'
    }
    if (Test-Path -LiteralPath $a11ySrc) {
        $a11yDest = Join-Path $Dest $a11yRel
        if (Test-Path -LiteralPath $a11yDest) {
            Write-Skip "$($a11yRel.Replace('\','/')) ya existe - conservado"
        } else {
            Copy-KitFile $a11ySrc $a11yRel
        }
    }
}
$infection = Join-Path $KitDir "adapters\$Stack.infection.json"
if (Test-Path $infection) {
    $infectionDest = Join-Path $Dest 'infection.json'
    if (Test-Path -LiteralPath $infectionDest) {
        Write-Skip "infection.json ya existe - conservado"
    } else {
        Copy-KitFile $infection 'infection.json'
    }
}
$depcruise = Join-Path $KitDir "adapters\$Stack.dependency-cruiser.js"
if (Test-Path $depcruise) {
    $depcruiseDest = Join-Path $Dest '.dependency-cruiser.js'
    if (Test-Path -LiteralPath $depcruiseDest) {
        Write-Skip ".dependency-cruiser.js ya existe - conservado"
    } else {
        Copy-KitFile $depcruise '.dependency-cruiser.js'
    }
}

Write-Head "4. Plantillas del proyecto"
Copy-KitFile (Join-Path $KitDir 'core\ai-specs\templates\pull_request_template.md') ".github\pull_request_template.md"
Copy-KitFile (Join-Path $KitDir 'core\ai-specs\templates\adr.md.tpl') "docs\adr\_template.md"

Write-Head "5. Contexto del proyecto"
$ctxPath = Join-Path $Dest 'docs\project-context.md'
if (Test-Path -LiteralPath $ctxPath) {
    Write-Skip "docs/project-context.md ya existe - conservado (es tuyo, el kit no lo pisa)"
} elseif ($DryRun) {
    Write-Ok "docs/project-context.md (simulado, con los comandos del adaptador)"
} else {
    $tpl = Get-Content -LiteralPath (Join-Path $KitDir 'core\ai-specs\templates\project-context.md.tpl') -Raw
    $cfg = @{}
    foreach ($line in Get-Content -LiteralPath $adapterEnv) {
        if ($line -match '^\s*([A-Z_]+)="(.*)"\s*$') { $cfg[$Matches[1]] = $Matches[2] }
    }
    $tpl = $tpl.Replace('{{PROJECT_NAME}}', (Split-Path -Leaf $Dest))
    foreach ($key in @('CMD_DEV','CMD_TEST','CMD_TEST_FILTER','CMD_LINT','CMD_STATIC','CMD_MIGRATE')) {
        $value = if ($cfg[$key]) { $cfg[$key] } else { 'not configured' }
        $tpl = $tpl.Replace("{{$key}}", $value)
    }
    $dir = Split-Path -Parent $ctxPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $ctxPath -Value $tpl -Encoding UTF8
    Write-Ok "docs/project-context.md creado, con los comandos del adaptador ya puestos"
    Write-Warn "Tiene marcadores {{...}} pendientes: completalos antes de la primera sesion"
}

Write-Head "6. Memoria multi-agente"
foreach ($name in @('CLAUDE.md','AGENTS.md')) {
    $mp = Join-Path $Dest $name
    if (Test-Path -LiteralPath $mp) { Write-Skip "$name ya existe"; continue }
    if ($DryRun) { Write-Ok "$name -> docs/base-standards.md (simulado)"; continue }
    try {
        New-Item -ItemType SymbolicLink -Path $mp -Target 'docs/base-standards.md' -ErrorAction Stop | Out-Null
        Write-Ok "$name -> docs/base-standards.md (symlink)"
    } catch {
        Set-Content -LiteralPath $mp -Value '@docs/base-standards.md' -Encoding UTF8
        Write-Ok "$name creado con import (el symlink no estaba disponible)"
    }
}

Write-Head "7. Referencias de skills y agents"
if ($DryRun) {
    Write-Ok ".claude y .cursor -> ai-specs (simulado)"
} else {
    Push-Location $Dest
    $env:CLAUDE_PROJECT_DIR = $Dest
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest '.claude\sync-artifacts.ps1')
    Pop-Location
}

Write-Head "7b. Doctor del harness (copia local en el proyecto)"
Copy-KitFile (Join-Path $KitDir 'doctor.ps1') ".claude\doctor.ps1"
Copy-KitFile (Join-Path $KitDir 'doctor.sh') ".claude\doctor.sh"

Write-Head "8. Comprobaciones"
if (Get-Command jq -ErrorAction SilentlyContinue) { Write-Ok "jq disponible" }
else { Write-Warn "jq NO esta instalado: los hooks se desactivaran solos hasta que lo instales (winget install jqlang.jq)" }
if (Get-Command git -ErrorAction SilentlyContinue) { Write-Ok "git disponible" } else { Write-Warn "git no disponible" }
if (Test-Path (Join-Path $Dest '.git')) { Write-Ok "el destino es un repositorio git" } else { Write-Warn "el destino no es un repositorio git" }
if (Get-Command bash -ErrorAction SilentlyContinue) { Write-Ok "bash disponible (los hooks lo necesitan; en Windows lo trae Git for Windows)" }
else { Write-Warn "bash NO disponible: los hooks no se ejecutaran. Instala Git for Windows." }

$gitignore = Join-Path $Dest '.gitignore'
if ((Test-Path $gitignore) -and -not (Select-String -Path $gitignore -Pattern 'settings\.local\.json' -Quiet)) {
    if (-not $DryRun) {
        Add-Content -LiteralPath $gitignore -Value "`n# sdd-harness-kit`n.claude/settings.local.json`n.worktrees/" -Encoding utf8
    }
    Write-Ok ".gitignore - aniadidas entradas del kit (settings.local + .worktrees/)"
}

if (-not $DryRun) {
    Write-Head "9. Doctor (salud del harness)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $KitDir 'doctor.ps1') -Dest $Dest
}

Write-Head "Siguientes pasos"
@"
  1. Completa docs/project-context.md (<200 lineas). Es el paso de mayor ROI del kit.
  2. Revisa .claude/sdd-harness.env (comandos reales + BRANCH_PREFIX). Los hooks los ejecutan tal cual.
  3. Revisa docs/backend-standards.md si tu arquitectura no es la del adaptador.
  4. Si hay frontend: cablea tests/a11y (deps + rename + script test:a11y). Ver docs/frontend-standards.md.
  5. Activa los MCP del proyecto en Claude Code / Cursor (Context7; Playwright si hay frontend).
     Si Cursor pide permiso la primera vez, aceptalo. Opcional: CONTEXT7_API_KEY en el entorno.
  6. Inicializa OpenSpec:  openspec init
     Luego cablea openspec/config.yaml con ai-specs/templates/openspec/config.yaml.tpl
  7. Revisa .claude/hooks/ antes de confiar en ellos: ejecutan codigo con tus permisos.
  8. Anade el secreto ANTHROPIC_API_KEY al repo si usas los workflows de review.
  9. Abre una sesion y escribe /enrich-us (o /kit-health) para probar que las skills cargan.
  10. Vuelve a pasar el doctor:  powershell -File $Dest\.claude\doctor.ps1 -Dest $Dest

  NO ejecutes /init: CLAUDE.md y AGENTS.md apuntan a docs/base-standards.md y /init
  escribiria a traves de ellos. Para el contexto del proyecto usa el prompt P0.

  Edita siempre ai-specs/ y ejecuta '.claude\sync-artifacts.ps1' para propagar.

  Guia paso a paso: $KitDir\docs\es\GUIA-PASO-A-PASO.md
  Uso / Manual / Prompts: docs\es\USO.md · docs\es\MANUAL.md · docs\es\PROMPTS.md
"@ | Write-Host
