# Pastely release pipeline. `make help` lists targets.
#
# Local notarization needs a keychain profile once:
#   xcrun notarytool store-credentials pastely-notary --apple-id <id> --team-id L33ZEUXVN4 --password <app-specific password>
# CI passes APPLE_ID / DEVELOPMENT_TEAM / NOTARIZE_PASSWORD instead.

.PHONY: help build test app release notarize dmg appcast screenshots clean

VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
BUILD_DIR := build.noindex
RELEASE_APP := $(BUILD_DIR)/Pastely.app
ZIP := $(BUILD_DIR)/Pastely-$(VERSION).zip
DMG := $(BUILD_DIR)/Pastely-$(VERSION).dmg
DEV_ID := $(shell security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
NOTARY_PROFILE ?= pastely-notary

ifdef NOTARIZE_PASSWORD
NOTARY_AUTH := --apple-id "$(APPLE_ID)" --team-id "$(DEVELOPMENT_TEAM)" --password "$(NOTARIZE_PASSWORD)"
else
NOTARY_AUTH := --keychain-profile "$(NOTARY_PROFILE)"
endif

help: ## Show targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

build: ## Debug build
	swift build

test: ## Run unit tests
	swift test

app: ## Dev bundle at build.noindex/dev/Pastely.app, signed with the Apple Development cert
	./scripts/bundle.sh

release: ## Release bundle at build.noindex/Pastely.app, Developer ID signed with timestamp
	@test -n "$(DEV_ID)" || { echo "No Developer ID Application certificate found"; exit 1; }
	mkdir -p $(BUILD_DIR)
	APP_PATH="$(RELEASE_APP)" SIGN_IDENTITY="$(DEV_ID)" VERSION="$(VERSION)" PASTELY_DEV=0 ./scripts/bundle.sh
	codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"

notarize: release ## Submit the release app to Apple, wait, staple
	rm -f "$(ZIP)"
	ditto -c -k --keepParent "$(RELEASE_APP)" "$(ZIP)"
	xcrun notarytool submit "$(ZIP)" $(NOTARY_AUTH) --wait
	xcrun stapler staple "$(RELEASE_APP)"
	spctl --assess --type execute --verbose=2 "$(RELEASE_APP)"

dmg: notarize ## Package the stapled app into a notarized drag-to-Applications DMG
	rm -rf $(BUILD_DIR)/dmg-staging "$(DMG)"
	mkdir -p $(BUILD_DIR)/dmg-staging
	ditto "$(RELEASE_APP)" "$(BUILD_DIR)/dmg-staging/Pastely.app"
	ln -s /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	hdiutil create -volname "Pastely" -srcfolder "$(BUILD_DIR)/dmg-staging" -ov -format UDZO "$(DMG)"
	codesign --force --timestamp --sign "$(DEV_ID)" "$(DMG)"
	xcrun notarytool submit "$(DMG)" $(NOTARY_AUTH) --wait
	xcrun stapler staple "$(DMG)"
	rm -rf $(BUILD_DIR)/dmg-staging
	@echo "Built $(DMG)"; shasum -a 256 "$(DMG)"

appcast: ## Sign the DMG for Sparkle and write build.noindex/appcast.xml
	./scripts/appcast.sh "$(DMG)" "$(VERSION)" "$$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' $(RELEASE_APP)/Contents/Info.plist)" $(BUILD_DIR)/appcast.xml

screenshots: app ## Render marketing screenshots at 2x and 3x into ~/Desktop/Pastely Screenshots
	open build.noindex/dev/Pastely.app && sleep 3 && open "pastely-dev://screenshots"

clean: ## Remove build outputs
	rm -rf $(BUILD_DIR) Pastely.app .build
