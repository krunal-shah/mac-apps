APP ?= go-links
APP_DIR = apps/$(APP)

.PHONY: list build app install run open clean release-zip

list:
	@find apps -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort

build app install run open clean release-zip:
	$(MAKE) -C "$(APP_DIR)" $@
