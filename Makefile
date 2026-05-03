APP_NAME := 7-Zip
EXECUTABLE := SevenZipMac
CONFIGURATION ?= release
BUILD_DIR := .build/$(CONFIGURATION)
APP_DIR := dist/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SEVENZIP_ROOT := ../7zip
OFFICIAL_BACKEND_DIR := $(SEVENZIP_ROOT)/CPP/7zip/Bundles/Alone2
OFFICIAL_BACKEND := $(OFFICIAL_BACKEND_DIR)/b/m_x64/7zz

.PHONY: build run install clean build-backend package test

build: package

package:
	swift build -c $(CONFIGURATION)
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(BUILD_DIR)/$(EXECUTABLE)" "$(MACOS_DIR)/$(EXECUTABLE)"
	cp "Resources/Info.plist" "$(CONTENTS_DIR)/Info.plist"
	if [ -x "Resources/7zz" ]; then cp "Resources/7zz" "$(RESOURCES_DIR)/7zz"; fi
	codesign --force --deep --sign - "$(APP_DIR)"

build-backend:
	$(MAKE) -C "$(OFFICIAL_BACKEND_DIR)" -f ../../cmpl_mac_x64.mak
	cp "$(OFFICIAL_BACKEND)" "Resources/7zz"

run: package
	open "$(APP_DIR)"

test:
	swift run $(EXECUTABLE) --self-test

install: package
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf dist
