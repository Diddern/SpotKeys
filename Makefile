APP := build/SpotKeys.app
INSTALL_DIR := /Applications
BUNDLE_ID := com.diddern.SpotKeys

.PHONY: build install run reset-permissions clean

build:
	./scripts/build.sh

install: build
	-osascript -e 'quit app id "$(BUNDLE_ID)"'
	rm -rf "$(INSTALL_DIR)/SpotKeys.app"
	cp -R "$(APP)" "$(INSTALL_DIR)/"
ifndef SIGN_IDENTITY
	# Ad-hoc signatures change on every build, which invalidates the old Accessibility grant.
	-tccutil reset Accessibility $(BUNDLE_ID)
endif
	open "$(INSTALL_DIR)/SpotKeys.app"

run: build
	open "$(APP)"

reset-permissions:
	-tccutil reset Accessibility $(BUNDLE_ID)
	-tccutil reset AppleEvents $(BUNDLE_ID)

clean:
	rm -rf build "$(HOME)/Library/Caches/SpotKeys"
