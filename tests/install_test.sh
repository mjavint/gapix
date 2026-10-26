#!/usr/bin/env bash
#
# Prueba install.sh / uninstall.sh en un HOME temporal (no toca el real).
#
set -euo pipefail

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL="$REPO_DIR/install.sh"
UNINSTALL="$REPO_DIR/uninstall.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gapix-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

assert_file() {
  if [ -f "$1" ]; then pass "$2"; else fail "$2 ($1)"; fi
}

assert_dir() {
  if [ -d "$1" ]; then pass "$2"; else fail "$2 ($1)"; fi
}

assert_symlink() {
  if [ -L "$1" ] && [ -f "$1/SKILL.md" ]; then pass "$2"; else fail "$2 ($1)"; fi
}

assert_absent() {
  if [ ! -e "$1" ] && [ ! -L "$1" ]; then pass "$2"; else fail "$2 ($1 sigue existiendo)"; fi
}

assert_exit_ok() {
  desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc (exit != 0)"; fi
}

assert_fails() {
  desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then fail "$desc (debió fallar)"; else pass "$desc"; fi
}

# --- Escenario 1: instalación global por copia -------------------------------
H1="$TMP_ROOT/home1"
mkdir -p "$H1"

HOME="$H1" assert_exit_ok "install global termina con éxito" "$INSTALL" --global --tool codex,claude,opencode

assert_file "$H1/.agents/skills/gapix/SKILL.md" "canónico .agents instalado"
assert_file "$H1/.agents/skills/gapix/.gapix-install.json" "marker en canónico"
assert_file "$H1/.claude/skills/gapix/SKILL.md" "Claude Code instalado"
assert_file "$H1/.config/opencode/skills/gapix/SKILL.md" "OpenCode instalado"
assert_file "$H1/.agents/skills/gapix/agents/openai.yaml" "agents/openai.yaml copiado"

# --- Escenario 2: idempotencia ---------------------------------------------
HOME="$H1" assert_exit_ok "segunda ejecución es idempotente" "$INSTALL" --global
assert_file "$H1/.agents/skills/gapix/SKILL.md" "canónico sigue instalado tras reinstalar"

# --- Escenario 3: dry-run no escribe ---------------------------------------
H2="$TMP_ROOT/home2"
mkdir -p "$H2"
HOME="$H2" assert_exit_ok "dry-run termina con éxito" "$INSTALL" --global --dry-run
assert_absent "$H2/.agents" "dry-run no crea .agents"
assert_absent "$H2/.claude" "dry-run no crea .claude"

# --- Escenario 4: desinstalación -------------------------------------------
HOME="$H1" assert_exit_ok "uninstall global termina con éxito" "$UNINSTALL" --global
assert_absent "$H1/.agents/skills/gapix" "canónico eliminado"
assert_absent "$H1/.claude/skills/gapix" "Claude Code eliminado"
assert_absent "$H1/.config/opencode/skills/gapix" "OpenCode eliminado"

# --- Escenario 5: no pisa instalaciones ajenas -----------------------------
H3="$TMP_ROOT/home3"
mkdir -p "$H3/.claude/skills/gapix"
printf 'skill ajena\n' > "$H3/.claude/skills/gapix/SKILL.md"
HOME="$H3" assert_fails "install se niega a sobrescribir algo ajeno" "$INSTALL" --global --tool claude
HOME="$H3" assert_exit_ok "install --force sobrescribe" "$INSTALL" --global --tool claude --force
if grep -q "name: gapix" "$H3/.claude/skills/gapix/SKILL.md" 2>/dev/null; then
  pass "--force reemplazó el contenido"
else
  fail "--force no reemplazó el contenido"
fi

# --- Escenario 6: modo proyecto -------------------------------------------
PROJ="$TMP_ROOT/proj"
mkdir -p "$PROJ"
assert_exit_ok "install --project termina con éxito" "$INSTALL" --project "$PROJ"
assert_file "$PROJ/.agents/skills/gapix/SKILL.md" "proyecto .agents instalado"
assert_file "$PROJ/.claude/skills/gapix/SKILL.md" "proyecto .claude instalado"
assert_file "$PROJ/.opencode/skills/gapix/SKILL.md" "proyecto .opencode instalado"
assert_exit_ok "uninstall --project termina con éxito" "$UNINSTALL" --project "$PROJ"
assert_absent "$PROJ/.agents/skills/gapix" "proyecto .agents eliminado"
assert_absent "$PROJ/.claude/skills/gapix" "proyecto .claude eliminado"
assert_absent "$PROJ/.opencode/skills/gapix" "proyecto .opencode eliminado"

# --- Escenario 7: modo symlink --------------------------------------------
H4="$TMP_ROOT/home4"
mkdir -p "$H4"
HOME="$H4" assert_exit_ok "install --link termina con éxito" "$INSTALL" --global --link
assert_symlink "$H4/.claude/skills/gapix" "Claude Code es symlink al canónico"
assert_symlink "$H4/.config/opencode/skills/gapix" "OpenCode es symlink al canónico"
HOME="$H4" assert_exit_ok "uninstall tras --link termina con éxito" "$UNINSTALL" --global
assert_absent "$H4/.claude/skills/gapix" "symlink eliminado"
assert_absent "$H4/.agents/skills/gapix" "canónico eliminado tras --link"

# --- Escenario 8: opciones inválidas --------------------------------------
assert_fails "--tool inválido falla" "$INSTALL" --tool nope
assert_fails "--project inexistente falla" "$INSTALL" --project "$TMP_ROOT/no-existe"

printf '\ninstall_test: %d ok, %d fallos\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
