TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = com.apple.MobileSMS

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WhatAMess

WhatAMess_FILES = Tweak.x
WhatAMess_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += WhatAMessPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support/WhatAMess$(ECHO_END)
	$(ECHO_NOTHING)cp -r Resources/* $(THEOS_STAGING_DIR)/Library/Application\ Support/WhatAMess/$(ECHO_END)