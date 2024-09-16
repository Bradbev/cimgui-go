NAME=cimgui-go Code Generator

.PHONY: all

## all: generates both bindings.
all: generate

## setup: prepare some dependencies
.PHONY: setup
setup:
	go get mvdan.cc/gofumpt@latest
	cd cmd/codegen; \
		go build -o ../../codegen .

# Parameters:
# $1: prefix
# $2: include path (of header file)
# $3: definitions.json filepath
# $4: structs_and_enums.json filepath
# $5: typedefs_dict.json filepath
# $6: additional agruments to codegen call (e.g. -r option)
define generate
	@echo "Generating for $(1)"
	./codegen -p $(1) -i $(2) -d $(3) -e $(4) -t $(5) $(6)
	go run mvdan.cc/gofumpt@latest -w $(1)_enums.go
	go run mvdan.cc/gofumpt@latest -w $(1)_funcs.go
	go run mvdan.cc/gofumpt@latest -w $(1)_typedefs.go
	go run golang.org/x/tools/cmd/goimports@latest -w $(1)_funcs.go
	go run golang.org/x/tools/cmd/goimports@latest -w $(1)_typedefs.go
endef

define cimgui
	$(call generate,cimgui,cwrappers/cimgui.h,cwrappers/cimgui_templates/definitions.json,cwrappers/cimgui_templates/structs_and_enums.json, cwrappers/cimgui_templates/typedefs_dict.json)
endef

## cimgui: generate cimgui binding
.PHONY: cimgui
cimgui: setup
	$(call cimgui)

define cimplot
	$(call generate,cimplot,cwrappers/cimplot.h,cwrappers/cimplot_templates/definitions.json,cwrappers/cimplot_templates/structs_and_enums.json,cwrappers/cimplot_templates/typedefs_dict.json,-r cwrappers/cimgui_templates/structs_and_enums.json -rt cwrappers/cimgui_templates/typedefs_dict.json)
endef

## cimplot: generate implot binding
.PHONY: cimplot
cimplot: setup
	$(call cimplot)

define cimnodes
	$(call generate,cimnodes,cwrappers/cimnodes.h,cwrappers/cimnodes_templates/definitions.json,cwrappers/cimnodes_templates/structs_and_enums.json,cwrappers/cimnodes_templates/typedefs_dict.json,-r cwrappers/cimgui_templates/structs_and_enums.json -rt cwrappers/cimgui_templates/typedefs_dict.json)
endef

## cimnodes: generate imnodes binding
.PHONY: cimnodes
cimnodes: setup
	$(call cimnodes)

define cimmarkdown
	$(call generate,cimmarkdown,cwrappers/cimmarkdown.h,cwrappers/cimmarkdown_templates/definitions.json,cwrappers/cimmarkdown_templates/structs_and_enums.json,cwrappers/cimmarkdown_templates/typedefs_dict.json,-r cwrappers/cimgui_templates/structs_and_enums.json -rt cwrappers/cimgui_templates/typedefs_dict.json)
endef

## cimmarkdown: generate immarkdown binding
.PHONY: cimmarkdown
cimmarkdown: setup
	$(call cimmarkdown)

compile_cimgui_macos:
	rm -rf ./lib/build
	cd ./lib; cmake -Bbuild -DCMAKE_BUILD_TYPE=Release -DIMGUI_STATIC=On -DCMAKE_OSX_ARCHITECTURES=arm64
	cd ./lib/build; make
	cp -f ./lib/build/cimgui.a ./lib/macos/arm64/

## generate: generates both bindings (equal to `all`)
.PHONY: generate
generate: cimgui cimplot cimnodes cimmarkdown

# update updates sub-repos (like cimplot or cimgui)
# $1 - subrepo directory
# $2 - repository URL
# $3 - $1/<c++ repo>/
# $4 - branch in $3 (cd tmp/$1/$3 && git checkout $4)
define update
	@echo "updating $1 from $2"
	mkdir -p tmp/
	if test -e tmp/$1; then \
		rm -rf tmp/*; \
	fi
	git clone --recurse-submodules $2 tmp/$1
	cd tmp/$1/$3; \
		git checkout $4
	cd tmp/$1/generator; \
		bash generator.sh --target "internal noimstrv comments" --cflags "glfw opengl3 opengl2 sdl2 -DIMGUI_USE_WCHAR32"
	cp -f tmp/$1/$1* cwrappers/
	if test -e tmp/$1/generator/output/$1*; then \
		cp -f tmp/$1/generator/output/$1* cwrappers/; \
	fi
	mkdir cwrappers/$1_templates
	cp -f tmp/$1/generator/output/*json cwrappers/$1_templates
	mkdir -p cwrappers/$3
	cp -rf tmp/$1/$3/* cwrappers/$3
	cd tmp/$1; \
		echo "$1 ($2) HEAD is on: `git rev-parse HEAD`" >> ../../cwrappers/VERSION.txt
	cd tmp/$1/$3; \
		echo "$1/$3 HEAD is on: `git rev-parse HEAD`" >> ../../../cwrappers/VERSION.txt
endef

.PHONY: update
update: setup
	rm -rf cwrappers/*
	$(call update,cimgui,https://github.com/cimgui/cimgui,imgui,docking)
	cat templates/assert.h >> cwrappers/imgui/imconfig.h
	$(call cimgui)
	$(call update,cimplot,https://github.com/cimgui/cimplot,implot,master)
	$(call cimplot)
	$(call update,cimnodes,https://github.com/cimgui/cimnodes,imnodes,master)
	$(call cimnodes)
	$(call update,cimmarkdown,https://github.com/gucio321/cimmarkdown,imgui_markdown,main)
	$(call cimmarkdown)
	echo -e "// +build rquired\n\npackage imgui\n\nimport (\n" > dummy.go
	for i in `find cwrappers -type f \( -name "*.h" -o -name "*.cpp" \) -exec dirname {} \; | sort -u`; do \
		cp templates/dummy.go.template $$i/dummy.go; \
		echo -e "\t\"github.com/AllenDang/cimgui-go/$$i\"" >> dummy.go; \
		done
	echo ")" >> dummy.go
