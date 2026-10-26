#!/usr/bin/env bash
#
# gapix — desinstalador.
#
# Elimina únicamente lo que instaló install.sh (detectado por el marker
# .gapix-install.json o por symlinks que apuntan a la ubicación canónica).
# Nunca borra el contenido de un symlink ajeno.
#
set -euo pipefail

SKILL_NAME="gapix"
MARKER_FILE=".gapix-install.json"

SCOPE="global"
PROJECT_DIR="."
TOOLS="codex,claude,opencode"
FORCE=0
DRY_RUN=0
SKIPPED=0
REMOVED=0

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
Uso: ./uninstall.sh [opciones]

Elimina la skill gapix de OpenCode, Claude Code y Codex.

Opciones:
  --project [DIR]   Desinstala de un proyecto (default: directorio actual)
  --global          Desinstala del usuario (default)
  --tool LIST       Herramientas: codex,claude,opencode (default: todas)
  --force           Elimina rutas aunque no tengan el marker de gapix
  --dry-run         Muestra las acciones sin borrar nada
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
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

[ -n "${HOME:-}" ] || die "HOME no está definido"

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

remove_target() {
  path="$1"

  if [ -L "$path" ]; then
    current=$(readlink "$path" 2>/dev/null || true)
    if [ "$FORCE" -eq 0 ] && [ "$current" != "$CANONICAL" ]; then
      warn "$path apunta a '$current' y no lo gestiona gapix; se omite (usa --force)"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    run rm -f "$path"
    info "eliminado symlink $path"
    REMOVED=$((REMOVED + 1))
    return 0
  fi

  if [ -d "$path" ]; then
    if [ -f "$path/$MARKER_FILE" ] || [ "$FORCE" -eq 1 ]; then
      run rm -rf "$path"
      info "eliminado $path"
      REMOVED=$((REMOVED + 1))
      return 0
    fi
    warn "$path no tiene marker de gapix; se omite (usa --force)"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [ -e "$path" ]; then
    if [ "$FORCE" -eq 0 ]; then
      warn "$path no es un directorio; se omite (usa --force)"
      SKIPPED=$((SKIPPED + 1))
      return 0
    fi
    run rm -f "$path"
    info "eliminado $path"
    REMOVED=$((REMOVED + 1))
    return 0
  fi

  return 0
}

say "gapix · desinstalando ($SCOPE)"

while IFS= read -r path; do
  [ -n "$path" ] || continue
  remove_target "$path"
done <<EOF
$TARGETS
EOF

say ""
if [ "$DRY_RUN" -eq 1 ]; then
  say "Simulación completada. No se borró nada."
elif [ "$REMOVED" -eq 0 ] && [ "$SKIPPED" -eq 0 ]; then
  say "No había nada instalado en las rutas revisadas."
else
  say "Eliminados: $REMOVED · omitidos: $SKIPPED"
fi

if [ "$SKIPPED" -gt 0 ]; then
  exit 2
fi
