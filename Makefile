PLUGIN := org.wallshift.wallpaper
QSB ?= qsb
QSB_FLAGS := --glsl "150,300 es,310 es"
SHADER_DIR := $(PLUGIN)/contents/ui/shaders
SHADERS := crossfade simple wipe wave grow outer

.PHONY: all shaders install upgrade clean

all: shaders

shaders:
	@for f in $(SHADERS); do \
		echo "Compiling $$f..."; \
		$(QSB) $(QSB_FLAGS) $(SHADER_DIR)/$$f.frag -o $(SHADER_DIR)/$$f.frag.qsb || exit 1; \
	done

install:
	kpackagetool6 --type Plasma/Wallpaper --install $(PLUGIN)

upgrade:
	kpackagetool6 --type Plasma/Wallpaper --upgrade $(PLUGIN)

clean:
	rm -f $(SHADER_DIR)/*.qsb
