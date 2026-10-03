PLUGIN := io.github.asikeida.wallshiftadvanced
VERSION := $(shell awk -F'"' '/"Version"/ { print $$4; exit }' $(PLUGIN)/metadata.json)
ARCHIVE := wallshift-advanced-$(VERSION).tar.gz
QSB ?= $(shell command -v qsb 2>/dev/null || command -v qsb6 2>/dev/null || printf '%s' /usr/lib/qt6/bin/qsb)
QSB_FLAGS := --qsbversion 64 --glsl "150,300 es,310 es"
QMLLINT ?= $(shell command -v qmllint6 2>/dev/null || test ! -x /usr/lib/qt6/bin/qmllint || printf '%s' /usr/lib/qt6/bin/qmllint)
QMLLINT := $(if $(QMLLINT),$(QMLLINT),qmllint)
QMLLINT_FLAGS := --unqualified disable --missing-property disable --unused-imports disable
SHADER_DIR := $(PLUGIN)/contents/ui/shaders
HELPER := $(PLUGIN)/contents/tools/wallshift-next
HELPER_DESKTOP := $(PLUGIN)/contents/tools/io.github.asikeida.wallshiftadvanced.next.desktop
USER_BIN ?= $(HOME)/.local/bin
USER_APPLICATIONS ?= $(HOME)/.local/share/applications
SHADERS := crossfade simple wipe wave grow outer stripes pixelate iris portal
PO := po/zh_CN/io.github.asikeida.wallshiftadvanced.po
MO := $(PLUGIN)/contents/locale/zh_CN/LC_MESSAGES/plasma_wallpaper_io.github.asikeida.wallshiftadvanced.mo

.PHONY: all shaders translations check dist install upgrade clean

all: shaders translations

shaders:
	@for f in $(SHADERS); do \
		echo "Compiling $$f..."; \
		$(QSB) $(QSB_FLAGS) $(SHADER_DIR)/$$f.frag -o $(SHADER_DIR)/$$f.frag.qsb || exit 1; \
	done

translations:
	msgfmt --check --check-format -o $(MO) $(PO)

check: all
	$(QMLLINT) $(QMLLINT_FLAGS) $(PLUGIN)/contents/ui/*.qml

dist: check
	tar -czf $(ARCHIVE) -C $(PLUGIN) metadata.json contents
	@echo "Created $(ARCHIVE)"

install:
	kpackagetool6 --type Plasma/Wallpaper --install $(PLUGIN)
	install -Dm755 $(HELPER) $(USER_BIN)/wallshift-next
	install -Dm644 $(HELPER_DESKTOP) $(USER_APPLICATIONS)/io.github.asikeida.wallshiftadvanced.next.desktop

upgrade:
	kpackagetool6 --type Plasma/Wallpaper --upgrade $(PLUGIN)
	install -Dm755 $(HELPER) $(USER_BIN)/wallshift-next
	install -Dm644 $(HELPER_DESKTOP) $(USER_APPLICATIONS)/io.github.asikeida.wallshiftadvanced.next.desktop

clean:
	rm -f $(SHADER_DIR)/*.qsb $(ARCHIVE)
