#!/usr/bin/env bash
#
# Valida SKILL.md: frontmatter portable (Agent Skills) y secciones esperadas.
#
set -euo pipefail

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SKILL_FILE="$REPO_DIR/SKILL.md"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$1"; }

check() {
  desc="$1"
  pattern="$2"
  if grep -qF -- "$pattern" "$SKILL_FILE"; then
    pass "$desc"
  else
    fail "$desc (falta: $pattern)"
  fi
}

[ -f "$SKILL_FILE" ] || { printf 'FAIL no existe %s\n' "$SKILL_FILE"; exit 1; }

first_line=$(head -n 1 "$SKILL_FILE")
if [ "$first_line" = "---" ]; then
  pass "frontmatter abre en la primera línea"
else
  fail "frontmatter debe abrir en la primera línea"
fi

closing=$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$SKILL_FILE")
if [ -n "$closing" ]; then
  pass "frontmatter cierra con ---"
else
  fail "frontmatter sin cierre ---"
fi

check "name: gapix"            "name: gapix"
check "description es block scalar" "description: >"
check "license: MIT"           "license: MIT"
check "compatibility: Go 1.26+" "compatibility: Go 1.26+"
check "metadata.stack"         "  stack: go, net/http, stdlib, clean-architecture, ddd, concurrency, memory-efficiency"

sections=(
  "# Go Clean API · Standard Library Only"
  "## 1. Principios irrenunciables"
  "## 2. Arquitectura: Clean Architecture + DDD ligero"
  "## 3. Implementación con net/http (Go 1.26+)"
  "## 4. Concurrencia segura"
  "## 5. Manejo eficiente de memoria"
  "## 6. Patrones de API"
  "## 7. Observabilidad"
  "## 8. Base de datos con sqlc"
  "## 9. Testing sin frameworks HTTP"
  "## 10. Anti-patrones a rechazar"
  "## 11. Checklist de salida"
)

for section in "${sections[@]}"; do
  check "sección presente: $section" "$section"
done

# El frontmatter no debe declarar campos extra (solo name, description, license,
# compatibility y metadata).
extra=$(awk -v end="$closing" 'NR > 1 && NR < end' "$SKILL_FILE" \
  | grep -E '^[A-Za-z0-9_-]+:' \
  | grep -vE '^(name|description|license|compatibility|metadata):' || true)
if [ -z "$extra" ]; then
  pass "sin campos extra en el frontmatter"
else
  fail "campos extra en el frontmatter: $extra"
fi

# Validación real de YAML si hay ruby disponible.
if command -v ruby >/dev/null 2>&1; then
  yaml_out=$(ruby -ryaml -e '
    text = File.read(ARGV[0])
    front = text.split(/^---\s*$/)[1] || ""
    data = YAML.safe_load(front, permitted_classes: [], aliases: true)
    raise "name" unless data["name"] == "gapix"
    raise "description" if data["description"].to_s.strip.empty?
    raise "license" unless data["license"] == "MIT"
    raise "compatibility" unless data["compatibility"] == "Go 1.26+"
    raise "metadata" unless data["metadata"].is_a?(Hash) && data["metadata"]["stack"]
    puts "ok"
  ' "$SKILL_FILE" 2>&1) || true

  if [ "$yaml_out" = "ok" ]; then
    pass "YAML válido y campos correctos"
  else
    fail "YAML inválido: $yaml_out"
  fi
else
  printf 'skip ruby no disponible: validación YAML profunda\n'
fi

printf '\nskill_test: %d ok, %d fallos\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
