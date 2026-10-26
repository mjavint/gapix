SHELL := /bin/bash
VERSION := $(shell cat VERSION)

.PHONY: help install install-link uninstall test lint dist clean

help:
	@printf '%s\n' \
	  "gapix $(VERSION)" \
	  "" \
	  "  make install        instala global (copia)" \
	  "  make install-link   instala global con symlinks (desarrollo)" \
	  "  make project        instala en el proyecto actual" \
	  "  make uninstall      desinstala global" \
	  "  make test           valida la skill e instala/desinstala en HOME temporal" \
	  "  make lint           shellcheck (si está disponible)" \
	  "  make dist           genera dist/gapix-$(VERSION).tgz" \
	  "  make clean          limpia dist/"

install:
	@./install.sh --global

install-link:
	@./install.sh --global --link

project:
	@./install.sh --project .

uninstall:
	@./uninstall.sh --global

test:
	@bash tests/skill_test.sh
	@bash tests/install_test.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck install.sh uninstall.sh tests/*.sh && echo "shellcheck: ok"; \
	else \
	  echo "shellcheck no está instalado; se omite"; \
	fi

dist:
	@rm -rf dist/gapix
	@mkdir -p dist/gapix
	@cp SKILL.md README.md LICENSE VERSION dist/gapix/
	@cp -R agents dist/gapix/agents
	@tar -czf dist/gapix-$(VERSION).tgz -C dist gapix
	@rm -rf dist/gapix
	@printf 'creado dist/gapix-%s.tgz\n' "$(VERSION)"

clean:
	@rm -rf dist
