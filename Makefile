TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = com.apple.MobileSMS


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WhatAMess

WhatAMess_FILES = Tweak.x
WhatAMess_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += WhatAMessPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
