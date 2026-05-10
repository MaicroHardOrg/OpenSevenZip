APP_NAME ?= OpenSevenZip Explorer
EXECUTABLE := SevenZipMac
CONFIGURATION ?= release
BUILD_DIR := .build/$(CONFIGURATION)
UNIVERSAL_BUILD_DIR := .build/universal/$(CONFIGURATION)
DIST_DIR := dist
GITHUB_APP_NAME := OpenSevenZip Explorer-gh
GITHUB_APP_DIR := $(DIST_DIR)/$(GITHUB_APP_NAME).app
GITHUB_DMG := $(DIST_DIR)/OpenSevenZip-Explorer-gh.dmg
GITHUB_DMG_STAGING_DIR := $(DIST_DIR)/dmg-github
APP_DIR := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
OFFICIAL_BACKEND := Resources/7zz
SEVENZIP_VERSION ?= 26.01
SEVENZIP_FILE_VERSION ?= 2601
SEVENZIP_MAC_ARCHIVE := 7z$(SEVENZIP_FILE_VERSION)-mac.tar.xz
SEVENZIP_MAC_URL ?= https://github.com/ip7z/7zip/releases/download/$(SEVENZIP_VERSION)/$(SEVENZIP_MAC_ARCHIVE)
SEVENZIP_MAC_ARCHIVE_SHA256 ?= 0b6b930dbf82742e3f1014c35072a6b8b3aab183fece348e7f723675f1c5bea2
SEVENZIP_MAC_BINARY_SHA256 ?= 4d1baeaa33a40e7d8189c746a46f1be2186cc125bfcabfb63989db4e1c319247
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

.PHONY: build run install clean fetch-official-backend build-backend build-backend-x64 build-backend-arm64 build-backend-universal package package-github package-appstore dmg-github test test-appstore verify-architectures

build: package-github

package: package-github

package-github:
	$(MAKE) package-variant APP_NAME="$(GITHUB_APP_NAME)" INFO_PLIST="$(GITHUB_INFO_PLIST)" APP_ENTITLEMENTS="$(GITHUB_ENTITLEMENTS)" HELPER_ENTITLEMENTS="$(GITHUB_ENTITLEMENTS)" SWIFT_FLAGS=""

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
	if [ -d "Resources/Localizations" ]; then cp -R "Resources/Localizations" "$(RESOURCES_DIR)/Localizations"; fi
	if [ -x "Resources/7zz" ]; then cp "Resources/7zz" "$(MACOS_DIR)/7zz"; fi
	if [ -x "$(MACOS_DIR)/7zz" ]; then codesign --force --options runtime --entitlements "$(HELPER_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(MACOS_DIR)/7zz"; fi
	codesign --force --options runtime --entitlements "$(APP_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(MACOS_DIR)/$(EXECUTABLE)"
	codesign --force --options runtime --entitlements "$(APP_ENTITLEMENTS)" --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"

dmg-github: fetch-official-backend package-github
	test -x "$(GITHUB_APP_DIR)/Contents/MacOS/7zz"
	rm -rf "$(GITHUB_DMG_STAGING_DIR)" "$(GITHUB_DMG)"
	mkdir -p "$(GITHUB_DMG_STAGING_DIR)"
	cp -R "$(GITHUB_APP_DIR)" "$(GITHUB_DMG_STAGING_DIR)/"
	ln -s /Applications "$(GITHUB_DMG_STAGING_DIR)/Applications"
	hdiutil create -volname "$(GITHUB_APP_NAME)" -srcfolder "$(GITHUB_DMG_STAGING_DIR)" -ov -format UDZO "$(GITHUB_DMG)"
	rm -rf "$(GITHUB_DMG_STAGING_DIR)"
	ls -lh "$(GITHUB_DMG)"

fetch-official-backend:
	SEVENZIP_MAC_URL="$(SEVENZIP_MAC_URL)" SEVENZIP_MAC_ARCHIVE_SHA256="$(SEVENZIP_MAC_ARCHIVE_SHA256)" SEVENZIP_MAC_BINARY_SHA256="$(SEVENZIP_MAC_BINARY_SHA256)" OFFICIAL_BACKEND="$(OFFICIAL_BACKEND)" Scripts/fetch-official-7zz.sh

build-backend: build-backend-universal

build-backend-x64:
	$(MAKE) -C "$(OFFICIAL_BACKEND_DIR)" -f ../../cmpl_mac_x64.mak

build-backend-arm64:
	$(MAKE) -C "$(OFFICIAL_BACKEND_DIR)" -f ../../cmpl_mac_arm64.mak

build-backend-universal: build-backend-x64 build-backend-arm64
	test -x "$(OFFICIAL_BACKEND_X64)"
	test -x "$(OFFICIAL_BACKEND_ARM64)"
	lipo -create -output "$(OFFICIAL_BACKEND)" "$(OFFICIAL_BACKEND_X64)" "$(OFFICIAL_BACKEND_ARM64)"
	chmod +x "$(OFFICIAL_BACKEND)"
	lipo -info "$(OFFICIAL_BACKEND)"

run: package-github
	open "$(APP_DIR)"

test:
	swift run $(EXECUTABLE) --self-test

test-appstore:
	swift run -Xswiftc -DAPP_STORE $(EXECUTABLE) --self-test

verify-architectures:
	lipo -info "$(MACOS_DIR)/$(EXECUTABLE)"
	lipo -info "$(MACOS_DIR)/7zz"

install: package-github
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"

clean:
	swift package clean
	rm -rf dist
