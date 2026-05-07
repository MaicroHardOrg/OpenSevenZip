APP_NAME ?= OpenSevenZip Explorer
EXECUTABLE := SevenZipMac
CONFIGURATION ?= release
BUILD_DIR := .build/$(CONFIGURATION)
UNIVERSAL_BUILD_DIR := .build/universal/$(CONFIGURATION)
DIST_DIR := dist
APP_DIR := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SEVENZIP_ROOT := ../7zip
OFFICIAL_BACKEND_DIR := $(SEVENZIP_ROOT)/CPP/7zip/Bundles/Alone2
OFFICIAL_BACKEND_X64 := $(OFFICIAL_BACKEND_DIR)/b/m_x64/7zz
OFFICIAL_BACKEND_ARM64 := $(OFFICIAL_BACKEND_DIR)/b/m_arm64/7zz
ARCHS ?= x86_64 arm64
SIGN_IDENTITY ?= -
GITHUB_INFO_PLIST := Resources/Info.github.plist
APPSTORE_INFO_PLIST := Resources/Info.appstore.plist
GITHUB_ENTITLEMENTS := Resources/Entitlements.github.plist
APPSTORE_ENTITLEMENTS := Resources/Entitlements.appstore.plist
APPSTORE_HELPER_ENTITLEMENTS := Resources/Entitlements.7zz.appstore.plist

.PHONY: build run install clean build-backend build-backend-x64 build-backend-arm64 build-backend-universal package package-github package-appstore test test-appstore verify-architectures

build: package-github

package: package-github

package-github:
	$(MAKE) package-variant APP_NAME="OpenSevenZip Explorer-gh" INFO_PLIST="$(GITHUB_INFO_PLIST)" APP_ENTITLEMENTS="$(GITHUB_ENTITLEMENTS)" HELPER_ENTITLEMENTS="$(GITHUB_ENTITLEMENTS)" SWIFT_FLAGS=""

package-appstore:
	$(MAKE) package-variant APP_NAME="OpenSevenZip Explorer" INFO_PLIST="$(APPSTORE_INFO_PLIST)" APP_ENTITLEMENTS="$(APPSTORE_ENTITLEMENTS)" HELPER_ENTITLEMENTS="$(APPSTORE_HELPER_ENTITLEMENTS)" SWIFT_FLAGS="-Xswiftc -DAPP_STORE"

package-variant:
	swift build -c $(CONFIGURATION) --arch x86_64 $(SWIFT_FLAGS)
	swift build -c $(CONFIGURATION) --arch arm64 $(SWIFT_FLAGS)
	mkdir -p "$(UNIVERSAL_BUILD_DIR)"
	lipo -create -output "$(UNIVERSAL_BUILD_DIR)/$(EXECUTABLE)" ".build/x86_64-apple-macosx/$(CONFIGURATION)/$(EXECUTABLE)" ".build/arm64-apple-macosx/$(CONFIGURATION)/$(EXECUTABLE)"
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(UNIVERSAL_BUILD_DIR)/$(EXECUTABLE)" "$(MACOS_DIR)/$(EXECUTABLE)"
	cp "$(INFO_PLIST)" "$(CONTENTS_DIR)/Info.plist"
	cp "Resources/AppIcon.icns" "$(RESOURCES_DIR)/AppIcon.icns"
	cp "Resources/ThirdPartyNotices.txt" "$(RESOURCES_DIR)/ThirdPartyNotices.txt"
	if [ -x "Resources/7zz" ]; then cp "Resources/7zz" "$(RESOURCES_DIR)/7zz"; fi
	if [ -x "$(RESOURCES_DIR)/7zz" ]; then codesign --force --options runtime --entitlements "$(HELPER_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(RESOURCES_DIR)/7zz"; fi
	codesign --force --options runtime --entitlements "$(APP_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(MACOS_DIR)/$(EXECUTABLE)"
	codesign --force --options runtime --entitlements "$(APP_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"

build-backend: build-backend-universal

build-backend-x64:
	$(MAKE) -C "$(OFFICIAL_BACKEND_DIR)" -f ../../cmpl_mac_x64.mak

build-backend-arm64:
	$(MAKE) -C "$(OFFICIAL_BACKEND_DIR)" -f ../../cmpl_mac_arm64.mak

build-backend-universal: build-backend-x64 build-backend-arm64
	test -x "$(OFFICIAL_BACKEND_X64)"
	test -x "$(OFFICIAL_BACKEND_ARM64)"
	lipo -create -output "Resources/7zz" "$(OFFICIAL_BACKEND_X64)" "$(OFFICIAL_BACKEND_ARM64)"
	chmod +x "Resources/7zz"
	lipo -info "Resources/7zz"

run: package-github
	open "$(APP_DIR)"

test:
	swift run $(EXECUTABLE) --self-test

test-appstore:
	swift run -Xswiftc -DAPP_STORE $(EXECUTABLE) --self-test

verify-architectures:
	lipo -info "$(MACOS_DIR)/$(EXECUTABLE)"
	lipo -info "$(RESOURCES_DIR)/7zz"

install: package-github
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf dist
