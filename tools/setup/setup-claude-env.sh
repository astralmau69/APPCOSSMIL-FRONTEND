#!/usr/bin/env bash
# =============================================================================
# setup-claude-env.sh
# Replica en tu PC el entorno de Claude Code usado en el proyecto COSSMIL:
# marketplaces + plugins (superpowers, claude-mem, taskmaster, fullstack-dev,
# stitch), MCP ruflo, config global (settings.json + CLAUDE.md), la memoria
# y las skills del proyecto (.claude/skills).
#
# Uso:
#   bash tools/setup/setup-claude-env.sh            # instala todo
#   bash tools/setup/setup-claude-env.sh --dry-run  # solo muestra que haria
#
# Requisitos previos: Claude Code (`claude`) y Node.js/npm ya instalados.
# Linux/macOS (bash). Para Windows ver docs/setup/entorno-claude-code.md.
# NO contiene secretos. Hace backup de lo que sobrescribe.
# =============================================================================
set -euo pipefail

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

# Raiz del repo (este script vive en tools/setup/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CFG_DIR="$REPO_DIR/docs/setup/claude-config"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
run()  { if [[ $DRY -eq 1 ]]; then echo "  (dry) $*"; else eval "$*"; fi; }

require() { command -v "$1" >/dev/null 2>&1 || { warn "Falta '$1'. Instalalo primero."; return 1; }; }

log "Repo: $REPO_DIR"
log "Config fuente: $CFG_DIR"
log "Destino Claude: $CLAUDE_HOME"
[[ $DRY -eq 1 ]] && warn "MODO DRY-RUN: no se cambia nada."

# --- 0. Prerrequisitos -------------------------------------------------------
require claude || { warn "Instala Claude Code: https://claude.com/claude-code"; exit 1; }
require npm    || { warn "Instala Node.js/npm."; exit 1; }

# --- 1. Marketplaces ---------------------------------------------------------
log "Agregando marketplaces de plugins..."
MARKETPLACES=(
  "anthropics/claude-plugins-official"
  "jeffallan/claude-skills"
  "google-labs-code/stitch-skills"
  "obra/superpowers"
  "thedotmack/claude-mem"
  "eyaltoledano/claude-task-master"
)
for m in "${MARKETPLACES[@]}"; do
  log "  marketplace add $m"
  run "claude plugin marketplace add \"$m\" || true"
done

# --- 2. Plugins --------------------------------------------------------------
# name@marketplace-alias (los alias los define settings.json / el add anterior).
log "Instalando/activando plugins..."
PLUGINS=(
  "superpowers@superpowers-dev"
  "claude-mem@thedotmack"
  "taskmaster@taskmaster"
  "fullstack-dev-skills@fullstack-dev-skills"
  "stitch-build@google-labs-code-stitch-skills"
  "stitch-design@google-labs-code-stitch-skills"
  "stitch-utilities@google-labs-code-stitch-skills"
)
for p in "${PLUGINS[@]}"; do
  log "  plugin install $p"
  run "claude plugin install \"$p\" || true"
done

# --- 3. ruflo (CLI global + MCP a nivel user) --------------------------------
log "Instalando ruflo (meta-harness multi-agente) global..."
# El entorno original usa prefix ~/.npm-global. Respetamoslo si existe.
if [[ -d "$HOME/.npm-global" ]]; then
  run "npm install -g --prefix \"$HOME/.npm-global\" ruflo || true"
  RUFLO_BIN="$HOME/.npm-global/bin/ruflo"
else
  run "npm install -g ruflo || true"
  RUFLO_BIN="$(command -v ruflo || echo ruflo)"
fi
log "  ruflo bin: $RUFLO_BIN"
# `ruflo init` cablea el MCP a scope user y escribe ~/.claude/CLAUDE.md.
if [[ -x "$RUFLO_BIN" || $DRY -eq 1 ]]; then
  log "  ruflo init (registra MCP user + CLAUDE.md)"
  run "\"$RUFLO_BIN\" init || true"
else
  warn "  ruflo no quedo ejecutable; registra el MCP a mano (ver guia)."
fi
# Fallback explicito por si `ruflo init` no registro el MCP:
log "  registrando MCP ruflo (fallback idempotente)"
run "claude mcp add -s user ruflo \"$RUFLO_BIN\" mcp start 2>/dev/null || true"

# --- 4. Config global: settings.json + CLAUDE.md -----------------------------
mkdir -p "$CLAUDE_HOME"
if [[ -f "$CLAUDE_HOME/settings.json" ]]; then
  log "Backup settings.json -> settings.json.bak-$STAMP"
  run "cp \"$CLAUDE_HOME/settings.json\" \"$CLAUDE_HOME/settings.json.bak-$STAMP\""
  warn "Ya existe settings.json. Revisa/mezcla manualmente con:"
  warn "  $CFG_DIR/settings.json"
else
  log "Copiando settings.json"
  run "cp \"$CFG_DIR/settings.json\" \"$CLAUDE_HOME/settings.json\""
fi

# CLAUDE.md global: si ruflo init ya lo escribio, no lo pisamos.
if [[ ! -f "$CLAUDE_HOME/CLAUDE.md" ]]; then
  log "Copiando CLAUDE.md global"
  run "cp \"$CFG_DIR/CLAUDE.global.md\" \"$CLAUDE_HOME/CLAUDE.md\""
else
  log "CLAUDE.md global ya existe (probablemente de ruflo init); se conserva."
fi

# --- 5. Memoria del proyecto -------------------------------------------------
# Claude Code guarda la memoria en ~/.claude/projects/<ruta-codificada>/memory/
# donde <ruta-codificada> = ruta absoluta del proyecto con / _ . -> '-'.
ENCODED="$(printf '%s' "$REPO_DIR" | sed 's#[/_.]#-#g')"
MEM_DEST="$CLAUDE_HOME/projects/$ENCODED/memory"
log "Restaurando memoria del proyecto en:"
log "  $MEM_DEST"
warn "  (si Claude Code creo otro nombre de carpeta, copia los .md al 'memory' correcto)"
run "mkdir -p \"$MEM_DEST\""
run "cp -n \"$CFG_DIR/memory/\"*.md \"$MEM_DEST\"/ 2>/dev/null || true"

# --- 6. Skills del proyecto (.claude/skills, ignorado por git) ---------------
# flutter-*, gsap-*, frontend-design y skills de seguridad (pentest movil, JWT,
# OAuth...), instaladas en su dia con `npx skills` (ver skills-lock.json).
# Se versionan como copia en docs/setup/claude-config/project-skills/.
SKILLS_SRC="$CFG_DIR/project-skills"
SKILLS_DEST="$REPO_DIR/.claude/skills"
if [[ -d "$SKILLS_SRC" ]]; then
  log "Copiando skills del proyecto -> $SKILLS_DEST (no pisa las existentes)"
  run "mkdir -p \"$SKILLS_DEST\""
  run "cp -rn \"$SKILLS_SRC\"/. \"$SKILLS_DEST\"/"
fi

# --- 7. Lo que llega solo con la cuenta --------------------------------------
# El plugin "mis-skills-claude-code" y las skills de ~/.claude/skills/synced se
# sincronizan desde claude.ai: aparecen al iniciar sesion con la MISMA cuenta.
log "Nota: 'mis-skills-claude-code' llega solo al iniciar sesion con tu cuenta de claude.ai."

log "Listo. Abre Claude Code en el proyecto y verifica con: /plugin  /mcp  y  /skills"
[[ $DRY -eq 1 ]] && warn "Fue dry-run: no se cambio nada."
