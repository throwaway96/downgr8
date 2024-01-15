# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

APP_ID:=lol.downgr8
VERSION:=0.0.1

# app binary (currently called by wrap.sh)
MAIN:=main

# icon for webOS launcher
ICON:=icon_80x80.png

# files to include in the app directory
APP_FILES=$(MAIN) appinfo.json $(ICON) wrap.sh

# files to include in the service directory
SVC_FILES=services.json package.json service.js

# temporary directories used to build the IPK
BUILD_DIR:=build
APP_DIR:=$(BUILD_DIR)/app
SVC_DIR:=$(BUILD_DIR)/service

# We kind of have to guess the IPK filename. Whether it's "arm" or "all" seems
# to depend on whether "main" in appinfo.json specifies a binary or script.
IPK:=$(APP_ID)_$(VERSION)_all.ipk

CROSS_COMPILE:=/opt/arm-webos-linux-gnueabi_sdk-buildroot/bin/arm-webos-linux-gnueabi-
CC=$(CROSS_COMPILE)gcc


CFLAGS:=-pipe -std=gnu17 -Wall -Wextra -Og -ggdb -feliminate-unused-debug-types \
	    -fdebug-prefix-map='$(dir $(PWD))=' -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64 \
		-DDEFAULT_APP_ID='"$(APP_ID)"'

# The LG toolchain uses these. -O1 and --hash-style=gnu are probably useless
# here but not harmful.
LDFLAGS:=-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed

# These are not used (yet), but --as-needed will take care of removing them.
LIBS:=-lPmLogLib -lglib-2.0 -lpbnjson_c -lluna-service2

# source files to link into main binary
SRCS:=main.c

.PHONY: all
all: $(IPK)

$(APP_DIR) $(SVC_DIR):
	mkdir -p -- '$(@)'

$(APP_DIR)/$(MAIN): $(SRCS) | $(APP_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o '$@' $^ $(EXTRA_CFLAGS) $(LIBS)

$(APP_DIR)/%.json $(SVC_DIR)/%.json: %.json.in Makefile | $(APP_DIR) $(SVC_DIR)
	sed -e 's/@APP_ID@/$(APP_ID)/g' \
	    -e 's/@VERSION@/$(VERSION)/g' < '$<' > '$@'

$(APP_DIR)/% $(SVC_DIR)/%: % | $(APP_DIR) $(SVC_DIR)
	mkdir -p -- '$(dir $@)'
	cp -t '$(dir $@)' -- '$<'

$(IPK): $(addprefix $(APP_DIR)/,$(APP_FILES)) $(addprefix $(SVC_DIR)/,$(SVC_FILES)) | $(APP_DIR) $(SVC_DIR)
	ares-package '$(APP_DIR)' '$(SVC_DIR)'

.PHONY: install
install:
	ares-install '$(IPK)'

.PHONY: launch
launch:
	ares-launch '$(APP_ID)'

.PHONY: clean
clean:
	rm -f -- '$(IPK)'
	rm -rf -- '$(BUILD_DIR)'
