# part of downgr8 by throwaway96
# licensed under AGPL 3.0 or later
# https://github.com/throwaway96/downgr8

APP_ID:=lol.downgr8
VERSION:=0.0.1
MAIN:=main
ICON:=icon_80x80.png
APP_DIR:=app-build
IPK:=$(APP_ID)_$(VERSION)_arm.ipk

CROSS_COMPILE:=/opt/arm-webos-linux-gnueabi_sdk-buildroot/bin/arm-webos-linux-gnueabi-
CC=$(CROSS_COMPILE)gcc

CFLAGS:=-pipe -std=gnu17 -Wall -Wextra -Og -ggdb -feliminate-unused-debug-types -fdebug-prefix-map='$(dir $(PWD))=' -D_GNU_SOURCE -DDEFAULT_APP_ID='"$(APP_ID)"'
LDFLAGS:=-Wl,-O1 -Wl,--hash-style=gnu -Wl,--as-needed

LIBS:=-lPmLogLib -lglib-2.0 -lpbnjson_c -lluna-service2

SRCS:=main.c

.PHONY: all
all: $(IPK)

$(APP_DIR):
	mkdir -p -- '$(APP_DIR)'

$(APP_DIR)/$(MAIN): $(SRCS) | $(APP_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -o '$@' $^ $(EXTRA_CFLAGS) $(LIBS)

$(APP_DIR)/appinfo.json: appinfo.json.in Makefile | $(APP_DIR)
	sed -e 's/@APP_ID@/$(APP_ID)/g' \
	    -e 's/@MAIN@/$(MAIN)/g' \
	    -e 's/@VERSION@/$(VERSION)/g' < '$<' > '$@'

$(APP_DIR)/$(ICON): $(ICON) | $(APP_DIR)
	cp -t '$(APP_DIR)' -- '$<'

$(IPK): $(APP_DIR)/$(MAIN) $(APP_DIR)/appinfo.json $(APP_DIR)/$(ICON) | $(APP_DIR)
	ares-package '$(APP_DIR)'

.PHONY: install
install:
	ares-install '$(IPK)'

.PHONY: launch
launch:
	ares-launch '$(APP_ID)'

.PHONY: clean
clean:
	rm -f -- '$(IPK)'
	rm -rf -- '$(APP_DIR)'
