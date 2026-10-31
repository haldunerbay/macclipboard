APP_NAME := ClipHistory
APP := build/Clip History.app
INSTALL_DIR ?= /Applications
# A stable signature keeps the Accessibility permission across rebuilds; falls back to ad-hoc.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning | awk '/Apple Development/ {print $$2; exit}')
# Written into the bundle; releases pass the tag (make dmg VERSION=1.2.0).
VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
DMG := build/ClipHistory-$(VERSION).dmg

.PHONY: help build app universal-app dmg install run test clean

help:
	@echo "make app      build build/Clip History.app"
	@echo "make install  build, copy to $(INSTALL_DIR) and start it"
	@echo "make dmg      build $(DMG) for Apple silicon and Intel Macs"
	@echo "make test     run the unit tests"

build:
	swift build -c release

app: build
	$(call bundle,.build/release/$(APP_NAME))

# One binary for Apple silicon and Intel, for downloads.
universal-app:
	swift build -c release --arch arm64 --arch x86_64
	$(call bundle,.build/apple/Products/Release/$(APP_NAME))

# A disk image with the app and a link to Applications, to install by dragging.
dmg: universal-app
	rm -rf build/dmg "$(DMG)"
	mkdir -p build/dmg
	cp -R "$(APP)" build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Clip History" -srcfolder build/dmg -fs HFS+ -format UDZO -ov "$(DMG)"
	rm -rf build/dmg

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

# $(1): the built executable. Makes the app bundle, stamps the version and signs it.
define bundle
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	cp $(1) "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(APP)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" -c "Set :CFBundleVersion $(VERSION)" "$(APP)/Contents/Info.plist"
	codesign --force --sign "$(if $(SIGN_IDENTITY),$(SIGN_IDENTITY),-)" "$(APP)"
endef
