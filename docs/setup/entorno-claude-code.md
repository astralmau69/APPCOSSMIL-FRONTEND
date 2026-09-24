# Replicar el entorno de Claude Code en tu PC

Esta guía deja tu PC **igual que trabajar aquí**: mismos plugins, skills, MCP,
memoria y configuración global. Todo lo necesario está versionado en
`docs/setup/claude-config/` y automatizado en `tools/setup/setup-claude-env.sh`.

> ⚠️ **Sin secretos.** Aquí NO se versiona ninguna credencial
> (`~/.claude/.credentials.json`, `history.jsonl`, sesiones). El login de Claude
> lo haces tú con `claude` (o `/login`). El MCP de ruflo no usa variables de
> entorno con secretos.

---

## 0. Prerrequisitos (instalar una vez)

- **Claude Code** — https://claude.com/claude-code (comando `claude`).
- **Node.js + npm** — https://nodejs.org (LTS). Necesario para ruflo y plugins.
- **Git**.
- (Para compilar la app COSSMIL, además: Flutter SDK, Android SDK, JDK 21 —
  ver la memoria "Entorno de build Android en Linux".)

Verifica:
```bash
claude --version
node -v && npm -v
```

---

## 1. Instalación automática (recomendado)

Desde la raíz del repo clonado:
```bash
bash tools/setup/setup-claude-env.sh --dry-run   # ver qué hará (no cambia nada)
bash tools/setup/setup-claude-env.sh             # instalar de verdad
```

El script:
1. Agrega los **marketplaces** de plugins.
2. Instala/activa los **plugins**.
3. Instala **ruflo** global y registra su **MCP** a nivel user (`ruflo init` +
   fallback `claude mcp add`).
4. Copia `settings.json` y `CLAUDE.md` global (con backup si ya existen).
5. Restaura la **memoria** del proyecto.

Luego abre Claude Code en el proyecto y comprueba:
```bash
claude            # dentro del repo
/plugin           # deben verse los plugins activos
/mcp              # debe verse 'ruflo' conectado
```

---

## 2. Qué se instala (inventario)

### Marketplaces (repos GitHub)
| Alias | Repo |
|---|---|
| claude-plugins-official | anthropics/claude-plugins-official |
| fullstack-dev-skills | jeffallan/claude-skills |
| google-labs-code-stitch-skills | google-labs-code/stitch-skills |
| superpowers-dev | obra/superpowers |
| thedotmack | thedotmack/claude-mem |
| taskmaster | eyaltoledano/claude-task-master |

### Plugins activos
- **superpowers** — skills de proceso (brainstorming, writing-plans, TDD,
  systematic-debugging, etc.). Es el que estructura cómo trabajamos.
- **claude-mem** — memoria/observaciones de sesiones (MCP `mcp-search`).
- **taskmaster** — orquestación de tareas (agentes task-*).
- **fullstack-dev-skills** — biblioteca grande de skills por stack (flutter,
  react, security, etc.).
- **stitch-build / stitch-design / stitch-utilities** — flujo de diseño Stitch.

### MCP
- **ruflo** (`ruflo mcp start`, stdio, scope user, **sin env/secretos**) —
  meta-harness multi-agente (memory_*, hooks_*, swarm_*, agent_*…).
- **claude-mem** — viene incluido por el plugin (no se configura aparte).
- **Claude Docs** — conector gestionado de claude.ai (no requiere instalación).

### Config global (`~/.claude/`)
- `settings.json` — modelo `claude-opus-4-8`, `effortLevel: high` (opus-5:
  xhigh), `tui: fullscreen`, `theme: dark`, marketplaces + plugins.
  - `skipDangerousModePermissionPrompt` queda **fuera** por defecto (riesgoso).
    Actívalo solo si lo entiendes.
- `CLAUDE.md` — nota de integración de ruflo (la escribe `ruflo init`).

### Memoria del proyecto
- 24 archivos `.md` (+ índice `MEMORY.md`) en `docs/setup/claude-config/memory/` → se restauran en
  `~/.claude/projects/<ruta-codificada>/memory/`.
- La `<ruta-codificada>` es la ruta absoluta del proyecto con `/`, `_` y `.`
  cambiados por `-`. Si Claude Code creó otro nombre, copia los `.md` a la
  carpeta `memory/` que él haya creado (abre una sesión primero y revisa
  `~/.claude/projects/`).

### Skills del proyecto (`.claude/skills/`)
- 31 skills instaladas con `npx skills` (fuentes en `skills-lock.json`):
  `flutter-*` (tests, animaciones, layout responsivo, arquitectura),
  `gsap-*`, `frontend-design` y skills de seguridad (pentest móvil, JWT, OAuth,
  CORS, almacenamiento inseguro...).
- `.claude/skills/` está en `.gitignore`, así que van como copia en
  `docs/setup/claude-config/project-skills/` y el script las copia a
  `.claude/skills/` del repo.

### Lo que llega solo con tu cuenta
- El plugin **`mis-skills-claude-code`** y las skills sincronizadas
  (`~/.claude/skills/synced`, artifact-design, dataviz, docs, pdf, etc.) vienen de
  claude.ai: aparecen al iniciar sesión con la **misma cuenta**. No se copian.

---

## 3. Instalación manual (si no usas el script)

```bash
# 1) Marketplaces
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add jeffallan/claude-skills
claude plugin marketplace add google-labs-code/stitch-skills
claude plugin marketplace add obra/superpowers
claude plugin marketplace add thedotmack/claude-mem
claude plugin marketplace add eyaltoledano/claude-task-master

# 2) Plugins
claude plugin install superpowers@superpowers-dev
claude plugin install claude-mem@thedotmack
claude plugin install taskmaster@taskmaster
claude plugin install fullstack-dev-skills@fullstack-dev-skills
claude plugin install stitch-build@google-labs-code-stitch-skills
claude plugin install stitch-design@google-labs-code-stitch-skills
claude plugin install stitch-utilities@google-labs-code-stitch-skills

# 3) ruflo + MCP (scope user)
npm install -g --prefix "$HOME/.npm-global" ruflo   # o: npm install -g ruflo
"$HOME/.npm-global/bin/ruflo" init                   # cablea MCP user + CLAUDE.md
# fallback si init no lo registró:
claude mcp add -s user ruflo "$HOME/.npm-global/bin/ruflo" mcp start

# 4) Config global
cp docs/setup/claude-config/settings.json  ~/.claude/settings.json
# (CLAUDE.md lo escribe ruflo init; si no, usa CLAUDE.global.md)

# 5) Memoria: copia docs/setup/claude-config/memory/*.md a
#    ~/.claude/projects/<ruta-codificada>/memory/

# 6) Skills del proyecto
mkdir -p .claude/skills && cp -rn docs/setup/claude-config/project-skills/. .claude/skills/
```

En PowerShell el paso 6 es:
```powershell
New-Item -ItemType Directory -Force .claude\skills | Out-Null
Copy-Item -Recurse -Force docs\setup\claude-config\project-skills\* .claude\skills\
```

---

## 4. Windows

- Instala Claude Code para Windows y Node.js.
- Corre los comandos de la sección 3 en **PowerShell** (o usa WSL y el script
  bash tal cual, recomendado).
- El binario de ruflo estará en la carpeta global de npm
  (`npm root -g` → sube a `..\ruflo.cmd`). Usa esa ruta en `claude mcp add` y en
  `ruflo.mcp.template.json`.

---

## 5. Verificación final

```bash
claude
/plugin      # superpowers, claude-mem, taskmaster, fullstack-dev-skills, stitch-*
/skills      # flutter-*, gsap-*, frontend-design, seguridad…
/mcp         # ruflo: connected
```
En una tarea nueva, deberías ver los skills de superpowers disponibles y las
sugerencias `[INTELLIGENCE]` de ruflo en los system-reminder.

---

## 6. Notas / troubleshooting

- **ruflo MCP falla con "active native WAL connection"**: no es bloqueante,
  reintenta en otra sesión (ver memoria "Sistema de tutoriales guiados").
- **claude-mem vs memoria nativa**: pueden solaparse; conviven, no es error.
- Plantilla del MCP de ruflo: `docs/setup/claude-config/ruflo.mcp.template.json`.
- Para que el propio Claude Code de tu PC lo instale por ti, dale el prompt de
  `docs/setup/PROMPT-para-claude-code-pc.md`.
