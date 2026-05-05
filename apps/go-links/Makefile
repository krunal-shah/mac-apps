# ============================================================
#  Command Shelf – macOS menu bar app
#  Requires: Xcode Command Line Tools (swift, swiftc)
#  Targets macOS 13 (Ventura)+
# ============================================================

APP_NAME    = CommandShelf
DISPLAY_NAME = Command Shelf
EXECUTABLE  = GoLinks
BUILD_DIR   = .build
APP_BUNDLE  = $(BUILD_DIR)/$(APP_NAME).app
BINARY      = $(BUILD_DIR)/release/$(EXECUTABLE)
INFO_PLIST  = Resources/Info.plist
ICON_FILE   = Resources/AppIcon.icns
INSTALL_DIR = /Applications
ZIP_FILE    = $(BUILD_DIR)/$(APP_NAME).app.zip

.PHONY: build app install clean run open test release-zip

# ------------------------------------
# 1. Compile with Swift Package Manager
# ------------------------------------
build:
	swift build -c release 2>&1

# ------------------------------------
# 2. Package into .app bundle
# ------------------------------------
app: build
	@echo "→ Creating $(APP_BUNDLE) …"
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BINARY)"     "$(APP_BUNDLE)/Contents/MacOS/$(EXECUTABLE)"
	@cp "$(INFO_PLIST)" "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "$(ICON_FILE)"  "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	@# Code-sign ad-hoc so macOS allows the app to run
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@echo "✓ $(APP_BUNDLE) ready"

# ------------------------------------
# 3. Install to /Applications
# ------------------------------------
install: app
	@echo "→ Installing to $(INSTALL_DIR)/$(APP_NAME).app …"
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "✓ Installed. Launch $(DISPLAY_NAME) from /Applications."

# ------------------------------------
# 4. Run directly (dev mode, no bundle)
# ------------------------------------
run: build
	"$(BINARY)"

# ------------------------------------
# 5. Open the built app bundle
# ------------------------------------
open: app
	open "$(APP_BUNDLE)"

# ------------------------------------
# 6. Run tests
# ------------------------------------
test:
	swift test

# ------------------------------------
# 7. Create a release zip
# ------------------------------------
release-zip: app
	@echo "→ Creating $(ZIP_FILE) …"
	@rm -f "$(ZIP_FILE)"
	@ditto -c -k --sequesterRsrc --keepParent "$(APP_BUNDLE)" "$(ZIP_FILE)"
	@echo "✓ $(ZIP_FILE) ready"

# ------------------------------------
# 8. Clean
# ------------------------------------
clean:
	rm -rf .build
