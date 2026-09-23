---
name: plugins-superpowers-claudemem-taskmaster
description: "Tres marketplaces/plugins de Claude Code instalados a nivel usuario el 2026-07-27: superpowers, claude-mem, taskmaster."
metadata: 
  node_type: memory
  type: reference
  originSessionId: dab608b4-3b93-41ae-bb3a-c7e134a32a94
  modified: 2026-07-27T12:36:25.555Z
---

Instalado el 2026-07-27 vía `claude plugin marketplace add` + `claude plugin install` (scope user, aplican a todos los proyectos, no solo Post2):

- **superpowers@superpowers-dev** (repo `obra/superpowers`, Jesse Vincent) — librería grande de skills de ingeniería (TDD, debugging, patrones de colaboración).
- **claude-mem@thedotmack** (repo `thedotmack/claude-mem`, Alex Newman) — sistema de memoria persistente entre sesiones vía compresión de contexto.
- **taskmaster@taskmaster** (repo `eyaltoledano/claude-task-master`) — gestión de tareas con IA (desglose, análisis de complejidad, orquestación).

**Ojo con claude-mem:** este proyecto (Post2) ya tenía un sistema de auto-memoria nativo basado en archivos en `~/.claude/projects/-mnt-Nuevo-vol-app-Post2/memory/` (este mismo directorio, indexado por `MEMORY.md`). claude-mem es un mecanismo aparte (compresión de transcripts vía su propio storage/MCP) — pueden solaparse o duplicar propósito. Si en el futuro se nota comportamiento raro de memoria (contexto repetido, dos fuentes de verdad), revisar si claude-mem está interfiriendo antes de asumir que es el sistema nativo.

Verificado antes de instalar que los tres repos tienen `.claude-plugin/marketplace.json` válido (no son typosquats): superpowers 261k★, claude-mem 88k★, claude-task-master 27k★ en GitHub.

Requiere reiniciar la sesión de Claude Code para que los nuevos skills/agentes/hooks carguen.

**Desinstalar si hace falta:** `claude plugin uninstall <name>@<marketplace>` y opcionalmente `claude plugin marketplace remove <marketplace>`.
