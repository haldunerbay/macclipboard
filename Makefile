APP_NAME := ClipHistory
APP := build/Clip History.app
INSTALL_DIR ?= /Applications
# A stable signature keeps the Accessibility permission across rebuilds; falls back to ad-hoc.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk '/Apple Development/ {print $$2; exit}')

.PHONY: help build app install run test clean

help:
	@echo "make app      build build/Clip History.app"
	@echo "make install  build, copy to $(INSTALL_DIR) and start it"
	@echo "make test     run the unit tests"

build:
	swift build -c release

app: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp .build/release/$(APP_NAME) "$(APP)/Contents/MacOS/"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --sign "$(if $(SIGN_IDENTITY),$(SIGN_IDENTITY),-)" "$(APP)"

install: app
	-pkill -x $(APP_NAME)
	rm -rf "$(INSTALL_DIR)/Clip History.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/Clip History.app"

run: app
	-pkill -x $(APP_NAME)
	open "$(APP)"

test:
	swift test

clean:
	rm -rf .build build
