---
name: ruflo-instalado
description: "Ruflo (meta-harness multi-agente para Claude Code) instalado a nivel de usuario; cómo arrancar, verificar y desinstalar."
metadata: 
  node_type: memory
  type: reference
  originSessionId: ab5f14e5-b7bd-41ab-8f9d-5fb18fcb8e09
  modified: 2026-07-21T18:27:25.057Z
---

Ruflo v3.32.9 (repo ruvnet/ruflo, paquete npm `ruflo`) instalado el 2026-07-21 para usar con Claude Code.

**Cómo se instaló (para no romper el repo COSSMIL):**
- CLI en prefijo de usuario, sin sudo: `npm install -g ruflo@latest --prefix ~/.npm-global` → binario en `~/.npm-global/bin/ruflo`.
- Workspace completo (`ruflo init --full --all-agents --no-signup --no-codex-detect --no-skills-sh`) en **`~/ruflo`**, NO en el proyecto COSSMIL (evita pisar su CLAUDE.md y ensuciar git). Genera 89 agentes, 34 skills, 21 comandos, hooks y `.claude-flow/`.
- MCP registrado a scope **user** apuntando al binario instalado (no a `npx ruflo@latest`, que fallaba el health check por latencia): `claude mcp add ruflo --scope user -- ~/.npm-global/bin/ruflo mcp start`. Estado: ✔ Connected.

**Backups previos** (por si init hubiera pisado algo): en scratchpad de la sesión, `CLAUDE.md.cossmil.bak`. El global `~/.claude/CLAUDE.md` no existía antes.

**Arrancar workers/enjambre** (opcional, desde `~/ruflo`): `ruflo daemon start`, `ruflo swarm init`, o `ruflo init --start-all`.

**Desinstalar:** `claude mcp remove ruflo --scope user`; `npm uninstall -g ruflo --prefix ~/.npm-global`; borrar `~/ruflo`. El PATH `~/.npm-global/bin` no se agregó a ningún profile (se usa con ruta absoluta).

Notas: prefijo npm global del sistema es `/usr/local` (no escribible sin sudo), por eso el prefijo de usuario. Plugins/skills adicionales: `npx skills add ruvnet/ruflo --all` o slash `/plugin marketplace add ruvnet/ruflo` (esos los teclea el usuario).
