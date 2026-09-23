# Prompt para el Claude Code de tu PC

Copia y pega esto en Claude Code (dentro del repo ya clonado en tu PC) para que
instale el entorno por ti:

---

Quiero replicar en esta PC el entorno de Claude Code del proyecto. Todo está
versionado en este repo. Haz lo siguiente y ve informándome:

1. Lee `docs/setup/entorno-claude-code.md` completo.
2. Verifica prerrequisitos: `claude --version`, `node -v`, `npm -v`. Si falta
   Node o Claude Code, dime cómo instalarlos y detente ahí.
3. Corre `bash tools/setup/setup-claude-env.sh --dry-run` y muéstrame el plan.
4. Si se ve bien, corre `bash tools/setup/setup-claude-env.sh` para instalar
   marketplaces, plugins (superpowers, claude-mem, taskmaster,
   fullstack-dev-skills, stitch-*), ruflo + su MCP, la config global y la
   memoria del proyecto.
5. Al terminar, dime qué comprobar con `/plugin` y `/mcp`, y verifica que la
   carpeta de memoria haya quedado en el `~/.claude/projects/<...>/memory/`
   correcto (si el nombre no coincide, copia los `.md` de
   `docs/setup/claude-config/memory/` a la carpeta correcta).

Reglas:
- No subas ni pidas credenciales. El login de Claude lo hago yo.
- Si un `claude plugin ...` o `ruflo ...` falla, no te detengas: sigue con lo
  demás y al final lístame lo que quedó pendiente y cómo resolverlo.
- No actives `skipDangerousModePermissionPrompt` salvo que yo lo pida.

---

## Nota sobre secretos
Este repo **no** trae credenciales. Si en el futuro agregas un MCP que requiera
API key, guárdala en variables de entorno de tu sistema, **nunca** en archivos
versionados.
