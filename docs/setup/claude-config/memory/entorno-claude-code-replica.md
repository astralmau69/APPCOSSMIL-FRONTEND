---
name: entorno-claude-code-replica
description: "Cómo replicar en otra PC este entorno de Claude Code (plugins, MCP ruflo, config, memoria); todo versionado en el repo."
metadata:
  node_type: memory
  type: reference
  originSessionId: 1ab52369-4f74-4f82-80d9-c7736645cfe7
  modified: 2026-09-23T01:20:35.336Z
---

Para trabajar en otra PC "igual que aquí", el entorno de Claude Code quedó
versionado en el repo (rama `preTutorial`, 22 sep 2026):

- Guía: `docs/setup/entorno-claude-code.md`
- Instalador: `tools/setup/setup-claude-env.sh` (`--dry-run` para ver el plan).
- Config sin secretos: `docs/setup/claude-config/` (settings.json, CLAUDE.global.md,
  ruflo.mcp.template.json, y copia de la memoria del proyecto en `memory/`).
- Prompt listo para pegar en el Claude Code de la PC nueva:
  `docs/setup/PROMPT-para-claude-code-pc.md`.

Inventario que replica: marketplaces (anthropics/claude-plugins-official,
jeffallan/claude-skills, google-labs-code/stitch-skills, obra/superpowers,
thedotmack/claude-mem, eyaltoledano/claude-task-master); plugins activos
(superpowers, claude-mem, taskmaster, fullstack-dev-skills, stitch-*); MCP ruflo
(`ruflo mcp start`, scope user, SIN secretos — env vacío); settings global
(opus-4-8, effort high, tema oscuro). `skipDangerousModePermissionPrompt` se dejó
FUERA por defecto (riesgoso). Login de Claude y credenciales NO se versionan.

La carpeta de memoria destino es `~/.claude/projects/<ruta-abs-codificada>/memory/`
donde la ruta usa `/ _ .` → `-`. Si Claude Code creó otro nombre, copiar los .md
al `memory/` correcto.

Relacionado: [[ruflo-instalado]], [[plugins-superpowers-claudemem-taskmaster]].
