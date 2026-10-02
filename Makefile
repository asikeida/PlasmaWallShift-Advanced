PLUGIN := io.github.asikeida.wallshiftadvanced
VERSION := $(shell awk -F'"' '/"Version"/ { print $$4; exit }' $(PLUGIN)/metadata.json)
ARCHIVE := wallshift-advanced-$(VERSION).tar.gz
QSB ?= $(shell command -v qsb 2>/dev/null || command -v qsb6 2>/dev/null || printf '%s' /usr/lib/qt6/bin/qsb)
QSB_FLAGS := --qsbversion 64 --glsl "150,300 es,310 es"
SHADER_DIR := $(PLUGIN)/contents/ui/shaders
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
	qmllint $(PLUGIN)/contents/ui/*.qml

dist: check
	tar -czf $(ARCHIVE) -C $(PLUGIN) metadata.json contents
	@echo "Created $(ARCHIVE)"

install:
	kpackagetool6 --type Plasma/Wallpaper --install $(PLUGIN)

upgrade:
	kpackagetool6 --type Plasma/Wallpaper --upgrade $(PLUGIN)

clean:
	rm -f $(SHADER_DIR)/*.qsb $(ARCHIVE)
