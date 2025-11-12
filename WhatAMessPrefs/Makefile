TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = WhatAMessPrefs

WhatAMessPrefs_FILES = WAMRootListController.m
WhatAMessPrefs_FRAMEWORKS = UIKit
WhatAMessPrefs_PRIVATE_FRAMEWORKS = Preferences
WhatAMessPrefs_INSTALL_PATH = /Library/PreferenceBundles
WhatAMessPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
