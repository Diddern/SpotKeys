APP := $(HOME)/Library/Caches/SpotKeys/SpotKeys.app
# ~/Applications needs no admin rights (and works where MDM locks down /Applications).
INSTALL_DIR ?= $(HOME)/Applications
BUNDLE_ID := com.diddern.SpotKeys

.PHONY: build install run reset-permissions clean

build:
	./scripts/build.sh

install: build
	@pkill -x SpotKeys || true
	rm -rf "$(INSTALL_DIR)/SpotKeys.app"
	mkdir -p "$(INSTALL_DIR)"
	ditto "$(APP)" "$(INSTALL_DIR)/SpotKeys.app"
ifndef SIGN_IDENTITY
	@# Ad-hoc signatures change on every build, which invalidates the old Accessibility grant.
	@tccutil reset Accessibility $(BUNDLE_ID) >/dev/null 2>&1 || true
endif
	open "$(INSTALL_DIR)/SpotKeys.app"

run: build
	open "$(APP)"

reset-permissions:
	-tccutil reset Accessibility $(BUNDLE_ID)
	-tccutil reset AppleEvents $(BUNDLE_ID)

clean:
	rm -rf "$(HOME)/Library/Caches/SpotKeys"
