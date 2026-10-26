#!/usr/bin/env bash
#
# gapix — instalador de la skill para OpenCode, Claude Code y Codex.
#
# Copia la skill a una ubicación canónica (~/.agents/skills/gapix) y crea
# aliases para cada herramienta. No requiere dependencias externas.
#
set -euo pipefail

SKILL_NAME="gapix"
MARKER_FILE=".gapix-install.json"
PAYLOAD_FILES="SKILL.md README.md LICENSE VERSION"
PAYLOAD_DIRS="agents"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

VERSION="0.0.0"
if [ -f "$SCRIPT_DIR/VERSION" ]; then
  VERSION=$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")
fi

SCOPE="global"
PROJECT_DIR="."
TOOLS="codex,claude,opencode"
MODE="copy"
FORCE=0
DRY_RUN=0

say()  { printf '%s\n' "$*"; }
info() { printf '  - %s\n' "$*"; }
warn() { printf 'aviso: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

usage() {
  cat <<'EOF'
Uso: ./install.sh [opciones]

Instala la skill gapix en OpenCode, Claude Code y Codex.

Destinos (modo global):
  ~/.agents/skills/gapix            canónico (Codex + compatibilidad OpenCode)
  ~/.claude/skills/gapix            Claude Code
  ~/.config/opencode/skills/gapix   OpenCode (nativo)

Destinos (--project DIR):
  DIR/.agents/skills/gapix
  DIR/.claude/skills/gapix
  DIR/.opencode/skills/gapix

Opciones:
  --project [DIR]   Instala dentro de un proyecto (default: directorio actual)
  --global          Instala a nivel de usuario (default)
  --tool LIST       Herramientas a instalar: codex,claude,opencode (default: todas)
  --link            Crea symlinks en vez de copiar (útil para desarrollo)
  --copy            Fuerza copia (default)
  --force           Sobrescribe rutas que no fueron instaladas por gapix
  --dry-run         Muestra las acciones sin escribir nada
  -V, --version     Muestra la versión
  -h, --help        Muestra esta ayuda
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      SCOPE="project"
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        PROJECT_DIR="$2"
        shift 2
      else
        PROJECT_DIR="."
        shift
      fi
      ;;
    --global)
      SCOPE="global"
      shift
      ;;
    --tool)
      [ $# -ge 2 ] || die "--tool requiere un valor (codex,claude,opencode)"
      TOOLS="$2"
      shift 2
      ;;
    --link)
      MODE="link"
      shift
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -V|--version)
      say "gapix $VERSION"
      exit 0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "opción desconocida: $1 (usa --help)"
      ;;
  esac
done

[ -f "$SCRIPT_DIR/SKILL.md" ] || die "no encuentro SKILL.md junto a install.sh ($SCRIPT_DIR)"
[ -n "${HOME:-}" ] || die "HOME no está definido"

# Valida la lista de herramientas.
old_ifs=$IFS
IFS=','
for tool in $TOOLS; do
  case "$tool" in
    codex|claude|opencode) ;;
    "") ;;
    *) IFS=$old_ifs; die "herramienta inválida: $tool (usa codex,claude,opencode)" ;;
  esac
done
IFS=$old_ifs

want_tool() {
  case ",$TOOLS," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$SCOPE" = "project" ]; then
  [ -d "$PROJECT_DIR" ] || die "no existe el directorio de proyecto: $PROJECT_DIR"
  BASE=$(CDPATH= cd -- "$PROJECT_DIR" && pwd)
else
  BASE="$HOME"
fi

CANONICAL="$BASE/.agents/skills/$SKILL_NAME"
TARGETS="$CANONICAL"

if want_tool claude; then
  TARGETS="$TARGETS
$BASE/.claude/skills/$SKILL_NAME"
fi

if want_tool opencode; then
  if [ "$SCOPE" = "project" ]; then
    TARGETS="$TARGETS
$BASE/.opencode/skills/$SKILL_NAME"
  else
    TARGETS="$TARGETS
$HOME/.config/opencode/skills/$SKILL_NAME"
  fi
fi

clear_target() {
  path="$1"

  if [ -L "$path" ]; then
    current=$(readlink "$path" 2>/dev/null || true)
    if [ "$FORCE" -eq 0 ] && [ "$current" != "$CANONICAL" ]; then
      die "$path es un symlink a '$current' y no lo gestiona gapix (usa --force)"
    fi
    run rm -f "$path"
    return 0
  fi

  if [ -d "$path" ]; then
    if [ -f "$path/$MARKER_FILE" ] || [ "$FORCE" -eq 1 ]; then
      run rm -rf "$path"
      return 0
    fi
    die "$path ya existe y no fue instalada por gapix (usa --force para sobrescribir)"
  fi

  if [ -e "$path" ]; then
    [ "$FORCE" -eq 1 ] || die "$path existe y no es un directorio (usa --force)"
    run rm -f "$path"
  fi
}

write_marker() {
  dest="$1"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] escribir %s/%s\n' "$dest" "$MARKER_FILE"
    return 0
  fi

  cat > "$dest/$MARKER_FILE" <<EOF
{
  "skill": "$SKILL_NAME",
  "version": "$VERSION",
  "source": "$SCRIPT_DIR",
  "mode": "$MODE",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

install_payload() {
  dest="$1"

  run mkdir -p "$dest"

  for f in $PAYLOAD_FILES; do
    [ -f "$SCRIPT_DIR/$f" ] || continue
    run cp "$SCRIPT_DIR/$f" "$dest/$f"
  done

  for d in $PAYLOAD_DIRS; do
    [ -d "$SCRIPT_DIR/$d" ] || continue
    run rm -rf "$dest/$d"
    run cp -R "$SCRIPT_DIR/$d" "$dest/$d"
  done

  write_marker "$dest"
}

say "gapix $VERSION · modo $SCOPE · $MODE"

clear_target "$CANONICAL"
install_payload "$CANONICAL"

while IFS= read -r path; do
  [ -n "$path" ] || continue
  [ "$path" = "$CANONICAL" ] && continue

  clear_target "$path"
  run mkdir -p "$(dirname "$path")"

  if [ "$MODE" = "link" ]; then
    run ln -s "$CANONICAL" "$path"
  else
    install_payload "$path"
  fi
done <<EOF
$TARGETS
EOF

say ""
if [ "$DRY_RUN" -eq 1 ]; then
  say "Simulación completada. No se escribió nada."
else
  say "Instalado. Rutas:"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    info "$path"
  done <<EOF
$TARGETS
EOF
  say ""
  say "Invócala con:"
  if want_tool claude; then say "  Claude Code   /$SKILL_NAME"; fi
  if want_tool codex; then say "  Codex         \$$SKILL_NAME  (o /skills)"; fi
  if want_tool opencode; then say "  OpenCode      @$SKILL_NAME"; fi
  say ""
  say "Reinicia la sesión si la herramienta no la detecta."
fi
