# gapix

Skill de [Agent Skills](https://agentskills.io) para construir APIs REST en **Go 1.26+** con **Clean Architecture + DDD ligero** y **solo la librería estándar**: `net/http` (`ServeMux`), `context`, `slog`, `sync.Pool` y `sqlc`. Sin Gin, Echo, Fiber ni Chi.

## Qué contiene

| Archivo | Propósito |
|---|---|
| `SKILL.md` | La skill (frontmatter portable + 11 secciones de guía). |
| `agents/openai.yaml` | Metadata opcional de Codex (nombre visible, invocación implícita). |
| `install.sh` / `uninstall.sh` | Instalación y desinstalación en OpenCode, Claude Code y Codex. |
| `tests/` | Validación del frontmatter y pruebas de instalación en un `HOME` temporal. |
| `Makefile` | Atajos: `install`, `uninstall`, `test`, `lint`, `dist`. |

## Instalación

```sh
git clone <repo> gapix && cd gapix
./install.sh            # global, copia
```

Eso deja la skill en:

| Herramienta | Ruta | Invocación |
|---|---|---|
| Codex (y compat OpenCode) | `~/.agents/skills/gapix` | `$gapix` o `/skills` |
| Claude Code | `~/.claude/skills/gapix` | `/gapix` |
| OpenCode | `~/.config/opencode/skills/gapix` | `@gapix` |

Reinicia la sesión si la herramienta no la detecta.

### Opciones

```sh
./install.sh --project .              # instala en el proyecto actual
./install.sh --tool claude            # solo Claude Code
./install.sh --link                   # symlinks en vez de copia (desarrollo)
./install.sh --dry-run                # muestra lo que haría
./install.sh --force                  # sobrescribe rutas ajenas a gapix
./install.sh --help
```

En modo proyecto instala en `DIR/.agents/skills/gapix`, `DIR/.claude/skills/gapix` y `DIR/.opencode/skills/gapix`.

## Desinstalación

```sh
./uninstall.sh                        # global
./uninstall.sh --project .            # proyecto
./uninstall.sh --dry-run
```

Solo elimina lo que instaló `gapix`, detectado por el marker `.gapix-install.json` o por un symlink que apunte a la ruta canónica. Si encuentra una ruta ajena la omite, avisa y termina con código `2` (usa `--force` para forzar). Nunca borra el contenido de un symlink ajeno.

## Verificación

```sh
make test    # valida SKILL.md e instala/desinstala en un HOME temporal
make lint    # shellcheck, si está instalado
```

## Distribución

```sh
make dist    # genera dist/gapix-<version>.tgz
```

El tarball contiene `gapix/{SKILL.md,agents/,README.md,LICENSE}`: se puede copiar a mano dentro de `~/.agents/skills/` o publicar como release.

## Compatibilidad

- **Formato**: Agent Skills (portable). Frontmatter con `name`, `description`, `license`, `compatibility` y `metadata`; ningún campo propietario.
- **Codex**: acepta la skill tal cual; `agents/openai.yaml` añade nombre visible y `allow_implicit_invocation`.
- **Claude Code**: acepta `license`, `compatibility` y `metadata` (los ignora sin romper). Ojo: si el YAML no parsea, Claude Code carga la skill **sin campos** → sin `description` no se auto-invoca. Por eso `make test` valida el YAML.
- **OpenCode**: el ID de la skill lo determina la **carpeta** (`gapix`), no el `name`.

## Licencia

MIT — ver [LICENSE](LICENSE).
