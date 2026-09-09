# Pin the SDK to theos's bundled 16.5 (which ships private-framework stubs). `latest` now resolves to the
# Xcode 26 public SDK, which has no PrivateFrameworks, so linking Preferences (prefs bundle) fails.
TARGET = iphone:clang:16.5:15.0
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = com.apple.MobileSMS

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WhatAMess

WhatAMess_FILES = Tweak.x WAMPresetModel.m WAMPresetPreviewView.m WAMPresetCardView.m WAMGradientBuilderController.m
WhatAMess_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += WhatAMessPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk


