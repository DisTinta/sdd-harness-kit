#!/usr/bin/env node
// Lanza un hook .sh con un bash que no sea el de WSL en Windows.
// Claude Code con `"command": "bash"` suele resolver C:\Windows\System32\bash.exe (WSL).
// Este proceso es Node de Windows; aquí se elige Git Bash si existe.
'use strict'

const { spawnSync } = require('child_process')
const fs = require('fs')

const script = process.argv[2]
if (!script) {
  process.stderr.write('invoke.cjs: falta el script del hook\n')
  process.exit(1)
}

function exists(p) {
  try {
    return Boolean(p) && fs.existsSync(p)
  } catch {
    return false
  }
}

function gitBashWin() {
  const candidates = [
    process.env.CLAUDE_CODE_GIT_BASH_PATH,
    process.env.GIT_BASH_PATH,
    'C:\\Program Files\\Git\\bin\\bash.exe',
    'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
  ]
  return candidates.find(exists)
}

const bash = process.platform === 'win32' ? gitBashWin() || 'bash' : 'bash'
const result = spawnSync(bash, [script], {
  stdio: 'inherit',
  cwd: process.cwd(),
  env: process.env,
  windowsHide: true,
})

if (result.error) {
  process.stderr.write(`invoke.cjs: no se pudo ejecutar ${bash}: ${result.error.message}\n`)
  process.exit(1)
}

process.exit(result.status === null ? 1 : result.status)
